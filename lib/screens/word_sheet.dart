import 'package:flutter/material.dart';

import '../conversation/word_lookup.dart';
import '../notes/notes_store.dart';
import '../notes/vocab_note.dart';

Future<void> showWordSheet({
  required BuildContext context,
  required String word,
  required String sentence,
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
        child: _WordSheet(word: word, sentence: sentence),
      );
    },
  );
}

class _WordSheet extends StatefulWidget {
  const _WordSheet({required this.word, required this.sentence});

  final String word;
  final String sentence;

  @override
  State<_WordSheet> createState() => _WordSheetState();
}

class _WordSheetState extends State<_WordSheet> {
  final _lookup = WordLookup();
  WordMeaning? _meaning;
  Object? _error;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadMeaning();
  }

  Future<void> _loadMeaning() async {
    try {
      final sentence = widget.sentence.trim();
      final meaning = await _lookup.lookup(
        word: widget.word,
        sentence: sentence.isEmpty ? widget.word : sentence,
      );
      if (!mounted) return;
      setState(() {
        _meaning = meaning;
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
    final meaning = _meaning;
    if (meaning == null || _saving) return;
    setState(() => _saving = true);
    final added = await NotesStore.instance.add(
      VocabNote(
        word: meaning.word,
        meaning: meaning.meaning,
        sentence: widget.sentence,
        usage: meaning.note,
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
    final alreadySaved = NotesStore.instance.contains(widget.word);
    final theme = Theme.of(context);
    final meaning = _meaning;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.word, style: theme.textTheme.headlineSmall),
            const SizedBox(height: 20),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Text(_error.toString())
            else if (meaning != null) ...[
              if (meaning.senses.isNotEmpty)
                for (final sense in meaning.senses) ...[
                  Text(
                    sense.partOfSpeech,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(sense.japanese, style: theme.textTheme.titleMedium),
                  if (sense.example != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '例: ${sense.example}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: 16),
                ]
              else ...[
                Text(meaning.meaning, style: theme.textTheme.titleMedium),
                if (meaning.note != null) ...[
                  const SizedBox(height: 8),
                  Text(meaning.note!),
                ],
                const SizedBox(height: 8),
              ],
              if (meaning.english != null) ...[
                Text(
                  meaning.english!,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              if (meaning.sourceLabel != null)
                Text(
                  meaning.sourceLabel!,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: (!_loading && _meaning != null && !alreadySaved)
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
