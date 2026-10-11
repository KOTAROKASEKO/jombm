import 'package:flutter/material.dart';

import '../chat/chat_session.dart';
import '../chat/chat_store.dart';
import '../course/situation_repository.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, this.embedded = false, this.onSelected});

  final bool embedded;
  final ValueChanged<String>? onSelected;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await ChatStore.instance.load();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _delete(ChatSession session) async {
    await ChatStore.instance.delete(session.id);
    if (mounted) setState(() {});
  }

  Future<void> _promote(ChatSession session) async {
    final situation = CourseSituation.fromConversation(
      id: session.id,
      fallbackTitle: session.title,
      lessonTitle: session.lessonTitle,
      lines: [
        for (final message in session.messages)
          CourseLine(text: message.text, isUser: message.isUser),
      ],
      updatedAt: session.updatedAt,
    );
    if (situation.messages.isEmpty) {
      _showMessage('公開できる会話がありません');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('コースに公開'),
        content: Text('「${situation.title}」を公開コースに追加します。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('公開する'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await SituationRepository.instance.publish(situation);
    } catch (_) {
      if (mounted) _showMessage('公開できませんでした');
      return;
    }
    if (mounted) _showMessage('コースに公開しました');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final sessions = ChatStore.instance.sessions
        .where((session) => session.hasUserMessage)
        .toList();

    final body = _loading
          ? const Center(child: CircularProgressIndicator())
          : sessions.isEmpty
          ? const Center(child: Text('過去の会話はまだありません'))
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: sessions.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final session = sessions[index];
                return Card(
                  child: Row(
                    children: [
                      Expanded(
                        child: ListTile(
                          title: Text(session.title),
                          subtitle: Text(
                            [
                              session.lessonTitle,
                              _formatTime(session.updatedAt),
                            ].whereType<String>().join(' · '),
                          ),
                          onTap: () {
                            final onSelected = widget.onSelected;
                            if (onSelected != null) {
                              onSelected(session.id);
                            } else {
                              Navigator.of(context).pop(session.id);
                            }
                          },
                          onLongPress: () => _promote(session),
                        ),
                      ),
                      IconButton(
                        tooltip: 'コースに公開',
                        onPressed: () => _promote(session),
                        icon: const Icon(Icons.public),
                      ),
                      IconButton(
                        tooltip: '削除',
                        onPressed: () => _delete(session),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                );
              },
            );
    if (widget.embedded) return body;
    return Scaffold(
      appBar: AppBar(title: const Text('会話履歴')),
      body: body,
    );
  }

  static String _formatTime(DateTime time) {
    final local = time.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.year}/$month/$day $hour:$minute';
  }
}
