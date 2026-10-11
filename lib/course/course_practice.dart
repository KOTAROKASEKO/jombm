import 'course_catalog.dart';

sealed class CourseExercise {
  const CourseExercise();
}

class SpeakExercise extends CourseExercise {
  const SpeakExercise({required this.phrase, required this.meaningJa});

  final String phrase;
  final String meaningJa;
}

class GrammarExercise extends CourseExercise {
  const GrammarExercise({
    required this.promptJa,
    required this.choices,
    required this.answerIndex,
    required this.explanationJa,
  });

  final String promptJa;
  final List<String> choices;
  final int answerIndex;
  final String explanationJa;
}

List<CourseExercise> practiceFor(CourseLesson lesson) {
  return _exercises[lesson.id] ?? _fallback(lesson);
}

bool spokenPhraseMatches(String heard, String target) {
  final heardWords = _words(heard);
  final targetWords = _words(target);
  if (heardWords.isEmpty || targetWords.isEmpty) return false;
  var index = 0;
  for (final word in heardWords) {
    if (index < targetWords.length && word == targetWords[index]) {
      index++;
    }
  }
  return index == targetWords.length;
}

List<String> _words(String text) {
  return text
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9à-ÿ]+'), ' ')
      .trim()
      .split(' ')
      .where((word) => word.isNotEmpty)
      .toList();
}

List<CourseExercise> _fallback(CourseLesson lesson) {
  final phrase = lesson.phrases.first;
  return [
    SpeakExercise(phrase: phrase, meaningJa: lesson.subtitle),
    GrammarExercise(
      promptJa: 'このレッスンで練習するフレーズはどれ？',
      choices: [phrase, 'Terima kasih.', 'Sama-sama.'],
      answerIndex: 0,
      explanationJa: lesson.goals.join('、'),
    ),
  ];
}

const _exercises = <String, List<CourseExercise>>{
  'l1-greet': [
    SpeakExercise(phrase: 'Hai, apa khabar?', meaningJa: 'こんにちは。元気？'),
    GrammarExercise(
      promptJa: '「お元気ですか」にあたるフレーズは？',
      choices: ['Hai, apa khabar?', 'Berapa ni?', 'Sedap tak?'],
      answerIndex: 0,
      explanationJa: 'apa khabar は「知らせは何？」から来て、あいさつでは「元気？」の意味です。',
    ),
    SpeakExercise(phrase: 'Nama saya Aina.', meaningJa: '私の名前はアイナです。'),
    GrammarExercise(
      promptJa: '名前を言うとき、正しいのは？',
      choices: ['Nama saya Aina.', 'Saya nama Aina.', 'Nama Aina saya.'],
      answerIndex: 0,
      explanationJa: 'Nama saya のあとに自分の名前を続けます。',
    ),
  ],
  'l1-food': [
    SpeakExercise(phrase: 'Saya nak teh tarik.', meaningJa: 'テータリックがほしいです。'),
    GrammarExercise(
      promptJa: '「〜がほしい」はどれ？',
      choices: [
        'Saya nak nasi lemak.',
        'Nasi saya nak lemak.',
        'Nak dari nasi lemak.',
      ],
      answerIndex: 0,
      explanationJa: 'Saya nak のあとに食べものや飲みものを続けます。nak は「ほしい」のくだけた言い方です。',
    ),
    SpeakExercise(phrase: 'Sedap tak?', meaningJa: 'おいしい？'),
    GrammarExercise(
      promptJa: '文末の tak? はどんな働き？',
      choices: ['「〜？」とたずねる', '値段を言う', '名前を言う'],
      answerIndex: 0,
      explanationJa: 'sedap は「おいしい」。文末の tak? で「おいしい？」と確認します。',
    ),
  ],
  'l1-number': [
    SpeakExercise(phrase: 'Berapa ni?', meaningJa: 'これ、いくら？'),
    GrammarExercise(
      promptJa: '値段を聞くのは？',
      choices: ['Berapa ni?', 'Nama saya Aina.', 'Jalan terus.'],
      answerIndex: 0,
      explanationJa: 'berapa は「いくつ・いくら」、ni は「これ」です。',
    ),
    SpeakExercise(phrase: 'Pukul berapa?', meaningJa: '今、何時？'),
    GrammarExercise(
      promptJa: '「Pukul berapa?」の意味は？',
      choices: ['今、何時？', 'これはおいしい？', 'どこから来たの？'],
      answerIndex: 0,
      explanationJa: 'pukul は時刻の「時」。berapa と合わせて「何時？」になります。',
    ),
  ],
  'l1-family': [
    SpeakExercise(phrase: 'Ada adik-beradik?', meaningJa: '兄弟姉妹はいる？'),
    GrammarExercise(
      promptJa: '家族について聞くのは？',
      choices: ['Ada adik-beradik?', 'Berapa ni?', 'Belok kiri.'],
      answerIndex: 0,
      explanationJa: 'adik-beradik は兄弟姉妹です。Ada で「いる？」と聞けます。',
    ),
    SpeakExercise(
      phrase: 'Saya kerja di pejabat.',
      meaningJa: '私はオフィスで働いています。',
    ),
    GrammarExercise(
      promptJa: '仕事を言うとき自然なのは？',
      choices: [
        'Saya kerja di pejabat.',
        'Kerja saya pejabat di.',
        'Di saya kerja pejabat.',
      ],
      answerIndex: 0,
      explanationJa: 'Saya kerja di のあとに場所を続けます。',
    ),
  ],
  'l2-shop': [
    SpeakExercise(phrase: 'Boleh kurang?', meaningJa: 'もう少し安くできる？'),
    GrammarExercise(
      promptJa: '値切るときに使うのは？',
      choices: ['Boleh kurang?', 'Nama saya Aina.', 'Sedap tak?'],
      answerIndex: 0,
      explanationJa: 'boleh は「できる」、kurang は「少ない」。値段を下げてほしいときに使います。',
    ),
    SpeakExercise(phrase: 'Bayar cash.', meaningJa: '現金で払います。'),
    GrammarExercise(
      promptJa: '「Bayar cash」の bayar は？',
      choices: ['払う', '曲がる', 'おいしい'],
      answerIndex: 0,
      explanationJa: 'bayar は「払う」です。',
    ),
  ],
  'l2-direction': [
    SpeakExercise(phrase: 'Dekat mana?', meaningJa: 'どこにある？'),
    GrammarExercise(
      promptJa: '場所を聞くのは？',
      choices: ['Dekat mana?', 'Pukul berapa?', 'Saya nak teh tarik.'],
      answerIndex: 0,
      explanationJa: 'dekat は「近い」、mana は「どこ」です。',
    ),
    SpeakExercise(phrase: 'Belok kiri.', meaningJa: '左に曲がって。'),
    GrammarExercise(
      promptJa: '「まっすぐ行って」はどれ？',
      choices: ['Jalan terus.', 'Belok kiri.', 'Belok kanan.'],
      answerIndex: 0,
      explanationJa: 'jalan terus は「まっすぐ進む」、kiri は左、kanan は右です。',
    ),
  ],
  'l2-work': [
    SpeakExercise(phrase: 'Pagi ni macam mana?', meaningJa: '今朝はどう？'),
    GrammarExercise(
      promptJa: '調子を聞くのは？',
      choices: ['Pagi ni macam mana?', 'Berapa ni?', 'Belok kanan.'],
      answerIndex: 0,
      explanationJa: 'macam mana は「どんな感じ？」です。朝のあいさつに使えます。',
    ),
    SpeakExercise(phrase: 'Busy tak?', meaningJa: '忙しい？'),
    GrammarExercise(
      promptJa: '「Busy tak?」の意味は？',
      choices: ['忙しい？', 'いくら？', 'どこ？'],
      answerIndex: 0,
      explanationJa: 'busy は日常会話でも使います。tak? で「忙しい？」と聞けます。',
    ),
  ],
  'l2-weekend': [
    SpeakExercise(phrase: 'Jom lepak.', meaningJa: '遊びに行こう。'),
    GrammarExercise(
      promptJa: '友達を誘うのは？',
      choices: ['Jom lepak.', 'Bayar cash.', 'Nama saya Aina.'],
      answerIndex: 0,
      explanationJa: 'jom は「行こう」、lepak は「ぶらぶら過ごす」です。',
    ),
    SpeakExercise(phrase: 'Weekend ni free?', meaningJa: '今週末、空いてる？'),
    GrammarExercise(
      promptJa: '「Weekend ni free?」は何を聞いている？',
      choices: ['週末が空いているか', '値段はいくらか', '道順'],
      answerIndex: 0,
      explanationJa: 'weekend ni は「今週末」。free? で予定があるかを聞けます。',
    ),
  ],
};
