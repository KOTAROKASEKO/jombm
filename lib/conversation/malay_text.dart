class MalayTextPart {
  const MalayTextPart({required this.text, required this.isWord});

  final String text;
  final bool isWord;
}

final _wordPattern = RegExp(r"[A-Za-zÀ-ÿ']+(?:-[A-Za-zÀ-ÿ']+)*");

List<MalayTextPart> splitMalayText(String text) {
  if (text.isEmpty) return const [];

  final parts = <MalayTextPart>[];
  var start = 0;
  for (final match in _wordPattern.allMatches(text)) {
    if (match.start > start) {
      parts.add(
        MalayTextPart(text: text.substring(start, match.start), isWord: false),
      );
    }
    parts.add(MalayTextPart(text: match.group(0)!, isWord: true));
    start = match.end;
  }
  if (start < text.length) {
    parts.add(MalayTextPart(text: text.substring(start), isWord: false));
  }
  return parts;
}
