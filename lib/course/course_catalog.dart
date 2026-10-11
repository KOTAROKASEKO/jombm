import '../characters/chat_character.dart';

class CourseLesson {
  const CourseLesson({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.goals,
    required this.phrases,
    required this.characterId,
    required this.coach,
  });

  final String id;
  final String title;
  final String subtitle;
  final List<String> goals;
  final List<String> phrases;
  final String characterId;
  final String coach;

  ChatCharacter get character => CharacterCatalog.byId(characterId);
}

class CourseLevel {
  const CourseLevel({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.lessons,
  });

  final String id;
  final String title;
  final String subtitle;
  final List<CourseLesson> lessons;
}

class CourseCatalog {
  static const levels = [
    CourseLevel(
      id: 'level1',
      title: 'Level 1',
      subtitle: 'あいさつと毎日の基本',
      lessons: [
        CourseLesson(
          id: 'l1-greet',
          title: 'あいさつと自己紹介',
          subtitle: 'Hai, nama, dari mana',
          goals: ['挨拶する', '名前を言う', '出身を聞く'],
          phrases: ['Hai, apa khabar?', 'Nama saya...', 'Saya dari...'],
          characterId: 'siti',
          coach: 'Practice greetings and self-intro. Keep Malay very simple.',
        ),
        CourseLesson(
          id: 'l1-food',
          title: '食べものと飲み物',
          subtitle: 'makan, minum, sedap',
          goals: ['食べ物を頼む', '好き嫌いを言う'],
          phrases: ['Saya nak...', 'Sedap tak?', 'Minum apa?'],
          characterId: 'aina',
          coach: 'Talk about food and drinks at a mamak. Offer choices.',
        ),
        CourseLesson(
          id: 'l1-number',
          title: '数字・時間・値段',
          subtitle: 'berapa, pukul, ringgit',
          goals: ['値段を聞く', '時間を言う'],
          phrases: ['Berapa ni?', 'Pukul berapa?', 'Mahal sikit.'],
          characterId: 'kumar',
          coach: 'Practice numbers, time and prices in a shop role-play.',
        ),
        CourseLesson(
          id: 'l1-family',
          title: '家族と自分のこと',
          subtitle: 'keluarga, umur, kerja',
          goals: ['家族を紹介する', '仕事・学校を言う'],
          phrases: ['Ada adik-beradik?', 'Saya kerja/sekolah...'],
          characterId: 'siti',
          coach: 'Ask about family, age and daily life with short questions.',
        ),
      ],
    ),
    CourseLevel(
      id: 'level2',
      title: 'Level 2',
      subtitle: '街なかと予定の会話',
      lessons: [
        CourseLesson(
          id: 'l2-shop',
          title: '買い物する',
          subtitle: 'tawar, bayar, plastik',
          goals: ['欲しいものを伝える', '値切ってみる'],
          phrases: ['Cari...', 'Boleh kurang?', 'Bayar cash/qr.'],
          characterId: 'kumar',
          coach: 'Role-play shopping. Ask what they want and the price.',
        ),
        CourseLesson(
          id: 'l2-direction',
          title: '道を聞く',
          subtitle: 'kiri, kanan, terus',
          goals: ['場所を聞く', '簡単な道順を理解する'],
          phrases: ['Dekat mana?', 'Jalan terus', 'Belok kiri/kanan'],
          characterId: 'rizal',
          coach: 'Help the learner ask and follow simple directions in KL.',
        ),
        CourseLesson(
          id: 'l2-work',
          title: '仕事と一日の流れ',
          subtitle: 'pagi, pejabat, balik',
          goals: ['一日の流れを話す', '忙しいかを聞く'],
          phrases: ['Pagi ni macam mana?', 'Busy tak?', 'Nanti balik pukul...'],
          characterId: 'rizal',
          coach: 'Talk about a normal work or school day, keep it casual.',
        ),
        CourseLesson(
          id: 'l2-weekend',
          title: '週末の予定',
          subtitle: 'lepak, jom, esok',
          goals: ['誘う', '予定を決める'],
          phrases: ['Weekend ni free?', 'Jom lepak', 'Nanti kita...'],
          characterId: 'farah',
          coach: 'Make weekend plans like friends. Suggest one simple outing.',
        ),
      ],
    ),
  ];

  static CourseLesson? lessonById(String? id) {
    if (id == null) return null;
    for (final level in levels) {
      for (final lesson in level.lessons) {
        if (lesson.id == id) return lesson;
      }
    }
    return null;
  }
}
