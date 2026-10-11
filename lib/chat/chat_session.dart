import 'chat_message.dart';

class ChatSession {
  ChatSession({
    required this.id,
    required this.title,
    required this.updatedAt,
    required this.messages,
    this.characterId,
    this.lessonTitle,
  });

  final String id;
  String title;
  DateTime updatedAt;
  List<ChatMessage> messages;
  String? characterId;
  String? lessonTitle;

  bool get hasUserMessage => messages.any((message) => message.isUser);

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'updatedAt': updatedAt.toIso8601String(),
    'messages': messages.map((message) => message.toJson()).toList(),
    'characterId': characterId,
    'lessonTitle': lessonTitle,
  };

  factory ChatSession.fromJson(Map<String, dynamic> json) {
    final rawMessages = json['messages'];
    return ChatSession(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '会話',
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
      messages: rawMessages is List
          ? rawMessages
                .whereType<Map>()
                .map(
                  (item) => ChatMessage.fromJson(Map<String, dynamic>.from(item)),
                )
                .toList()
          : [],
      characterId: json['characterId'] as String?,
      lessonTitle: json['lessonTitle'] as String?,
    );
  }

  static String titleFrom(List<ChatMessage> messages) {
    ChatMessage? firstUser;
    for (final message in messages) {
      if (message.isUser) {
        firstUser = message;
        break;
      }
    }
    final text = firstUser?.text.trim() ?? '';
    if (text.isEmpty) return '新しい会話';
    if (text.length <= 24) return text;
    return '${text.substring(0, 24)}…';
  }
}
