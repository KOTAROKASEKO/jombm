import '../characters/chat_character.dart';
import '../chat/user_memory.dart';
import 'gemini_client.dart';

class MalayTutor {
  MalayTutor({
    GeminiClient? client,
    ChatCharacter? character,
    this.lessonCoach,
  }) : _client = client ?? GeminiClient(),
       _character = character ?? CharacterCatalog.aina;

  ChatCharacter _character;
  String? lessonCoach;

  ChatCharacter get character => _character;

  late String _opening = _character.opening();
  List<String> _memories = const [];

  String get opening => _opening;

  void setMemories(List<String> notes) {
    _memories = List.unmodifiable(notes.take(UserMemoryStore.recentLimit));
  }

  String get _systemPrompt {
    final lesson = lessonCoach;
    return '''
You are role-playing a real Malaysian person in a language-practice chat.
Never say you are an AI. Stay in character.

Shared Malay style:
Use casual spoken Bahasa Melayu (Malaysia) only when speaking Malay. Never Bahasa Indonesia. Never stiff textbook Malay.
Keep replies short: one or two sentences.
Use tak, nak, dah, je, kat, lah, kan, awak, jom when natural.
If the learner makes a Malay mistake, say the natural daily phrase once, then continue.

Language matching:
- If they use Japanese, reply in natural casual Japanese, in character. A short Malay example is OK.
- If they use Malay, reply in casual spoken Malay only, in character.
- If they use English, reply in Japanese, in character.

Do not use markdown, bullet points, or romanization.

Character:
${_character.personality}
${lesson == null || lesson.isEmpty ? '' : 'Lesson focus: $lesson'}
${learnerNotesForPrompt(_memories)}''';
  }

  final GeminiClient _client;
  late final List<Map<String, String>> _contents = [
    {'role': 'model', 'text': _opening},
  ];

  static const _historyLimit = 8;

  void setCharacter(ChatCharacter character, {String? lessonCoach}) {
    _character = character;
    this.lessonCoach = lessonCoach;
  }

  void reset() {
    _opening = _character.opening();
    _contents
      ..clear()
      ..add({'role': 'model', 'text': _opening});
  }

  void restore(List<Map<String, String>> messages) {
    _contents
      ..clear()
      ..addAll(messages);
    if (_contents.isEmpty) {
      reset();
    }
  }

  Future<String> reply(String userSpeech) async {
    _contents.add({'role': 'user', 'text': userSpeech});
    try {
      final text = await _client.generate(
        systemPrompt: _systemPrompt,
        contents: _recentContents,
        maxOutputTokens: 140,
      );
      _contents.add({'role': 'model', 'text': text});
      return text;
    } catch (error) {
      _contents.removeLast();
      rethrow;
    }
  }

  List<Map<String, String>> get _recentContents {
    if (_contents.length <= _historyLimit) return List.of(_contents);
    return _contents.sublist(_contents.length - _historyLimit);
  }
}
