import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../notes/match_board.dart';
import '../notes/match_store.dart';

const _chipHeight = 48.0;
const _chipGap = 40.0;
const _fallSpeed = 32.0;

class _FallingWord {
  _FallingWord({required this.id, required this.y});

  final String id;
  double y;
}

enum _Phase { playing, cleared, failed }

class MatchScreen extends StatefulWidget {
  const MatchScreen({super.key, required this.pairs});

  final List<MatchPair> pairs;

  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends State<MatchScreen>
    with SingleTickerProviderStateMixin {
  late final MatchBoard _board;
  late final List<_FallingWord> _words;
  late final DateTime _started;
  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;
  Timer? _secondPulse;
  Duration? _finishedIn;
  String? _feedback;
  String? _draggingId;
  double? _playfieldHeight;
  double? _meaningListWidth;
  late List<String> _meaningIds;
  final ScrollController _meaningScroll = ScrollController();
  int _answerSlot = 0;
  String? _pinnedRecentId;
  bool _placed = false;
  _Phase _phase = _Phase.playing;
  bool _saving = false;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _board = MatchBoard(widget.pairs);
    _meaningIds = List<String>.of(_board.meaningOrder);
    _words = [
      for (final id in _board.malayOrder) _FallingWord(id: id, y: -_chipHeight),
    ];
    _started = DateTime.now();
    _ticker = createTicker(_onTick);
    if (widget.pairs.isNotEmpty) _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _meaningScroll.dispose();
    _secondPulse?.cancel();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    if (!mounted || _phase != _Phase.playing) return;
    final dt =
        (elapsed - _lastTick).inMicroseconds / Duration.microsecondsPerSecond;
    _lastTick = elapsed;
    final step = dt.clamp(0.0, 0.05);
    final crashY = _playfieldHeight == null
        ? null
        : _playfieldHeight! - _chipHeight;
    final hit = <_FallingWord>[];
    for (final word in _words) {
      if (word.id == _draggingId) continue;
      word.y += _fallSpeed * step;
      if (crashY != null && word.y >= crashY) hit.add(word);
    }
    for (final word in hit) {
      _words.remove(word);
      if (_board.collide(word.id)) {
        _feedback = 'ダメージ -$matchCollisionDamage';
        _pulse(correct: false);
      }
    }
    _checkEnd();
    setState(() {});
  }

  Duration get _elapsed => _finishedIn ?? DateTime.now().difference(_started);

  void _pulse({required bool correct}) {
    _secondPulse?.cancel();
    unawaited(_vibrate());
    if (correct) return;
    _secondPulse = Timer(const Duration(milliseconds: 180), () {
      unawaited(_vibrate());
    });
  }

  Future<void> _vibrate() async {
    try {
      await HapticFeedback.vibrate();
    } catch (_) {}
  }

  void _placeWords() {
    if (_placed) return;
    _placed = true;
    final pitch = _chipHeight + _chipGap;
    var y = -_chipHeight;
    for (final word in _words) {
      word.y = y;
      y -= pitch;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final before = _meaningIds;
      _refreshMeaningWindow();
      if (!identical(before, _meaningIds)) setState(() {});
    });
  }

  String? _mostRecentVisibleMalay() {
    final height = _playfieldHeight;
    if (height == null || height <= 0) return null;
    String? recent;
    var recentIndex = -1;
    for (final word in _words) {
      final onScreen = word.y < height && word.y + _chipHeight > 0;
      if (!onScreen) continue;
      final index = _board.malayOrder.indexOf(word.id);
      if (index > recentIndex) {
        recentIndex = index;
        recent = word.id;
      }
    }
    return recent;
  }

  void _refreshMeaningWindow() {
    final width = _meaningListWidth;
    if (width == null) return;
    final target = _mostRecentVisibleMalay();
    final next = bringAnswerIntoView(
      order: _meaningIds,
      recentId: target,
      visibleSlots: visibleMeaningSlots(width),
      matched: _board.matched,
      slotBias: _answerSlot,
    );
    final orderChanged = !_sameIds(next, _meaningIds);
    final targetChanged = target != null && target != _pinnedRecentId;
    if (!orderChanged && !targetChanged) return;
    if (orderChanged) {
      _answerSlot++;
      _meaningIds = next;
    }
    if (target != null) _pinnedRecentId = target;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_meaningScroll.hasClients) return;
      if (_meaningScroll.offset == 0) return;
      _meaningScroll.jumpTo(0);
    });
  }

  bool _sameIds(List<String> a, List<String> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void _drop(String wordId, String meaningId) {
    if (_phase != _Phase.playing) return;
    final result = _board.dropOn(wordId: wordId, meaningId: meaningId);
    if (result == MatchDrop.wrong) {
      _pulse(correct: false);
      setState(() => _feedback = 'ちがいます');
      return;
    }
    _words.removeWhere((word) => word.id == wordId);
    _pulse(correct: true);
    _feedback = null;
    _checkEnd();
    setState(() {});
  }

  void _checkEnd() {
    if (_phase != _Phase.playing) return;
    if (_board.isComplete) {
      _phase = _Phase.cleared;
      unawaited(_saveClear());
      return;
    }
    if (_board.hp <= 0 || _words.isEmpty) {
      _phase = _Phase.failed;
      _finishedIn ??= DateTime.now().difference(_started);
      _ticker.stop();
    }
  }

  Future<void> _saveClear() async {
    if (_saving || _saved) return;
    _finishedIn ??= DateTime.now().difference(_started);
    _ticker.stop();
    _saving = true;
    final record = MatchRecord(
      completedAt: DateTime.now(),
      elapsedMs: _finishedIn!.inMilliseconds,
      wordCount: widget.pairs.length,
      mistakes: _board.mistakes,
    );
    try {
      await MatchStore.instance.add(record);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _feedback = '記録を保存できませんでした';
      });
      return;
    }
    if (!mounted) return;
    setState(() {
      _saving = false;
      _saved = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('意味合わせ')),
      body: SafeArea(
        child: widget.pairs.isEmpty
            ? const Center(child: Text('意味のある単語がまだありません'))
            : _phase == _Phase.playing
            ? _playfield(theme)
            : _result(theme),
      ),
    );
  }

  Widget _playfield(ThemeData theme) {
    final scheme = theme.colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              Text(
                formatMatchElapsed(_elapsed),
                style: theme.textTheme.titleMedium,
              ),
              const Spacer(),
              Text('HP ${_board.hp}', style: theme.textTheme.titleMedium),
            ],
          ),
        ),
        LinearProgressIndicator(
          value: _board.hp / matchMaxHp,
          minHeight: 6,
          color: _board.hp > 20 ? scheme.primary : scheme.error,
          backgroundColor: scheme.surfaceContainerHighest,
        ),
        if (_feedback != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              _feedback!,
              style: theme.textTheme.bodyMedium?.copyWith(color: scheme.error),
            ),
          ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              _playfieldHeight = constraints.maxHeight;
              _placeWords();
              return Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  for (final word in _words)
                    Positioned(
                      top: word.y,
                      left: 0,
                      right: 0,
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: _malayChip(word.id),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        const Divider(height: 1),
        SizedBox(
          height:
              meaningListPaddingV * 2 +
              meaningChipHeight * meaningRows +
              meaningChipGap,
          child: LayoutBuilder(
            builder: (context, constraints) {
              _meaningListWidth = constraints.maxWidth;
              _refreshMeaningWindow();
              final ids = [
                for (final id in _meaningIds)
                  if (!_board.matched.contains(id)) id,
              ];
              final columns = (ids.length / meaningRows).ceil();
              return ListView.separated(
                controller: _meaningScroll,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: meaningListPaddingH,
                  vertical: meaningListPaddingV,
                ),
                itemCount: columns,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: meaningChipGap),
                itemBuilder: (context, column) {
                  final top = column * meaningRows;
                  final bottom = top + 1 < ids.length ? ids[top + 1] : null;
                  return Column(
                    children: [
                      _meaningTarget(ids[top]),
                      const SizedBox(height: meaningChipGap),
                      if (bottom != null)
                        _meaningTarget(bottom)
                      else
                        const SizedBox(height: meaningChipHeight),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _meaningTarget(String id) {
    return DragTarget<String>(
      onWillAcceptWithDetails: (details) =>
          _phase == _Phase.playing && !_board.matched.contains(details.data),
      onAcceptWithDetails: (details) => _drop(details.data, id),
      builder: (context, candidate, rejected) {
        return KeyedSubtree(
          key: ValueKey('meaning-$id'),
          child: _piece(
            _board.pairById(id).meaning,
            malay: false,
            highlighted: candidate.isNotEmpty,
          ),
        );
      },
    );
  }

  Widget _malayChip(String id) {
    return Draggable<String>(
      key: ValueKey('malay-$id'),
      data: id,
      dragAnchorStrategy: childDragAnchorStrategy,
      feedback: _piece(_board.pairById(id).word, malay: true),
      childWhenDragging: Opacity(
        opacity: 0.25,
        child: _piece(_board.pairById(id).word, malay: true),
      ),
      onDragStarted: () => setState(() => _draggingId = id),
      onDragEnd: (_) => _draggingId = null,
      child: _piece(_board.pairById(id).word, malay: true),
    );
  }

  Widget _piece(String label, {required bool malay, bool highlighted = false}) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: malay ? scheme.primaryContainer : scheme.surface,
      elevation: malay ? 3 : 0,
      shape: StadiumBorder(
        side: BorderSide(
          color: highlighted ? scheme.primary : scheme.outlineVariant,
          width: highlighted ? 2 : 1,
        ),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: malay ? 88 : meaningChipMinWidth,
          maxWidth: malay ? 220 : meaningChipMaxWidth,
        ),
        child: SizedBox(
          height: malay ? _chipHeight : meaningChipHeight,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: malay ? 16 : 10),
            child: Center(
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ),
        ),
      ),
    );
  }

  Widget _result(ThemeData theme) {
    final records = MatchStore.instance.records;
    final cleared = _phase == _Phase.cleared;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      children: [
        Text(cleared ? '完了' : '終了', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 12),
        Text(formatMatchElapsed(_elapsed), style: theme.textTheme.displaySmall),
        const SizedBox(height: 8),
        Text(
          '${widget.pairs.length}語 · ダメージ ${_board.damage} · HP ${_board.hp}',
        ),
        const SizedBox(height: 16),
        if (!cleared)
          const Text('マレー語チップが日本語に当たりました')
        else if (_saving)
          const Center(child: CircularProgressIndicator())
        else if (_saved)
          const Text('記録を保存しました'),
        if (_board.missed.isNotEmpty) ...[
          const SizedBox(height: 28),
          Text('間違えた単語', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          for (final pair in _board.missed)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(pair.word, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text(pair.meaning),
                ],
              ),
            ),
        ],
        if (_feedback != null) ...[
          const SizedBox(height: 8),
          Text(
            _feedback!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
        if (records.isNotEmpty) ...[
          const SizedBox(height: 28),
          Text('これまでの記録', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final record in records.take(8))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '${formatMatchElapsed(Duration(milliseconds: record.elapsedMs))} · ${record.wordCount}語 · ダメージ ${record.mistakes * matchCollisionDamage}',
              ),
            ),
        ],
      ],
    );
  }
}
