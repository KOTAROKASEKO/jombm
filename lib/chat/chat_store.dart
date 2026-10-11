import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'chat_session.dart';

class ChatStore {
  ChatStore._();

  static final ChatStore instance = ChatStore._();

  static const _sessionsKey = 'chat_sessions';
  static const _currentKey = 'chat_current_id';

  List<ChatSession> _sessions = [];
  String? _currentId;
  bool _loaded = false;

  @visibleForTesting
  void resetForTest() {
    _sessions = [];
    _currentId = null;
    _loaded = false;
  }

  List<ChatSession> get sessions {
    final copy = [..._sessions]..sort(
      (a, b) => b.updatedAt.compareTo(a.updatedAt),
    );
    return List.unmodifiable(copy);
  }

  String? get currentId => _currentId;

  ChatSession? get current {
    final id = _currentId;
    if (id == null) return null;
    for (final session in _sessions) {
      if (session.id == id) return session;
    }
    return null;
  }

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    _currentId = prefs.getString(_currentKey);
    final raw = prefs.getString(_sessionsKey);
    if (raw != null && raw.isNotEmpty) {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        _sessions = decoded
            .whereType<Map>()
            .map((item) => ChatSession.fromJson(Map<String, dynamic>.from(item)))
            .where((session) => session.id.isNotEmpty)
            .toList();
      }
    }
    _loaded = true;
  }

  Future<void> upsert(ChatSession session) async {
    await load();
    final index = _sessions.indexWhere((item) => item.id == session.id);
    if (index >= 0) {
      _sessions[index] = session;
    } else {
      _sessions.insert(0, session);
    }
    _currentId = session.id;
    await _save();
  }

  Future<void> delete(String id) async {
    await load();
    _sessions.removeWhere((session) => session.id == id);
    if (_currentId == id) {
      _currentId = null;
    }
    await _save();
  }

  Future<void> setCurrent(String? id) async {
    await load();
    _currentId = id;
    await _save();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _sessionsKey,
      jsonEncode(_sessions.map((session) => session.toJson()).toList()),
    );
    if (_currentId == null) {
      await prefs.remove(_currentKey);
    } else {
      await prefs.setString(_currentKey, _currentId!);
    }
  }
}
