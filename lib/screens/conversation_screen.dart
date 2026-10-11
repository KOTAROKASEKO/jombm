import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../auth/auth_service.dart';
import '../characters/chat_character.dart';
import '../chat/chat_launch.dart';
import '../chat/user_memory.dart';
import '../chat/chat_message.dart';
import '../chat/chat_session.dart';
import '../chat/chat_store.dart';
import '../conversation/malay_tutor.dart';
import '../conversation/sentence_lookup.dart';
import '../notes/notes_store.dart';
import '../screens/character_picker.dart';
import '../screens/history_screen.dart';
import '../screens/sentence_sheet.dart';
import '../screens/word_sheet.dart';
import '../widgets/tappable_malay_text.dart';
import '../widgets/translate_selection.dart';

enum ConversationState { idle, listening, thinking, speaking }

class ConversationScreen extends StatefulWidget {
  const ConversationScreen({super.key});

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final _speech = SpeechToText();
  final _tts = FlutterTts();
  final _tutor = MalayTutor();
  final _scrollController = ScrollController();
  final _input = TextEditingController();
  final _inputFocus = FocusNode();

  ConversationState _state = ConversationState.idle;
  bool _speechReady = false;
  bool _sending = false;
  bool _wantListening = false;
  String _committedText = '';
  String? _sttLocaleId;
  String? _malayTtsLanguage;
  String? _japaneseTtsLanguage;

  String? _sessionId;
  String? _lessonTitle;
  Timer? _scriptTimer;
  List<String> _scriptLines = const [];
  List<bool> _scriptFromUser = const [];
  int _scriptCursor = 0;
  bool _scriptTyping = false;
  bool _memoriesReady = false;

  late final List<ChatMessage> _messages = [
    ChatMessage(text: _tutor.opening, isUser: false),
  ];

  String? get _statusLabel {
    switch (_state) {
      case ConversationState.idle:
        return null;
      case ConversationState.listening:
        return '話してください。止めたら文字を直せます';
      case ConversationState.thinking:
        return '考えています…';
      case ConversationState.speaking:
        return '読み上げています…';
    }
  }

  bool get _canSend =>
      !_sending &&
      _state != ConversationState.thinking &&
      _input.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _input.addListener(_onInputChanged);
    _inputFocus.addListener(_onFocusChanged);
    ChatLaunch.instance.addListener(_onChatLaunch);
    _prepareTts();
    NotesStore.instance.load();
    unawaited(_loadUserMemory());
  }

  @override
  void dispose() {
    _stopScript();
    ChatLaunch.instance.removeListener(_onChatLaunch);
    _wantListening = false;
    _speech.cancel();
    _tts.stop();
    _input.removeListener(_onInputChanged);
    _inputFocus.removeListener(_onFocusChanged);
    _input.dispose();
    _inputFocus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onInputChanged() {
    if (mounted) setState(() {});
  }

  void _onFocusChanged() {
    if (_inputFocus.hasFocus && _wantListening) {
      _stopListeningKeepText();
    }
  }

  Future<void> _prepareTts() async {
    try {
      await _tts.awaitSpeakCompletion(true);
      await _tts.setVolume(1);
      await _tts.setPitch(1);
      await _tts.setSpeechRate(
        defaultTargetPlatform == TargetPlatform.android ? 0.4 : 0.45,
      );

      final languages = await _tts.getLanguages;
      if (languages is List) {
        final ids = languages.map((e) => e.toString()).toList();
        _malayTtsLanguage = _pickLanguage(ids, const ['ms-MY', 'id-ID']);
        _japaneseTtsLanguage = _pickLanguage(ids, const ['ja-JP', 'ja']);
        final selected = _malayTtsLanguage ?? _japaneseTtsLanguage;
        if (selected != null) {
          await _tts.setLanguage(selected);
        }
      }
    } catch (_) {
      // TTS is unavailable in some test / emulator environments.
    }
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

  static bool _looksJapanese(String text) =>
      RegExp(r'[\u3040-\u30ff\u4e00-\u9fff]').hasMatch(text);

  Future<void> _speak(String text) async {
    final language = _looksJapanese(text)
        ? _japaneseTtsLanguage
        : _malayTtsLanguage;
    if (language != null) {
      await _tts.setLanguage(language);
    }
    await _tts.speak(text);
  }

  Future<bool> _ensureSpeech() async {
    if (_speechReady) return true;
    final available = await _speech.initialize(
      onStatus: (status) {
        if (!_wantListening || _sending) return;
        if (status == 'done' || status == 'notListening') {
          _resumeListening();
        }
      },
      onError: (error) {
        if (!_wantListening || _sending) return;
        if (!error.permanent) {
          _resumeListening();
          return;
        }
        _wantListening = false;
        if (!mounted) return;
        setState(() => _state = ConversationState.idle);
        _showMessage('音声の認識に失敗しました。');
      },
    );
    if (!available) return false;

    final locales = await _speech.locales();
    for (final candidate in ['ms_MY', 'ms-MY', 'id_ID', 'id-ID']) {
      final normalized = candidate.replaceAll('-', '_').toLowerCase();
      for (final locale in locales) {
        if (locale.localeId.replaceAll('-', '_').toLowerCase() == normalized) {
          _sttLocaleId = locale.localeId;
          break;
        }
      }
      if (_sttLocaleId != null) break;
    }

    _speechReady = true;
    return true;
  }

  Future<void> _listen() async {
    if (!_wantListening || _sending) return;
    await _speech.listen(
      onResult: (result) {
        if (!mounted || !_wantListening) return;
        final live = result.recognizedWords.trim();
        final display = [
          _committedText,
          live,
        ].where((text) => text.isNotEmpty).join(' ');
        _setInputText(display);
        if (result.finalResult && live.isNotEmpty) {
          _committedText = display;
        }
      },
      listenOptions: SpeechListenOptions(
        localeId: _sttLocaleId,
        listenMode: ListenMode.dictation,
        partialResults: true,
        cancelOnError: false,
        listenFor: const Duration(minutes: 5),
        pauseFor: const Duration(seconds: 30),
      ),
    );
  }

  Future<void> _resumeListening() async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted || !_wantListening || _sending) return;
    if (_speech.isListening) return;
    await _listen();
  }

  void _setInputText(String text) {
    _input.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  Future<void> _stopListeningKeepText() async {
    _wantListening = false;
    await _speech.stop();
    if (!mounted) return;
    if (_state == ConversationState.listening) {
      setState(() => _state = ConversationState.idle);
    }
    _inputFocus.requestFocus();
  }

  Future<void> _onMicPressed() async {
    switch (_state) {
      case ConversationState.thinking:
        return;
      case ConversationState.speaking:
        await _tts.stop();
        if (mounted) setState(() => _state = ConversationState.idle);
        return;
      case ConversationState.listening:
        await _stopListeningKeepText();
        return;
      case ConversationState.idle:
        final ready = await _ensureSpeech();
        if (!ready) {
          _showMessage('マイクまたは音声認識を許可してください。');
          return;
        }
        _inputFocus.unfocus();
        _wantListening = true;
        _committedText = _input.text.trim();
        setState(() => _state = ConversationState.listening);
        await _listen();
    }
  }

  Future<void> _onSendPressed() async {
    if (_wantListening) {
      _wantListening = false;
      await _speech.stop();
    }
    await _submitTranscript(_input.text);
  }

  Future<void> _submitTranscript(String rawText) async {
    if (_sending) return;
    final spoken = rawText.trim();
    if (spoken.isEmpty) {
      if (mounted) setState(() => _state = ConversationState.idle);
      return;
    }

    _sending = true;
    _wantListening = false;
    await _speech.stop();
    _inputFocus.unfocus();
    if (!mounted) {
      _sending = false;
      return;
    }

    _input.clear();
    _committedText = '';
    setState(() {
      _messages.add(ChatMessage(text: spoken, isUser: true));
      _state = ConversationState.thinking;
    });
    _scrollToEnd();

    try {
      if (!_memoriesReady) await _loadUserMemory();
      final reply = await _tutor.reply(spoken);
      unawaited(_rememberLearner(spoken));
      if (!mounted) return;
      setState(() {
        _messages.add(ChatMessage(text: reply, isUser: false));
        _state = ConversationState.speaking;
      });
      _scrollToEnd();
      try {
        await _speak(reply);
      } catch (_) {
        // Keep the text reply even if speech playback fails.
      }
    } catch (error) {
      if (mounted) {
        _showMessage(error.toString());
      }
    } finally {
      _sending = false;
      if (mounted) setState(() => _state = ConversationState.idle);
      await _persistSession();
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  void _onChatLaunch() {
    final request = ChatLaunch.instance.take();
    if (request == null) return;
    if (request.script.isNotEmpty) {
      _startScript(
        lines: request.script,
        fromUser: request.scriptFromUser,
        title: request.lessonTitle,
        character: CharacterCatalog.byId(request.characterId),
        coach: request.coach,
      );
      return;
    }
    _startNewChat(
      character: CharacterCatalog.byId(request.characterId),
      lessonTitle: request.lessonTitle,
      lessonCoach: request.coach,
    );
  }

  void _stopScript() {
    _scriptTimer?.cancel();
    _scriptTimer = null;
    _scriptLines = const [];
    _scriptFromUser = const [];
    _scriptCursor = 0;
    _scriptTyping = false;
  }

  Future<void> _startScript({
    required List<String> lines,
    List<bool> fromUser = const [],
    String? title,
    ChatCharacter? character,
    String? coach,
  }) async {
    _stopScript();
    _wantListening = false;
    unawaited(_speech.stop().then((_) {}, onError: (_) {}));
    unawaited(_tts.stop().then((_) {}, onError: (_) {}));
    await _persistSession();
    await ChatStore.instance.setCurrent(null);
    _sessionId = null;
    _lessonTitle = title;
    _tutor.setCharacter(character ?? CharacterCatalog.aina, lessonCoach: coach);
    await _loadUserMemory();
    _tutor.reset();
    _input.clear();
    _committedText = '';
    final scriptLines = <String>[];
    final scriptFromUser = <bool>[];
    for (var i = 0; i < lines.length; i++) {
      final text = lines[i].trim();
      if (text.isEmpty) continue;
      scriptLines.add(text);
      scriptFromUser.add(
        i < fromUser.length ? fromUser[i] : scriptFromUser.length.isOdd,
      );
    }
    _scriptLines = scriptLines;
    _scriptFromUser = scriptFromUser;
    _scriptCursor = 0;
    if (!mounted) return;
    setState(() {
      _messages.clear();
      _state = ConversationState.idle;
      _scriptTyping = _scriptLines.isNotEmpty;
    });
    _scrollToEnd();
    _scheduleScriptLine();
  }

  void _scheduleScriptLine() {
    _scriptTimer?.cancel();
    if (_scriptCursor >= _scriptLines.length) {
      if (mounted) setState(() => _scriptTyping = false);
      return;
    }
    _scriptTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      final line = _scriptLines[_scriptCursor];
      final fromUser = _scriptFromUser[_scriptCursor];
      _scriptCursor++;
      setState(() {
        _messages.add(ChatMessage(text: line, isUser: fromUser));
        _scriptTyping = _scriptCursor < _scriptLines.length;
      });
      _tutor.restore([
        for (final message in _messages)
          {'role': message.isUser ? 'user' : 'model', 'text': message.text},
      ]);
      _scrollToEnd();
      if (_scriptCursor < _scriptLines.length) _scheduleScriptLine();
    });
  }

  Future<void> _applySession(ChatSession session) async {
    _stopScript();
    _sessionId = session.id;
    _lessonTitle = session.lessonTitle;
    _tutor.setCharacter(CharacterCatalog.byId(session.characterId));
    await _loadUserMemory();
    _messages
      ..clear()
      ..addAll(
        session.messages.map(
          (message) => ChatMessage.fromJson(message.toJson()),
        ),
      );
    _tutor.restore([
      for (final message in _messages)
        {'role': message.isUser ? 'user' : 'model', 'text': message.text},
    ]);
    setState(() {});
    _scrollToEnd();
  }

  Future<void> _persistSession() async {
    if (!_messages.any((message) => message.isUser)) return;
    _sessionId ??= DateTime.now().microsecondsSinceEpoch.toString();
    await ChatStore.instance.upsert(
      ChatSession(
        id: _sessionId!,
        title: ChatSession.titleFrom(_messages),
        updatedAt: DateTime.now(),
        messages: [
          for (final message in _messages)
            ChatMessage.fromJson(message.toJson()),
        ],
        characterId: _tutor.character.id,
        lessonTitle: _lessonTitle,
      ),
    );
  }

  Future<void> _openSession(String selectedId) async {
    await ChatStore.instance.load();
    if (!mounted) return;
    ChatSession? session;
    for (final item in ChatStore.instance.sessions) {
      if (item.id == selectedId) {
        session = item;
        break;
      }
    }
    if (session == null) return;
    await ChatStore.instance.setCurrent(selectedId);
    if (!mounted) return;
    await _applySession(session);
  }

  Future<void> _loadUserMemory() async {
    final notes = await UserMemoryStore.instance.recent();
    _tutor.setMemories(notes);
    _memoriesReady = true;
  }

  Future<void> _rememberLearner(String message) async {
    try {
      await UserMemoryStore.instance.capture(message);
    } catch (_) {
      // A missed note should not interrupt the chat.
    }
  }

  Future<void> _startNewChat({
    ChatCharacter? character,
    String? lessonTitle,
    String? lessonCoach,
  }) async {
    _stopScript();
    _wantListening = false;
    await _speech.stop();
    await _tts.stop();
    await _persistSession();
    await ChatStore.instance.setCurrent(null);
    _sessionId = null;
    _lessonTitle = lessonTitle;
    _tutor.setCharacter(
      character ?? _tutor.character,
      lessonCoach: lessonCoach,
    );
    _memoriesReady = false;
    await _loadUserMemory();
    _tutor.reset();
    _input.clear();
    if (!mounted) return;
    setState(() {
      _messages
        ..clear()
        ..add(ChatMessage(text: _tutor.opening, isUser: false));
      _state = ConversationState.idle;
      _committedText = '';
    });
  }

  Future<void> _pickCharacter() async {
    final selected = await showCharacterPicker(
      context: context,
      selected: _tutor.character,
    );
    if (selected == null || selected.id == _tutor.character.id) return;
    await _startNewChat(character: selected);
  }

  Future<void> _showSentenceTranslation(ChatMessage message) async {
    await showSentenceSheet(
      context: context,
      sentence: message.text,
      initial: message.translation,
      onTranslated: (result) {
        if (!mounted) return;
        setState(() => message.translation = result);
        _persistSession();
      },
    );
  }

  static const _copyPhrases = [
    'マレー語で__ってなんていうの',
    '_と_の違いは何',
  ];

  Future<void> _copyPhrase(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    _showMessage('コピーしました');
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _signOut() async {
    _wantListening = false;
    await _speech.cancel();
    await _tts.stop();
    try {
      await AuthService().signOut();
    } catch (error) {
      if (!mounted) return;
      final message = authErrorMessage(error);
      if (message.isEmpty) return;
      _showMessage(message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final canTapMic = _state != ConversationState.thinking;

    return Scaffold(
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                leading: const Icon(Icons.add_comment_outlined),
                title: const Text('新しいチャット'),
                onTap: () {
                  Navigator.of(context).pop();
                  _startNewChat();
                },
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text(
                  '履歴',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              Expanded(
                child: HistoryScreen(
                  embedded: true,
                  onSelected: (id) {
                    Navigator.of(context).pop();
                    _openSession(id);
                  },
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('サインアウト'),
                onTap: () {
                  Navigator.of(context).pop();
                  _signOut();
                },
              ),
            ],
          ),
        ),
      ),
      appBar: AppBar(
        title: const Text('マレー語で会話'),
        actions: [
          IconButton(
            tooltip: 'キャラクター',
            onPressed: _pickCharacter,
            icon: const Icon(Icons.face_retouching_natural),
          ),
        ],
      ),
      body: Column(
        children: [
          InkWell(
            onTap: _pickCharacter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Color(_tutor.character.colorValue),
                    child: Text(
                      _tutor.character.initial,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _tutor.character.nameJa,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        Text(
                          _lessonTitle == null
                              ? _tutor.character.roleJa
                              : '${_tutor.character.roleJa} · $_lessonTitle',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              itemCount: _messages.length + (_scriptTyping ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= _messages.length) {
                  final fromUser =
                      _scriptCursor < _scriptFromUser.length &&
                      _scriptFromUser[_scriptCursor];
                  return _TypingBubble(fromUser: fromUser);
                }
                final message = _messages[index];
                return _MessageBubble(
                  message: message,
                  colorScheme: colorScheme,
                  onWordTap: (word) {
                    showWordSheet(
                      context: context,
                      word: word,
                      sentence: message.text,
                    );
                  },
                  onTranslate: () => _showSentenceTranslation(message),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(
                children: [
                  if (_statusLabel != null) ...[
                    Text(
                      _statusLabel!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      IconButton.filledTonal(
                        tooltip: _state == ConversationState.listening
                            ? '録音を止める'
                            : '音声入力',
                        onPressed: canTapMic ? _onMicPressed : null,
                        style: IconButton.styleFrom(
                          backgroundColor: _state == ConversationState.listening
                              ? colorScheme.errorContainer
                              : null,
                          foregroundColor: _state == ConversationState.listening
                              ? colorScheme.onErrorContainer
                              : null,
                        ),
                        icon: Icon(switch (_state) {
                          ConversationState.listening => Icons.stop,
                          ConversationState.thinking => Icons.hourglass_top,
                          ConversationState.speaking => Icons.volume_up,
                          ConversationState.idle => Icons.mic,
                        }),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _input,
                          focusNode: _inputFocus,
                          enabled: _state != ConversationState.thinking,
                          contextMenuBuilder: translateSelectionMenu,
                          keyboardType: TextInputType.multiline,
                          textInputAction: TextInputAction.newline,
                          minLines: 1,
                          maxLines: 6,
                          decoration: InputDecoration(
                            hintText: 'マレー語で入力',
                            filled: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        tooltip: '送信',
                        onPressed: _canSend ? _onSendPressed : null,
                        icon: const Icon(Icons.send),
                      ),
                    ],
                  ),
                  SizedBox(
                    height: 36,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _copyPhrases.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(width: 4),
                      itemBuilder: (context, index) {
                        final phrase = _copyPhrases[index];
                        return TextButton.icon(
                          onPressed: () => _copyPhrase(phrase),
                          icon: const Icon(Icons.copy, size: 16),
                          label: Text(phrase),
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble({this.fromUser = false});

  final bool fromUser;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Align(
      alignment: fromUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          '入力中',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.colorScheme,
    required this.onWordTap,
    required this.onTranslate,
  });

  final ChatMessage message;
  final ColorScheme colorScheme;
  final void Function(String word) onWordTap;
  final VoidCallback onTranslate;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final onBubble = isUser ? colorScheme.onPrimary : colorScheme.onSurface;
    final translation = message.translation;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.86,
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
          decoration: BoxDecoration(
            color: isUser
                ? colorScheme.primary
                : colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
          ),
          child: IntrinsicWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TappableMalayText(
                  text: message.text,
                  style: TextStyle(color: onBubble),
                  onWordTap: onWordTap,
                ),
                if (translation != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    translation.translation,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: onBubble.withValues(alpha: 0.82),
                    ),
                  ),
                  if (readableEnglish(
                        translation.english,
                        original: message.text,
                        translation: translation.translation,
                      )
                      case final english?) ...[
                    const SizedBox(height: 4),
                    Text(
                      english,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: onBubble.withValues(alpha: 0.68),
                      ),
                    ),
                  ],
                ],
                Align(
                  alignment: isUser
                      ? Alignment.centerLeft
                      : Alignment.centerRight,
                  child: IconButton(
                    tooltip: '文を訳す',
                    visualDensity: VisualDensity.compact,
                    onPressed: onTranslate,
                    icon: Icon(
                      Icons.translate,
                      size: 20,
                      color: onBubble.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
