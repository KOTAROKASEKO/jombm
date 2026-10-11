import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'vocab_note.dart';

class NotesStore {
  NotesStore._();

  static final NotesStore instance = NotesStore._();

  static const _key = 'vocab_notes';

  List<VocabNote> _notes = [];
  bool _loaded = false;

  List<VocabNote> get notes => List.unmodifiable(_notes);

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
            .map((item) => VocabNote.fromJson(Map<String, dynamic>.from(item)))
            .toList();
      }
    }
    _loaded = true;
  }

  bool contains(String word) {
    final target = word.toLowerCase();
    return _notes.any((note) => note.word.toLowerCase() == target);
  }

  Future<bool> add(VocabNote note) async {
    await load();
    if (contains(note.word)) return false;
    _notes.insert(0, note);
    await _save();
    return true;
  }

  Future<void> remove(String word) async {
    await load();
    final target = word.toLowerCase();
    _notes.removeWhere((note) => note.word.toLowerCase() == target);
    await _save();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(_notes.map((note) => note.toJson()).toList()),
    );
  }
}
