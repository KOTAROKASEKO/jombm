import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../course/course_catalog.dart';
import '../course/course_practice.dart';

class CoursePracticeScreen extends StatefulWidget {
  const CoursePracticeScreen({
    super.key,
    required this.lesson,
    this.initialStep = 0,
  });

  final CourseLesson lesson;
  final int initialStep;

  @override
  State<CoursePracticeScreen> createState() => _CoursePracticeScreenState();
}

class _CoursePracticeScreenState extends State<CoursePracticeScreen> {
  final _speech = SpeechToText();
  final _tts = FlutterTts();

  late final List<CourseExercise> _exercises;
  late int _index;

  int? _selectedChoice;
  bool _checked = false;
  bool _completed = false;
  bool _listening = false;
  bool _speaking = false;
  bool _speakPassed = false;
  bool _speakAttempted = false;
  bool _speechUnavailable = false;
  bool _speechReady = false;
  bool _ttsReady = false;
  String _heard = '';
  String? _speakMessage;
  String? _sttLocaleId;
  String? _malayTtsLanguage;

  @override
  void initState() {
    super.initState();
    _exercises = practiceFor(widget.lesson);
    final last = _exercises.isEmpty ? 0 : _exercises.length - 1;
    _index = widget.initialStep.clamp(0, last);
  }

  @override
  void dispose() {
    _speech.cancel();
    _tts.stop();
    super.dispose();
  }

  CourseExercise get _exercise => _exercises[_index];

  Future<void> _prepareTts() async {
    if (_ttsReady) return;
    await _tts.awaitSpeakCompletion(true);
    await _tts.setVolume(1);
    await _tts.setPitch(1);
    await _tts.setSpeechRate(
      defaultTargetPlatform == TargetPlatform.android ? 0.4 : 0.45,
    );
    final languages = await _tts.getLanguages;
    if (languages is List) {
      final ids = languages.map((item) => item.toString()).toList();
      _malayTtsLanguage = _pickLanguage(ids, const ['ms-MY', 'id-ID']);
      if (_malayTtsLanguage != null) {
        await _tts.setLanguage(_malayTtsLanguage!);
      }
    }
    _ttsReady = true;
  }

  static String? _pickLanguage(List<String> ids, List<String> candidates) {
    for (final candidate in candidates) {
      for (final id in ids) {
        if (id.replaceAll('_', '-').toLowerCase() == candidate.toLowerCase()) {
          return id;
        }
      }
    }
    return null;
  }

  Future<void> _play(String phrase) async {
    if (_speaking) return;
    setState(() => _speaking = true);
    try {
      await _prepareTts();
      await _tts.stop();
      await _tts.speak(phrase);
    } catch (_) {
      // TTS is unavailable in some test and emulator environments.
    } finally {
      if (mounted) setState(() => _speaking = false);
    }
  }

  Future<bool> _ensureSpeech() async {
    if (_speechReady) return true;
    try {
      final available = await _speech.initialize(
        onError: (error) {
          if (!mounted) return;
          setState(() {
            _listening = false;
            if (error.permanent) {
              _speakAttempted = true;
              _speakMessage = '音声の認識に失敗しました。もう一度試してください。';
            }
          });
        },
      );
      if (!available) return false;
      final locales = await _speech.locales();
      for (final candidate in ['ms_MY', 'ms-MY', 'id_ID', 'id-ID']) {
        final normalized = candidate.replaceAll('-', '_').toLowerCase();
        for (final locale in locales) {
          if (locale.localeId.replaceAll('-', '_').toLowerCase() ==
              normalized) {
            _sttLocaleId = locale.localeId;
            break;
          }
        }
        if (_sttLocaleId != null) break;
      }
      _speechReady = true;
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _listen(String phrase) async {
    if (_listening || _speakPassed) return;
    try {
      await _tts.stop();
    } catch (_) {}
    final ready = await _ensureSpeech();
    if (!mounted) return;
    if (!ready) {
      setState(() => _speechUnavailable = true);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('この端末では音声入力を使えません')));
      return;
    }
    setState(() {
      _listening = true;
      _heard = '';
      _speakMessage = null;
    });
    try {
      await _speech.listen(
        onResult: (result) {
          if (!mounted) return;
          final heard = result.recognizedWords.trim();
          final passed =
              result.finalResult && spokenPhraseMatches(heard, phrase);
          setState(() {
            _heard = heard;
            if (result.finalResult) {
              _listening = false;
              _speakAttempted = true;
              _speakPassed = passed;
              _speakMessage = heard.isEmpty
                  ? '聞き取れませんでした。もう一度言ってください。'
                  : passed
                  ? 'いい発音です'
                  : 'もう一度、画面のフレーズを言ってみてください';
            }
          });
        },
        listenOptions: SpeechListenOptions(
          localeId: _sttLocaleId,
          listenMode: ListenMode.confirmation,
          partialResults: true,
          listenFor: const Duration(seconds: 6),
          pauseFor: const Duration(seconds: 2),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _listening = false;
        _speakAttempted = true;
        _speakMessage = '音声の認識に失敗しました。もう一度試してください。';
      });
    }
  }

  void _check() {
    if (_selectedChoice == null || _checked) return;
    setState(() => _checked = true);
  }

  void _next() {
    try {
      _speech.stop();
    } catch (_) {}
    try {
      _tts.stop();
    } catch (_) {}
    if (_index >= _exercises.length - 1) {
      setState(() => _completed = true);
      return;
    }
    setState(() {
      _index++;
      _selectedChoice = null;
      _checked = false;
      _listening = false;
      _speakPassed = false;
      _speakAttempted = false;
      _heard = '';
      _speakMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_exercises.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.lesson.title)),
        body: const Center(child: Text('このレッスンの練習はまだありません')),
      );
    }
    if (_completed) return _completeScreen(context);

    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(widget.lesson.title)),
      body: Column(
        children: [
          _progress(scheme),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              children: [
                _kindLabel(context),
                const SizedBox(height: 16),
                switch (_exercise) {
                  SpeakExercise exercise => _speakBody(context, exercise),
                  GrammarExercise exercise => _grammarBody(context, exercise),
                },
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _bottomBar(context),
    );
  }

  Widget _progress(ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          for (var i = 0; i < _exercises.length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 8,
                decoration: BoxDecoration(
                  color: i <= _index
                      ? scheme.primary
                      : scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _kindLabel(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final speaking = _exercise is SpeakExercise;
    return Align(
      alignment: Alignment.centerLeft,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.secondaryContainer,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(
            speaking ? '発声練習' : '文法練習',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: scheme.onSecondaryContainer,
            ),
          ),
        ),
      ),
    );
  }

  Widget _speakBody(BuildContext context, SpeakExercise exercise) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'お手本を聞いて、声に出してみましょう。',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 20),
        Text(exercise.meaningJa, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                exercise.phrase,
                style: theme.textTheme.headlineMedium,
              ),
            ),
            IconButton(
              tooltip: '聞く',
              onPressed: _speaking ? null : () => _play(exercise.phrase),
              icon: const Icon(Icons.volume_up),
            ),
          ],
        ),
        if (_heard.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            _heard,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
        ],
      ],
    );
  }

  Widget _grammarBody(BuildContext context, GrammarExercise exercise) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(exercise.promptJa, style: theme.textTheme.titleLarge),
        const SizedBox(height: 16),
        for (var i = 0; i < exercise.choices.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _choiceCard(
            context: context,
            scheme: scheme,
            label: exercise.choices[i],
            index: i,
            answerIndex: exercise.answerIndex,
          ),
        ],
      ],
    );
  }

  Widget _choiceCard({
    required BuildContext context,
    required ColorScheme scheme,
    required String label,
    required int index,
    required int answerIndex,
  }) {
    final selected = _selectedChoice == index;
    Color color = scheme.surfaceContainerHighest;
    var border = Colors.transparent;
    if (!_checked && selected) {
      color = scheme.primaryContainer;
      border = scheme.primary;
    } else if (_checked && index == answerIndex) {
      color = scheme.primaryContainer;
      border = scheme.primary;
    } else if (_checked && selected) {
      color = scheme.errorContainer;
      border = scheme.error;
    }

    return Material(
      color: color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: border, width: 2),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _checked ? null : () => setState(() => _selectedChoice = index),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(label, style: Theme.of(context).textTheme.titleMedium),
        ),
      ),
    );
  }

  Widget _bottomBar(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final exercise = _exercise;
    final correct =
        exercise is GrammarExercise && _selectedChoice == exercise.answerIndex;
    Color? color;
    if (exercise is GrammarExercise && _checked) {
      color = correct ? scheme.primaryContainer : scheme.errorContainer;
    } else if (exercise is SpeakExercise && _speakPassed) {
      color = scheme.primaryContainer;
    } else if (exercise is SpeakExercise &&
        _speakAttempted &&
        !_speakPassed &&
        !_listening) {
      color = scheme.errorContainer;
    }

    return Material(
      color: color ?? scheme.surface,
      elevation: 8,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: switch (exercise) {
            SpeakExercise speak => _speakActions(context, speak),
            GrammarExercise grammar => _grammarActions(
              context,
              grammar,
              correct,
            ),
          },
        ),
      ),
    );
  }

  Widget _speakActions(BuildContext context, SpeakExercise exercise) {
    if (_speakPassed) {
      return _feedback(
        context,
        title: 'いい発音です',
        body: exercise.meaningJa,
        action: _isLast ? '完了' : '続ける',
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_speakMessage != null) ...[
          Text(_speakMessage!, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
        ],
        FilledButton.icon(
          onPressed: _listening ? null : () => _listen(exercise.phrase),
          icon: Icon(_listening ? Icons.hearing : Icons.mic),
          label: Text(_listening ? '聞いています…' : '発声する'),
        ),
        if (_speakAttempted || _speechUnavailable) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: _listening ? null : _next,
            child: Text(_isLast ? '完了' : '続ける'),
          ),
        ],
      ],
    );
  }

  Widget _grammarActions(
    BuildContext context,
    GrammarExercise exercise,
    bool correct,
  ) {
    if (!_checked) {
      return FilledButton(
        onPressed: _selectedChoice == null ? null : _check,
        child: const Text('チェック'),
      );
    }
    return _feedback(
      context,
      title: correct ? '正解！' : '正解を確認しましょう',
      body: exercise.explanationJa,
      action: _isLast ? '完了' : '続ける',
    );
  }

  bool get _isLast => _index >= _exercises.length - 1;

  Widget _feedback(
    BuildContext context, {
    required String title,
    required String body,
    required String action,
  }) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(body),
        const SizedBox(height: 12),
        FilledButton(onPressed: _next, child: Text(action)),
      ],
    );
  }

  Widget _completeScreen(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Icon(
                Icons.celebration,
                size: 72,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'レッスン完了',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                widget.lesson.title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
              const Spacer(),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('コースに戻る'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
