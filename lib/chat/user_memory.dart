import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../conversation/gemini_client.dart';

class UserNote {
  const UserNote({required this.text, required this.updatedAt});

  final String text;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => {
    'text': text,
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory UserNote.fromJson(Map<String, dynamic> json) {
    return UserNote(
      text: json['text'] as String? ?? '',
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

String? parseLearnerFact(String raw) {
  final line = raw
      .trim()
      .split('\n')
      .first
      .trim()
      .replaceFirst(RegExp(r"""^[-*・"「『]+"""), '')
      .replaceFirst(RegExp(r"""["」』]+$"""), '')
      .trim();
  if (line.isEmpty || line.toUpperCase() == 'NONE') return null;
  if (line.length > 80) return null;
  return line;
}

String learnerNotesForPrompt(List<String> notes) {
  if (notes.isEmpty) return '';
  final lines = notes.take(3).map((note) => '- $note').join('\n');
  return '''
Recent notes about this learner. Mention one only when it naturally fits. Do not recite the list.
$lines
''';
}

class UserMemoryStore {
  UserMemoryStore._();

  static final UserMemoryStore instance = UserMemoryStore._();

  static const _key = 'user_memory';
  static const _maxKept = 20;
  static const recentLimit = 3;

  static const _extractPrompt = '''
Extract one personal fact about the learner from their message.
Facts include name, home, job, family, likes, plans, and hobbies.
Ignore greetings and language practice that reveals nothing personal.
Return one short Japanese sentence, or exactly NONE.
''';

  final GeminiClient _client = GeminiClient();
  List<UserNote> _notes = [];
  bool _loaded = false;

  @visibleForTesting
  void resetForTest() {
    _notes = [];
    _loaded = false;
  }

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null && raw.isNotEmpty) {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        _notes = decoded
            .whereType<Map>()
            .map((item) => UserNote.fromJson(Map<String, dynamic>.from(item)))
            .where((note) => note.text.trim().isNotEmpty)
            .toList();
      }
    }
    _loaded = true;
  }

  Future<List<String>> recent() async {
    await load();
    final sorted = [..._notes]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return sorted.take(recentLimit).map((note) => note.text).toList();
  }

  Future<void> remember(String text) async {
    await load();
    final fact = text.trim();
    if (fact.isEmpty) return;
    final key = _normalize(fact);
    final now = DateTime.now();
    final index = _notes.indexWhere((note) => _normalize(note.text) == key);
    if (index >= 0) {
      _notes[index] = UserNote(text: fact, updatedAt: now);
    } else {
      _notes.add(UserNote(text: fact, updatedAt: now));
    }
    _notes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    if (_notes.length > _maxKept) {
      _notes = _notes.sublist(0, _maxKept);
    }
    await _save();
  }

  Future<void> capture(String message) async {
    final spoken = message.trim();
    if (spoken.isEmpty) return;
    final raw = await _client.generate(
      systemPrompt: _extractPrompt,
      contents: [
        {'role': 'user', 'text': spoken},
      ],
      maxOutputTokens: 60,
      temperature: 0,
    );
    final fact = parseLearnerFact(raw);
    if (fact == null) return;
    await remember(fact);
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(_notes.map((note) => note.toJson()).toList()),
    );
  }

  static String _normalize(String text) =>
      text.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}
