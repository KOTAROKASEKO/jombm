class VocabNote {
  const VocabNote({
    required this.word,
    required this.meaning,
    required this.sentence,
    required this.createdAt,
    this.usage,
  });

  final String word;
  final String meaning;
  final String sentence;
  final DateTime createdAt;
  final String? usage;

  Map<String, dynamic> toJson() => {
    'word': word,
    'meaning': meaning,
    'sentence': sentence,
    'createdAt': createdAt.toIso8601String(),
    'usage': usage,
  };

  factory VocabNote.fromJson(Map<String, dynamic> json) {
    return VocabNote(
      word: json['word'] as String? ?? '',
      meaning: json['meaning'] as String? ?? '',
      sentence: json['sentence'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      usage: (json['usage'] as String?) ?? (json['note'] as String?),
    );
  }
}
