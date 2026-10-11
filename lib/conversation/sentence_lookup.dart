import 'dart:convert';

import 'gemini_client.dart';

class SentenceTranslation {
  const SentenceTranslation({
    required this.original,
    required this.translation,
    this.english,
    this.note,
  });

  final String original;
  final String translation;
  final String? english;
  final String? note;

  Map<String, dynamic> toJson() => {
    'original': original,
    'translation': translation,
    'english': english,
    'note': note,
  };

  factory SentenceTranslation.fromJson(Map<String, dynamic> json) {
    return SentenceTranslation(
      original: json['original'] as String? ?? '',
      translation: json['translation'] as String? ?? '',
      english: _blankToNull(json['english'] as String?),
      note: json['note'] as String?,
    );
  }
}

String? readableEnglish(
  String? english, {
  required String original,
  required String translation,
}) {
  final text = english?.trim();
  if (text == null || text.isEmpty) return null;
  if (text == translation.trim()) return null;
  if (text.toLowerCase() == original.trim().toLowerCase()) return null;
  return text;
}

String? _blankToNull(String? value) {
  final text = value?.trim();
  if (text == null || text.isEmpty) return null;
  return text;
}

class SentenceLookup {
  SentenceLookup({GeminiClient? client}) : _client = client ?? GeminiClient();

  static const _systemPrompt = '''
You translate one chat line for a Japanese learner of Malaysian Malay.

If the line is Malay or English, translation must be natural Japanese.
If the line is Japanese, translation must be casual spoken Bahasa Melayu (Malaysia), using tak, nak, dah, je, lah when natural. Never Bahasa Indonesia.
english is always a short, plain English version of the same meaning, so the learner can check the Japanese. One sentence at most. Do not copy the Japanese into english.

Return JSON only, no markdown:
{"translation":"...","english":"...","note":"日本語で一言の補足。不要なら空文字"}

Keep translation to one or two short sentences.
Do not add romanization or extra quotes.
''';

  static const _toMalayPrompt = '''
Translate the user's word or short phrase into casual spoken Bahasa Melayu (Malaysia).
The input may be Japanese or English. If it is already Malay, keep that Malay.
Use tak, nak, dah, je, lah only when they sound natural. Never Bahasa Indonesia.

Return JSON only, no markdown:
{"translation":"...","note":""}

translation must be Malay only, one short phrase.
Do not add romanization, quotes, or Japanese.
''';

  final GeminiClient _client;
  static final Map<String, SentenceTranslation> _cache = {};

  Future<SentenceTranslation> translate(String sentence) async {
    final key = sentence.trim();
    final cached = _cache[key];
    if (cached != null) return cached;

    final raw = await _client.generate(
      systemPrompt: _systemPrompt,
      contents: [
        {'role': 'user', 'text': key},
      ],
      maxOutputTokens: 240,
      temperature: 0.2,
    );

    Map<String, dynamic> parsed;
    try {
      parsed = _parseJson(raw);
    } catch (_) {
      parsed = {'translation': raw.trim()};
    }
    final translation = (parsed['translation'] as String?)?.trim();
    final note = (parsed['note'] as String?)?.trim();
    final result = SentenceTranslation(
      original: key,
      translation: (translation == null || translation.isEmpty)
          ? raw.trim()
          : translation,
      english: _blankToNull(parsed['english'] as String?),
      note: (note == null || note.isEmpty) ? null : note,
    );
    _cache[key] = result;
    return result;
  }

  Future<SentenceTranslation> toMalay(String text) async {
    final key = text.trim();
    if (key.isEmpty) {
      return const SentenceTranslation(original: '', translation: '');
    }
    final cacheKey = 'ms:$key';
    final cached = _cache[cacheKey];
    if (cached != null) return cached;

    final raw = await _client.generate(
      systemPrompt: _toMalayPrompt,
      contents: [
        {'role': 'user', 'text': key},
      ],
      maxOutputTokens: 120,
      temperature: 0.2,
    );

    Map<String, dynamic> parsed;
    try {
      parsed = _parseJson(raw);
    } catch (_) {
      parsed = {'translation': raw.trim()};
    }
    final translation = (parsed['translation'] as String?)?.trim();
    final result = SentenceTranslation(
      original: key,
      translation: (translation == null || translation.isEmpty)
          ? raw.trim()
          : translation,
    );
    _cache[cacheKey] = result;
    return result;
  }

  static Map<String, dynamic> _parseJson(String raw) {
    var text = raw.trim();
    if (text.startsWith('```')) {
      text = text.replaceFirst(RegExp(r'^```(?:json)?'), '').trim();
      if (text.endsWith('```')) {
        text = text.substring(0, text.length - 3).trim();
      }
    }
    final decoded = jsonDecode(text);
    if (decoded is Map<String, dynamic>) return decoded;
    return {};
  }
}
