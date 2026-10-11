import 'dart:convert';

import 'dictionary_client.dart';
import 'gemini_client.dart';

class WordMeaning {
  const WordMeaning({
    required this.word,
    required this.meaning,
    this.english,
    this.note,
    this.senses = const [],
    this.sourceLabel,
  });

  final String word;
  final String meaning;
  final String? english;
  final String? note;
  final List<DictionarySense> senses;
  final String? sourceLabel;
}

class WordLookup {
  WordLookup({DictionaryClient? dictionary, GeminiClient? client})
    : _dictionary = dictionary ?? DictionaryClient(),
      _client = client ?? GeminiClient();

  static const _systemPrompt = '''
You help Japanese beginners look up Malay words from a conversation.

Return JSON only, no markdown:
{"meaning":"日本語の意味","english":"short English gloss","note":"使い方を日本語で一文"}

Keep meaning short. english is a short English gloss, not Japanese, so the learner can check the Japanese. Use the sentence for context.
If the word is a particle or filler, explain that simply.
''';

  final DictionaryClient _dictionary;
  final GeminiClient _client;

  Future<WordMeaning> lookup({
    required String word,
    required String sentence,
  }) async {
    try {
      final entry = await _dictionary.lookup(word);
      if (entry != null && entry.senses.isNotEmpty) {
        return _fromDictionary(word, entry);
      }
    } catch (_) {
      // Fall back to Gemini when the dictionary is unavailable.
    }
    return _lookupWithGemini(word: word, sentence: sentence);
  }

  WordMeaning _fromDictionary(String word, DictionaryEntry entry) {
    final meaning = entry.senses
        .map((sense) => sense.japanese)
        .where((text) => text.isNotEmpty)
        .toSet()
        .join('、');
    final example = entry.senses
        .map((sense) => sense.example)
        .whereType<String>()
        .firstWhere((text) => text.isNotEmpty, orElse: () => '');
    final extra = example.isEmpty ? null : '例: $example';
    final english = entry.englishGlosses
        .map((gloss) => gloss.trim())
        .where((gloss) => gloss.isNotEmpty)
        .toSet()
        .take(3)
        .join(', ');
    return WordMeaning(
      word: word,
      meaning: meaning.isEmpty ? entry.senses.first.english : meaning,
      english: english.isEmpty ? null : english,
      note: extra,
      senses: entry.senses,
      sourceLabel: 'Glosbe（${entry.languageLabel}）',
    );
  }

  Future<WordMeaning> _lookupWithGemini({
    required String word,
    required String sentence,
  }) async {
    final raw = await _client.generate(
      systemPrompt: _systemPrompt,
      contents: [
        {'role': 'user', 'text': 'Word: $word\nSentence: $sentence'},
      ],
      maxOutputTokens: 220,
      temperature: 0.2,
    );

    Map<String, dynamic> parsed;
    try {
      parsed = _parseJson(raw);
    } catch (_) {
      parsed = {'meaning': raw.trim()};
    }
    final meaning = (parsed['meaning'] as String?)?.trim();
    final note = (parsed['note'] as String?)?.trim();
    final english = (parsed['english'] as String?)?.trim();
    return WordMeaning(
      word: word,
      meaning: (meaning == null || meaning.isEmpty) ? raw.trim() : meaning,
      english: (english == null || english.isEmpty) ? null : english,
      note: (note == null || note.isEmpty) ? null : note,
      sourceLabel: '会話からの説明',
    );
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
