import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class GeminiException implements Exception {
  GeminiException(
    this.message, {
    this.retrySameModel = false,
    this.retryWithNextModel = false,
  });
  final String message;
  final bool retrySameModel;
  final bool retryWithNextModel;

  @override
  String toString() => message;
}

class _GeminiModel {
  const _GeminiModel(this.id);

  final String id;
}

class GeminiClient {
  GeminiClient({http.Client? httpClient}) : _http = httpClient ?? http.Client();

  static const models = [
    _GeminiModel('gemini-3.6-flash'),
    _GeminiModel('gemini-3.5-flash'),
    _GeminiModel('gemini-3.5-flash-lite'),
  ];

  static String? _workingModelId;
  static final Set<String> _skipThinkingConfig = {};
  static final Set<String> _missingModels = {};
  static final Map<String, DateTime> _overloadedUntil = {};

  final http.Client _http;

  Future<String> generate({
    required String systemPrompt,
    required List<Map<String, String>> contents,
    int maxOutputTokens = 96,
    double temperature = 1,
  }) async {
    final key = _apiKey();
    Object? lastError;

    for (final model in _modelsToTry()) {
      try {
        final text = await _generateWithRetries(
          apiKey: key,
          model: model,
          systemPrompt: systemPrompt,
          contents: contents,
          maxOutputTokens: maxOutputTokens,
          temperature: temperature,
        );
        _workingModelId = model.id;
        _overloadedUntil.remove(model.id);
        debugPrint('Gemini model: ${model.id}');
        return text;
      } on GeminiException catch (error) {
        lastError = error;
        if (error.retryWithNextModel) {
          continue;
        }
        rethrow;
      }
    }
    throw lastError ?? GeminiException('返信を取得できませんでした。');
  }

  List<_GeminiModel> _modelsToTry() {
    final now = DateTime.now();
    bool missing(_GeminiModel model) => _missingModels.contains(model.id);
    bool busy(_GeminiModel model) {
      final until = _overloadedUntil[model.id];
      return until != null && until.isAfter(now);
    }

    final current = models.where((model) => !missing(model)).toList();
    final available = current.where((model) => !busy(model)).toList();
    final overloaded = current.where(busy).toList();
    return [
      ...available.where((model) => model.id == _workingModelId),
      ...available.where((model) => model.id != _workingModelId),
      ...overloaded,
    ];
  }

  Future<String> _generateWithRetries({
    required String apiKey,
    required _GeminiModel model,
    required String systemPrompt,
    required List<Map<String, String>> contents,
    required int maxOutputTokens,
    required double temperature,
  }) async {
    Object? lastError;
    for (var attempt = 0; attempt < 2; attempt++) {
      if (attempt > 0) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
      try {
        return await _generateWithModel(
          apiKey: apiKey,
          model: model,
          systemPrompt: systemPrompt,
          contents: contents,
          maxOutputTokens: maxOutputTokens,
          temperature: temperature,
        );
      } on GeminiException catch (error) {
        lastError = error;
        if (!error.retrySameModel || attempt == 1) {
          rethrow;
        }
      }
    }
    throw lastError ?? GeminiException('返信を取得できませんでした。');
  }

  Future<String> _generateWithModel({
    required String apiKey,
    required _GeminiModel model,
    required String systemPrompt,
    required List<Map<String, String>> contents,
    required int maxOutputTokens,
    required double temperature,
    bool includeThinkingConfig = true,
  }) async {
    final uri = Uri.https(
      'generativelanguage.googleapis.com',
      '/v1beta/models/${model.id}:generateContent',
    );
    final thinking = includeThinkingConfig &&
            !_skipThinkingConfig.contains(model.id)
        ? {
            'thinkingLevel': 'minimal',
            'includeThoughts': false,
          }
        : null;
    final body = jsonEncode({
      'systemInstruction': {
        'parts': [
          {'text': systemPrompt},
        ],
      },
      'contents': [
        for (final turn in contents)
          {
            'role': turn['role'],
            'parts': [
              {'text': turn['text']},
            ],
          },
      ],
      'generationConfig': {
        'temperature': temperature,
        'maxOutputTokens': maxOutputTokens,
        'thinkingConfig': ?thinking,
      },
    });

    late http.Response response;
    final started = DateTime.now();
    try {
      response = await _http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'x-goog-api-key': apiKey,
            },
            body: body,
          )
          .timeout(const Duration(seconds: 8));
    } on TimeoutException {
      _markOverloaded(model.id);
      throw GeminiException(
        'Gemini が混雑しています。もう一度話してみてください。',
        retryWithNextModel: true,
      );
    } on GeminiException {
      rethrow;
    } catch (_) {
      throw GeminiException('ネットワークに接続できませんでした。');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw GeminiException('Gemini の応答を読めませんでした。');
    }

    if (response.statusCode >= 400) {
      debugPrint('Gemini HTTP ${response.statusCode} ${model.id}: ${response.body}');
      if (thinking != null && response.statusCode == 400) {
        _skipThinkingConfig.add(model.id);
        return _generateWithModel(
          apiKey: apiKey,
          model: model,
          systemPrompt: systemPrompt,
          contents: contents,
          maxOutputTokens: maxOutputTokens,
          temperature: temperature,
          includeThinkingConfig: false,
        );
      }
      if (response.statusCode == 503 || response.statusCode == 429) {
        _markOverloaded(model.id);
        throw GeminiException(
          'Gemini が混雑しています。もう一度話してみてください。',
          retrySameModel: true,
          retryWithNextModel: true,
        );
      }
      if (response.statusCode == 404) {
        _missingModels.add(model.id);
        if (_workingModelId == model.id) {
          _workingModelId = null;
        }
        throw GeminiException(
          'このモデルが見つかりません。',
          retryWithNextModel: true,
        );
      }
      throw GeminiException(_messageForStatus(response.statusCode, decoded));
    }

    final text = _extractText(decoded);
    if (text.isEmpty) {
      throw GeminiException('Gemini から空の返信が返りました。');
    }
    debugPrint(
      'Gemini ${model.id} ${DateTime.now().difference(started).inMilliseconds}ms',
    );
    return text;
  }

  static void _markOverloaded(String modelId) {
    _overloadedUntil[modelId] = DateTime.now().add(const Duration(seconds: 20));
    if (_workingModelId == modelId) {
      _workingModelId = null;
    }
  }

  static String _apiKey() {
    final key = dotenv.env['GEMINI_API_KEY']?.trim() ?? '';
    if (key.isEmpty) {
      throw GeminiException('.env の GEMINI_API_KEY が空です。');
    }
    return key;
  }

  static String _extractText(Map<String, dynamic> json) {
    final candidates = json['candidates'];
    if (candidates is! List || candidates.isEmpty) {
      return '';
    }
    final content = candidates.first;
    if (content is! Map) return '';
    final parts = (content['content'] as Map?)?['parts'];
    if (parts is! List) return '';

    final buffer = StringBuffer();
    for (final part in parts) {
      if (part is! Map) continue;
      if (part['thought'] == true) continue;
      final text = part['text'];
      if (text is String && text.trim().isNotEmpty) {
        buffer.write(text);
      }
    }
    return buffer.toString().trim();
  }

  static String _messageForStatus(int status, Map<String, dynamic> json) {
    final apiMessage = (json['error'] is Map)
        ? (json['error']['message'] as String?) ?? ''
        : '';
    final lower = apiMessage.toLowerCase();

    if (status == 401 || status == 403 || lower.contains('api key')) {
      return 'Gemini APIキーが無効です。AI Studio のキーを .env に入れてください。';
    }
    if (status == 404 || lower.contains('not found')) {
      return 'このモデルが見つかりません。';
    }
    if (status == 429) {
      return 'リクエストが多すぎます。少し待ってから再試行してください。';
    }
    if (apiMessage.isNotEmpty) {
      return apiMessage;
    }
    return 'Gemini との通信に失敗しました（HTTP $status）。';
  }
}
