import '../conversation/sentence_lookup.dart';

class ChatMessage {
  ChatMessage({
    required this.text,
    required this.isUser,
    this.translation,
  });

  final String text;
  final bool isUser;
  SentenceTranslation? translation;

  Map<String, dynamic> toJson() => {
    'text': text,
    'isUser': isUser,
    'translation': translation?.toJson(),
  };

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final translationJson = json['translation'];
    return ChatMessage(
      text: json['text'] as String? ?? '',
      isUser: json['isUser'] as bool? ?? false,
      translation: translationJson is Map
          ? SentenceTranslation.fromJson(
              Map<String, dynamic>.from(translationJson),
            )
          : null,
    );
  }
}
