import 'package:flutter/material.dart';

import '../characters/chat_character.dart';
import '../chat/chat_launch.dart';
import '../course/situation_repository.dart';

class CourseScreen extends StatefulWidget {
  const CourseScreen({super.key});

  @override
  State<CourseScreen> createState() => _CourseScreenState();
}

class _CourseScreenState extends State<CourseScreen> {
  late Future<List<CourseSituation>> _situations;

  @override
  void initState() {
    super.initState();
    _situations = SituationRepository.instance.load();
  }

  void _reload() {
    setState(() {
      _situations = SituationRepository.instance.load();
    });
  }

  void _start(CourseSituation situation) {
    ChatLaunch.instance.open(
      ChatLaunchRequest(
        characterId: CharacterCatalog.aina.id,
        lessonId: situation.id,
        lessonTitle: situation.title,
        coach:
            'Situation: ${situation.title}. '
            'Lines already said: ${situation.messages.map((line) => line.text).join(' | ')}. '
            'Continue this scene in simple casual Malay.',
        script: [for (final line in situation.messages) line.text],
        scriptFromUser: [for (final line in situation.messages) line.isUser],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('コース')),
      body: FutureBuilder<List<CourseSituation>>(
        future: _situations,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('状況を読み込めませんでした'),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _reload,
                      child: const Text('再読み込み'),
                    ),
                  ],
                ),
              ),
            );
          }
          final situations = snapshot.data ?? const <CourseSituation>[];
          if (situations.isEmpty) {
            return const Center(child: Text('状況がまだありません'));
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              Text(
                '状況を選んでコースを開始できます。',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              for (final situation in situations) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          situation.title,
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: situation.messages.isEmpty
                              ? null
                              : () => _start(situation),
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('コース開始'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ],
          );
        },
      ),
    );
  }
}
