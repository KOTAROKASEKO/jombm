import 'package:flutter/material.dart';

import '../conversation/sentence_lookup.dart';
import '../notes/notes_store.dart';
import '../notes/vocab_note.dart';

Future<void> showSentenceSheet({
  required BuildContext context,
  required String sentence,
  SentenceTranslation? initial,
  void Function(SentenceTranslation translation)? onTranslated,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: _SentenceSheet(
          sentence: sentence,
          initial: initial,
          onTranslated: onTranslated,
        ),
      );
    },
  );
}

class _SentenceSheet extends StatefulWidget {
  const _SentenceSheet({
    required this.sentence,
    this.initial,
    this.onTranslated,
  });

  final String sentence;
  final SentenceTranslation? initial;
  final void Function(SentenceTranslation translation)? onTranslated;

  @override
  State<_SentenceSheet> createState() => _SentenceSheetState();
}

class _SentenceSheetState extends State<_SentenceSheet> {
  final _lookup = SentenceLookup();
  SentenceTranslation? _result;
  Object? _error;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final initial = widget.initial;
    if (initial != null &&
        readableEnglish(
              initial.english,
              original: initial.original,
              translation: initial.translation,
            ) !=
            null) {
      setState(() {
        _result = initial;
        _loading = false;
      });
      return;
    }
    try {
      final result = await _lookup.translate(widget.sentence);
      widget.onTranslated?.call(result);
      if (!mounted) return;
      setState(() {
        _result = result;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _addToNotes() async {
    final result = _result;
    if (result == null || _saving) return;
    setState(() => _saving = true);
    final added = await NotesStore.instance.add(
      VocabNote(
        word: result.original,
        meaning: result.translation,
        sentence: result.original,
        usage: result.note,
        createdAt: DateTime.now(),
      ),
    );
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(added ? 'ノートに追加しました' : 'すでにノートにあります'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final alreadySaved = NotesStore.instance.contains(widget.sentence);
    final theme = Theme.of(context);
    final result = _result;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('文の翻訳', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            Text(
              widget.sentence,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Text(_error.toString())
            else if (result != null) ...[
              Text(result.translation, style: theme.textTheme.titleMedium),
              if (readableEnglish(
                    result.english,
                    original: result.original,
                    translation: result.translation,
                  )
                  case final english?) ...[
                const SizedBox(height: 8),
                Text(
                  english,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (result.note != null) ...[
                const SizedBox(height: 8),
                Text(result.note!),
              ],
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: (!_loading && _result != null && !alreadySaved)
                  ? _addToNotes
                  : null,
              icon: const Icon(Icons.note_add_outlined),
              label: Text(alreadySaved ? 'ノートに追加済み' : 'ノートに追加'),
            ),
          ],
        ),
      ),
    );
  }
}
