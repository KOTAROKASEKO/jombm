import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MatchRecord {
  const MatchRecord({
    required this.completedAt,
    required this.elapsedMs,
    required this.wordCount,
    required this.mistakes,
  });

  final DateTime completedAt;
  final int elapsedMs;
  final int wordCount;
  final int mistakes;

  Map<String, dynamic> toJson() => {
    'completedAt': completedAt.toIso8601String(),
    'elapsedMs': elapsedMs,
    'wordCount': wordCount,
    'mistakes': mistakes,
  };

  factory MatchRecord.fromJson(Map<String, dynamic> json) {
    return MatchRecord(
      completedAt:
          DateTime.tryParse(json['completedAt'] as String? ?? '') ??
          DateTime.now(),
      elapsedMs: json['elapsedMs'] is num
          ? (json['elapsedMs'] as num).toInt()
          : 0,
      wordCount: json['wordCount'] is num
          ? (json['wordCount'] as num).toInt()
          : 0,
      mistakes: json['mistakes'] is num ? (json['mistakes'] as num).toInt() : 0,
    );
  }
}

class MatchStore {
  MatchStore._();

  static final MatchStore instance = MatchStore._();

  static const _key = 'match_records';

  List<MatchRecord> _records = [];
  bool _loaded = false;

  List<MatchRecord> get records => List.unmodifiable(_records);

  @visibleForTesting
  void resetForTest() {
    _records = [];
    _loaded = false;
  }

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null && raw.isNotEmpty) {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        _records = decoded
            .whereType<Map>()
            .map(
              (item) => MatchRecord.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList();
      }
    }
    _loaded = true;
  }

  Future<void> add(MatchRecord record) async {
    await load();
    _records.insert(0, record);
    await _save();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(_records.map((record) => record.toJson()).toList()),
    );
  }
}
