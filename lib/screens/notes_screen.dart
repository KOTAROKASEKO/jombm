import 'package:flutter/material.dart';

import '../notes/match_board.dart';
import '../notes/notes_store.dart';
import '../notes/vocab_note.dart';
import '../widgets/translate_selection.dart';
import 'match_screen.dart';
import 'word_sheet.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await NotesStore.instance.load();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _remove(VocabNote note) async {
    await NotesStore.instance.remove(note.word);
    if (mounted) setState(() {});
  }

  void _openMatch() {
    final pairs = pairsFromNotes(NotesStore.instance.notes);
    if (pairs.isEmpty) return;
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => MatchScreen(pairs: pairs)));
  }

  Future<void> _addWord() async {
    final draft = await showModalBottomSheet<_WordDraft>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: const _AddWordSheet(),
        );
      },
    );
    if (draft == null || !mounted) return;
    await showWordSheet(
      context: context,
      word: draft.word,
      sentence: draft.sentence,
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final notes = NotesStore.instance.notes;
    final hasMatch = pairsFromNotes(notes).isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('単語')),
      floatingActionButton: FloatingActionButton(
        tooltip: '単語を追加',
        onPressed: _addWord,
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : notes.isEmpty
          ? const Center(child: Text('会話の単語や文を追加できます'))
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
              itemCount: notes.length + (hasMatch ? 1 : 0),
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                if (hasMatch && index == 0) {
                  return FilledButton.icon(
                    onPressed: _openMatch,
                    icon: const Icon(Icons.extension),
                    label: const Text('意味合わせ'),
                  );
                }
                final note = notes[hasMatch ? index - 1 : index];
                final theme = Theme.of(context);
                return Card(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                note.word,
                                style: theme.textTheme.titleMedium,
                              ),
                              const SizedBox(height: 4),
                              Text(note.meaning),
                              if (note.usage != null) ...[
                                const SizedBox(height: 4),
                                Text(note.usage!),
                              ],
                              if (note.sentence.isNotEmpty &&
                                  note.sentence != note.word) ...[
                                const SizedBox(height: 4),
                                Text(
                                  note.sentence,
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: '削除',
                        onPressed: () => _remove(note),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class _WordDraft {
  const _WordDraft({required this.word, required this.sentence});

  final String word;
  final String sentence;
}

class _AddWordSheet extends StatefulWidget {
  const _AddWordSheet();

  @override
  State<_AddWordSheet> createState() => _AddWordSheetState();
}

class _AddWordSheetState extends State<_AddWordSheet> {
  final _wordController = TextEditingController();
  final _sentenceController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _wordController.dispose();
    _sentenceController.dispose();
    super.dispose();
  }

  void _submit() {
    final word = _wordController.text.trim();
    if (word.isEmpty) {
      setState(() => _error = '単語を入力してください');
      return;
    }
    Navigator.of(
      context,
    ).pop(_WordDraft(word: word, sentence: _sentenceController.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('単語を追加', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(
              controller: _wordController,
              autofocus: true,
              contextMenuBuilder: translateSelectionMenu,
              textCapitalization: TextCapitalization.none,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'マレー語の単語',
                errorText: _error,
              ),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _sentenceController,
              contextMenuBuilder: translateSelectionMenu,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: '例文（任意）',
                hintText: '会話の一文があると意味が正確になります',
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _submit,
              icon: const Icon(Icons.search),
              label: const Text('意味を調べる'),
            ),
          ],
        ),
      ),
    );
  }
}
