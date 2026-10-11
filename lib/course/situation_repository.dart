import 'package:cloud_firestore/cloud_firestore.dart';

class CourseLine {
  const CourseLine({required this.text, required this.isUser});

  final String text;
  final bool isUser;

  @override
  bool operator ==(Object other) =>
      other is CourseLine && other.text == text && other.isUser == isUser;

  @override
  int get hashCode => Object.hash(text, isUser);
}

class CourseSituation {
  const CourseSituation({
    required this.id,
    required this.title,
    required this.messages,
    this.order = 0,
  });

  final String id;
  final String title;
  final List<CourseLine> messages;
  final int order;

  factory CourseSituation.fromMap(String id, Map<String, dynamic> data) {
    final title = (data['title'] as String?)?.trim();
    final order = data['order'] is num ? (data['order'] as num).toInt() : 0;
    return CourseSituation(
      id: id,
      title: (title == null || title.isEmpty) ? '状況' : title,
      messages: _messagesFrom(data['messages']),
      order: order,
    );
  }

  factory CourseSituation.fromConversation({
    required String id,
    required String fallbackTitle,
    String? lessonTitle,
    required List<CourseLine> lines,
    required DateTime updatedAt,
  }) {
    final lesson = lessonTitle?.trim();
    final fallback = fallbackTitle.trim();
    final title = (lesson != null && lesson.isNotEmpty)
        ? lesson
        : (fallback.isEmpty ? '状況' : fallback);
    return CourseSituation(
      id: id,
      title: title,
      messages: [
        for (final line in lines)
          if (line.text.trim().isNotEmpty)
            CourseLine(text: line.text.trim(), isUser: line.isUser),
      ],
      order: updatedAt.millisecondsSinceEpoch,
    );
  }

  static List<CourseLine> _messagesFrom(Object? raw) {
    if (raw is! List) return const [];
    final indexed = <({int order, String text, bool? isUser})>[];
    for (var i = 0; i < raw.length; i++) {
      final item = raw[i];
      if (item is String) {
        final text = item.trim();
        if (text.isNotEmpty) indexed.add((order: i, text: text, isUser: null));
        continue;
      }
      if (item is Map) {
        final text = (item['text'] ?? item['message'] ?? '').toString().trim();
        final order = item['order'] is num ? (item['order'] as num).toInt() : i;
        if (text.isNotEmpty) {
          indexed.add((order: order, text: text, isUser: _isUser(item)));
        }
      }
    }
    indexed.sort((a, b) => a.order.compareTo(b.order));
    return [
      for (var i = 0; i < indexed.length; i++)
        CourseLine(
          text: indexed[i].text,
          isUser: indexed[i].isUser ?? i.isOdd,
        ),
    ];
  }

  static bool? _isUser(Map item) {
    final value = item['isUser'] ?? item['fromUser'];
    if (value is bool) return value;
    final role = (item['role'] ?? item['speaker'] ?? '').toString().toLowerCase();
    if (role == 'user') return true;
    if (role == 'model' || role == 'ai' || role == 'assistant') return false;
    return null;
  }
}

class SituationRepository {
  SituationRepository._();

  static final SituationRepository instance = SituationRepository._();

  static const sampleId = 'morning-friend';

  static const sample = CourseSituation(
    id: sampleId,
    title: '朝友達とばったり',
    messages: [
      CourseLine(text: 'Hello', isUser: false),
      CourseLine(text: 'Hey abang, apa khabar?', isUser: true),
    ],
  );

  Future<List<CourseSituation>> Function()? debugLoad;
  Future<void> Function(CourseSituation situation)? debugPublish;

  Future<List<CourseSituation>> load() {
    final override = debugLoad;
    if (override != null) return override();
    return _loadFromFirestore();
  }

  void resetForTest() {
    debugLoad = () async => const [];
    debugPublish = null;
  }

  Future<void> publish(CourseSituation situation) {
    if (situation.id.isEmpty || situation.messages.isEmpty) {
      throw StateError('公開できる会話がありません');
    }
    final override = debugPublish;
    if (override != null) return override(situation);
    return _publishToFirestore(situation);
  }

  Future<void> _publishToFirestore(CourseSituation situation) {
    return FirebaseFirestore.instance
        .collection('situations')
        .doc(situation.id)
        .set({
          'title': situation.title,
          'order': situation.order,
          'messages': [
            for (final line in situation.messages)
              {'text': line.text, 'isUser': line.isUser},
          ],
        });
  }

  Future<List<CourseSituation>> _loadFromFirestore() async {
    final collection = FirebaseFirestore.instance.collection('situations');
    var snapshot = await collection.get();
    if (snapshot.docs.isEmpty) {
      await collection.doc(sample.id).set({
        'title': sample.title,
        'order': sample.order,
        'messages': [
          for (final line in sample.messages)
            {'text': line.text, 'isUser': line.isUser},
        ],
      });
      snapshot = await collection.get();
    }
    final situations = [
      for (final doc in snapshot.docs)
        CourseSituation.fromMap(doc.id, doc.data()),
    ]..sort((a, b) => a.order.compareTo(b.order));
    return situations;
  }
}
