import 'package:flutter/foundation.dart';

class ChatLaunchRequest {
  const ChatLaunchRequest({
    required this.characterId,
    this.lessonId,
    this.lessonTitle,
    this.coach,
    this.script = const [],
    this.scriptFromUser = const [],
  });

  final String characterId;
  final String? lessonId;
  final String? lessonTitle;
  final String? coach;
  final List<String> script;
  final List<bool> scriptFromUser;
}

class ChatLaunch extends ChangeNotifier {
  ChatLaunch._();
  static final ChatLaunch instance = ChatLaunch._();

  ChatLaunchRequest? _pending;

  ChatLaunchRequest? get pending => _pending;

  void open(ChatLaunchRequest request) {
    _pending = request;
    notifyListeners();
  }

  ChatLaunchRequest? take() {
    final request = _pending;
    _pending = null;
    return request;
  }

  @visibleForTesting
  void resetForTest() {
    _pending = null;
  }
}
