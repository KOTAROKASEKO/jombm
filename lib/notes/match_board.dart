import 'dart:math';

import 'vocab_note.dart';

class MatchPair {
  const MatchPair({
    required this.id,
    required this.word,
    required this.meaning,
  });

  final String id;
  final String word;
  final String meaning;
}

const matchMaxHp = 100;
const matchCollisionDamage = 5;

enum MatchDrop { correct, wrong }

class MatchBoard {
  MatchBoard(List<MatchPair> pairs, {Random? random})
    : pairs = List.unmodifiable(pairs),
      malayOrder = [for (final pair in pairs) pair.id]..shuffle(random),
      meaningOrder = [for (final pair in pairs) pair.id]..shuffle(random);

  final List<MatchPair> pairs;
  final List<String> malayOrder;
  final List<String> meaningOrder;
  final Set<String> matched = {};
  final Set<String> crashed = {};
  int hp = matchMaxHp;
  int mistakes = 0;

  bool get isComplete => pairs.isNotEmpty && matched.length == pairs.length;

  List<MatchPair> get missed {
    return [
      for (final id in malayOrder)
        if (!matched.contains(id)) pairById(id),
    ];
  }

  int get damage => matchMaxHp - hp;

  MatchPair pairById(String id) {
    return pairs.firstWhere((pair) => pair.id == id);
  }

  MatchDrop dropOn({required String wordId, required String meaningId}) {
    if (matched.contains(wordId) ||
        crashed.contains(wordId) ||
        matched.contains(meaningId)) {
      return MatchDrop.wrong;
    }
    if (wordId == meaningId) {
      matched.add(wordId);
      return MatchDrop.correct;
    }
    return MatchDrop.wrong;
  }

  bool collide(String wordId) {
    if (matched.contains(wordId) || crashed.contains(wordId)) return false;
    crashed.add(wordId);
    mistakes++;
    hp = max(0, hp - matchCollisionDamage);
    return true;
  }
}

List<MatchPair> pairsFromNotes(List<VocabNote> notes) {
  final pairs = <MatchPair>[];
  final seen = <String>{};
  for (final note in notes) {
    final word = note.word.trim();
    final meaning = note.meaning.trim();
    if (word.isEmpty || meaning.isEmpty) continue;
    final id = word.toLowerCase();
    if (!seen.add(id)) continue;
    pairs.add(MatchPair(id: id, word: word, meaning: meaning));
  }
  return pairs;
}

const meaningRows = 2;
const meaningChipHeight = 36.0;
const meaningChipGap = 6.0;
const meaningChipMinWidth = 64.0;
const meaningChipMaxWidth = 120.0;
const meaningListPaddingH = 8.0;
const meaningListPaddingV = 6.0;

/// How many Japanese chips fit in the two-row answer tray.
int visibleMeaningSlots(double width) {
  final available = width - meaningListPaddingH * 2 + meaningChipGap;
  if (available < meaningChipMaxWidth + meaningChipGap) return meaningRows;
  final perRow = (available / (meaningChipMaxWidth + meaningChipGap)).floor();
  return (perRow < 1 ? 1 : perRow) * meaningRows;
}

/// Moves [recentId] into the unmatched chips that fit on screen.
/// Ids already inside that window stay put. Matched ids are skipped
/// when counting visible slots.
List<String> bringAnswerIntoView({
  required List<String> order,
  required String? recentId,
  required int visibleSlots,
  required Set<String> matched,
  int slotBias = 0,
}) {
  if (recentId == null || visibleSlots <= 0 || matched.contains(recentId)) {
    return order;
  }
  final index = order.indexOf(recentId);
  if (index < 0) return order;

  final visibleIndexes = <int>[];
  for (var i = 0; i < order.length; i++) {
    if (matched.contains(order[i])) continue;
    visibleIndexes.add(i);
    if (visibleIndexes.length == visibleSlots) break;
  }
  if (visibleIndexes.isEmpty || visibleIndexes.contains(index)) return order;

  final swapAt = visibleIndexes[slotBias.abs() % visibleIndexes.length];
  final next = List<String>.of(order);
  final displaced = next[swapAt];
  next[swapAt] = recentId;
  next[index] = displaced;
  return next;
}

String formatMatchElapsed(Duration duration) {
  final seconds = duration.inSeconds < 0 ? 0 : duration.inSeconds;
  final minutes = seconds ~/ 60;
  final remain = seconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:${remain.toString().padLeft(2, '0')}';
}
