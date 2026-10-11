import 'dart:convert';

import 'package:http/http.dart' as http;

class DictionaryException implements Exception {
  DictionaryException(this.message);
  final String message;

  @override
  String toString() => message;
}

class DictionarySense {
  const DictionarySense({
    required this.partOfSpeech,
    required this.english,
    required this.japanese,
    this.example,
  });

  final String partOfSpeech;
  final String english;
  final String japanese;
  final String? example;
}

class DictionaryEntry {
  const DictionaryEntry({
    required this.word,
    required this.languageLabel,
    required this.senses,
    this.englishGlosses = const [],
  });

  final String word;
  final String languageLabel;
  final List<DictionarySense> senses;
  final List<String> englishGlosses;
}

class _Gloss {
  const _Gloss({
    required this.japanese,
    required this.partOfSpeech,
    required this.source,
    this.example,
  });

  final String japanese;
  final String partOfSpeech;
  final String source;
  final String? example;

  bool get trusted =>
      !source.toLowerCase().contains('open multilingual wordnet');
}

class DictionaryClient {
  DictionaryClient({http.Client? httpClient})
    : _http = httpClient ?? http.Client();

  static const _userAgent = 'JomBM/1.0 (Malay learning)';
  static const _headers = {
    'User-Agent': _userAgent,
    'Accept': 'text/html,application/json',
  };

  final http.Client _http;
  final Map<String, DictionaryEntry> _cache = {};

  Future<DictionaryEntry?> lookup(String word) async {
    final key = word.trim().toLowerCase();
    if (key.isEmpty) return null;
    final cached = _cache[key];
    if (cached != null) return cached;

    final direct = await _glosbe(key);
    final trusted = direct.where((gloss) => gloss.trusted).toList();
    var chosen = trusted;
    var glossWord = key;
    String? baseNote;
    if (chosen.isEmpty) {
      final base = await _contractionBase(key);
      if (base != null && base != key) {
        final expanded = await _glosbe(base);
        final expandedTrusted = expanded.where((gloss) => gloss.trusted);
        final expandedRest = expanded.where((gloss) => !gloss.trusted);
        final merged = [...expandedTrusted, ...expandedRest];
        if (merged.isNotEmpty) {
          chosen = merged;
          glossWord = base;
          baseNote = '「$base」の短縮';
        }
      }
    }
    if (chosen.isEmpty && direct.isNotEmpty) {
      chosen = [direct.first];
    }
    if (chosen.isEmpty) return null;

    final senses = <DictionarySense>[];
    final seen = <String>{};
    for (final gloss in chosen) {
      if (!seen.add(gloss.japanese)) continue;
      final example = senses.isEmpty && baseNote != null
          ? baseNote
          : gloss.example;
      senses.add(
        DictionarySense(
          partOfSpeech: gloss.partOfSpeech,
          english: gloss.japanese,
          japanese: gloss.japanese,
          example: example,
        ),
      );
      if (senses.length == 3) break;
    }
    if (senses.isEmpty) return null;

    final entry = DictionaryEntry(
      word: key,
      languageLabel: 'マレー語',
      senses: senses,
      englishGlosses: await _englishGlosses(glossWord),
    );
    _cache[key] = entry;
    return entry;
  }

  Future<List<String>> _englishGlosses(String word) async {
    try {
      final glosses = await _glosbe(word, target: 'en');
      final seen = <String>{};
      final english = <String>[];
      for (final gloss in glosses) {
        final text = gloss.japanese.trim();
        if (text.isEmpty || !seen.add(text.toLowerCase())) continue;
        english.add(text);
        if (english.length == 3) break;
      }
      return english;
    } catch (_) {
      return const [];
    }
  }

  Future<List<_Gloss>> _glosbe(String word, {String target = 'ja'}) async {
    final uri = Uri(
      scheme: 'https',
      host: 'glosbe.com',
      pathSegments: ['ms', target, word],
    );
    final response = await _http
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 12));
    if (response.statusCode == 404) return const [];
    if (response.statusCode != 200) {
      throw DictionaryException('辞書を取得できませんでした（${response.statusCode}）。');
    }
    return _parseGlosbeHtml(
      utf8.decode(response.bodyBytes, allowMalformed: true),
      japanese: target == 'ja',
    );
  }

  Future<String?> _contractionBase(String word) async {
    final uri = Uri(
      scheme: 'https',
      host: 'en.wiktionary.org',
      pathSegments: ['api', 'rest_v1', 'page', 'definition', word],
    );
    try {
      final response = await _http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(
        utf8.decode(response.bodyBytes, allowMalformed: true),
      );
      if (decoded is! Map<String, dynamic>) return null;
      final malay = decoded['ms'];
      if (malay is! List) return null;
      final pattern = RegExp(
        r'(?:contraction|clipping|abbreviation|short form) of ([a-z][a-z-]*)',
        caseSensitive: false,
      );
      for (final entry in malay) {
        if (entry is! Map<String, dynamic>) continue;
        final definitions = entry['definitions'];
        if (definitions is! List) continue;
        for (final definition in definitions) {
          if (definition is! Map<String, dynamic>) continue;
          final text = stripHtml('${definition['definition'] ?? ''}');
          final match = pattern.firstMatch(text);
          final base = match?.group(1)?.toLowerCase();
          if (base != null && base.isNotEmpty && base != word) return base;
        }
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  static List<_Gloss> _parseGlosbeHtml(String html, {bool japanese = true}) {
    final auto = html.toLowerCase().indexOf('automatic translations');
    final body = auto >= 0 ? html.substring(0, auto) : html;
    final parts = body.split('data-element="translation"');
    final glosses = <_Gloss>[];
    for (final part in parts.skip(1)) {
      final phrase = _firstMatch(
        part,
        RegExp(r'translation__item__pharse[^>]*>\s*([^<]+)'),
      );
      if (phrase == null) continue;
      final japaneseText = phrase.trim();
      if (japaneseText.isEmpty) continue;
      if (japanese &&
          (japaneseText.contains('県') || japaneseText.contains('郡'))) {
        continue;
      }
      final pos = _firstMatch(part, RegExp(r'dir-aware-pr-1">([^<]+)</span>'));
      final source = stripHtml(
        _firstMatch(part, RegExp(r'<aside[^>]*>(.*?)</aside>', dotAll: true)) ??
            '',
      );
      glosses.add(
        _Gloss(
          japanese: japaneseText,
          partOfSpeech: translatePos(pos?.split(RegExp(r'\s+')).first ?? ''),
          source: source,
          example: _example(part),
        ),
      );
    }
    return glosses;
  }

  static String? _example(String part) {
    String? malay;
    String? japanese;
    final pattern = RegExp(
      '<p\\b[^>]*\\blang="(ms|ja)"[^>]*>(.*?)</p>',
      caseSensitive: false,
      dotAll: true,
    );
    for (final match in pattern.allMatches(part)) {
      final lang = match.group(1)!.toLowerCase();
      final text = stripHtml(match.group(2) ?? '');
      if (text.isEmpty) continue;
      if (lang == 'ms' && malay == null) malay = text;
      if (lang == 'ja' && japanese == null) japanese = text;
    }
    if (malay != null && japanese != null) return '$malay / $japanese';
    return japanese ?? malay;
  }

  static String? _firstMatch(String text, RegExp pattern) {
    final match = pattern.firstMatch(text);
    final value = match?.group(1);
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static String stripHtml(String html) {
    var text = html.replaceAll(RegExp(r'<[^>]*>'), ' ');
    text = text
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&nbsp;', ' ')
        .replaceAll(RegExp(r'&[a-zA-Z]+;'), ' ');
    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static String translatePos(String pos) {
    switch (pos.toLowerCase()) {
      case 'noun':
        return '名詞';
      case 'verb':
        return '動詞';
      case 'adjective':
        return '形容詞';
      case 'adverb':
        return '副詞';
      case 'pronoun':
        return '代名詞';
      case 'particle':
        return '助詞';
      case 'preposition':
        return '前置詞';
      case 'conjunction':
        return '接続詞';
      case 'interjection':
        return '間投詞';
      case 'determiner':
        return '限定詞';
      case 'article':
        return '冠詞';
      case 'numeral':
      case 'number':
        return '数詞';
      case 'prefix':
        return '接頭辞';
      case 'suffix':
        return '接尾辞';
      default:
        return pos.isEmpty ? '語句' : pos;
    }
  }
}
