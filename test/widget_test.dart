import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jombm/chat/chat_launch.dart';
import 'package:jombm/chat/chat_message.dart';
import 'package:jombm/chat/chat_session.dart';
import 'package:jombm/chat/chat_store.dart';
import 'package:jombm/chat/user_memory.dart';
import 'package:jombm/characters/chat_character.dart';
import 'package:jombm/conversation/malay_text.dart';
import 'package:jombm/course/course_catalog.dart';
import 'package:jombm/course/course_practice.dart';
import 'package:jombm/course/situation_repository.dart';
import 'package:jombm/notes/match_board.dart';
import 'package:jombm/notes/match_store.dart';
import 'package:jombm/notes/notes_store.dart';
import 'package:jombm/notes/vocab_note.dart';
import 'package:jombm/screens/auth_screen.dart';
import 'package:jombm/screens/notes_screen.dart';
import 'package:jombm/screens/conversation_screen.dart';
import 'package:jombm/screens/course_practice_screen.dart';
import 'package:jombm/screens/history_screen.dart';
import 'package:jombm/screens/home_shell.dart';

void expectOneOf(List<String> openers) {
  final shown = openers.where((opener) {
    final words = splitMalayText(
      opener,
    ).where((part) => part.isWord).map((part) => part.text);
    return words.every((word) => find.text(word).evaluate().isNotEmpty);
  });
  expect(shown, isNotEmpty);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ChatStore.instance.resetForTest();
    UserMemoryStore.instance.resetForTest();
    ChatLaunch.instance.resetForTest();
    NotesStore.instance.resetForTest();
    MatchStore.instance.resetForTest();
    SituationRepository.instance.debugLoad = () async => const [
      CourseSituation(
        id: 'morning-friend',
        title: '朝友達とばったり',
        messages: [
          CourseLine(text: 'Hello', isUser: false),
          CourseLine(text: 'Hey abang, apa khabar?', isUser: true),
        ],
      ),
    ];
  });

  test('マレー語の文を単語に分割できる', () {
    final words = splitMalayText(
      'Hai! Apa khabar?',
    ).where((part) => part.isWord).map((part) => part.text).toList();
    expect(words, ['Hai', 'Apa', 'khabar']);
  });

  test('会話のタイトルは最初のユーザー発話から作る', () {
    final title = ChatSession.titleFrom([
      ChatMessage(text: 'Hai!', isUser: false),
      ChatMessage(text: 'Apa khabar?', isUser: true),
    ]);
    expect(title, 'Apa khabar?');
  });

  testWidgets('サインイン画面にメールとGoogleの導線がある', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: AuthScreen()));

    expect(find.text('Jom BM'), findsOneWidget);
    expect(find.text('サインイン'), findsWidgets);
    expect(find.text('メールアドレス'), findsOneWidget);
    expect(find.text('Googleで続ける'), findsOneWidget);
  });

  testWidgets('サインアップ表示に切り替えられる', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: AuthScreen()));

    await tester.tap(find.text('サインアップ').first);
    await tester.pumpAndSettle();

    expect(find.text('名前'), findsOneWidget);
    expect(find.text('アカウントを作成'), findsOneWidget);
  });

  testWidgets('会話画面は保存済みのチャットを再開しない', (WidgetTester tester) async {
    await ChatStore.instance.upsert(
      ChatSession(
        id: 'old',
        title: 'Selamat pagi',
        updatedAt: DateTime.utc(2026, 10, 4),
        messages: [
          ChatMessage(text: 'Hai', isUser: false),
          ChatMessage(text: 'Selamat pagi', isUser: true),
        ],
      ),
    );

    await tester.pumpWidget(const MaterialApp(home: ConversationScreen()));
    await tester.pump();

    expect(find.text('Selamat pagi'), findsNothing);
    expectOneOf(CharacterCatalog.aina.openers);
  });

  testWidgets('会話画面は初期のマレー語挨拶を表示する', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: ConversationScreen()));
    await tester.pump();

    expect(find.text('マレー語で会話'), findsOneWidget);
    expectOneOf(CharacterCatalog.aina.openers);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('マレー語で入力'), findsOneWidget);
    expect(find.byTooltip('音声入力'), findsOneWidget);
    expect(find.byTooltip('送信'), findsOneWidget);
    expect(find.byIcon(Icons.menu), findsOneWidget);
    expect(find.byTooltip('キャラクター'), findsOneWidget);
    expect(find.byTooltip('文を訳す'), findsOneWidget);
    expect(find.text('アイナ'), findsOneWidget);
  });

  testWidgets('会話メニューは新しいチャットと履歴とサインアウト', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: ConversationScreen()));
    await tester.pump();

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    expect(find.text('新しいチャット'), findsOneWidget);
    expect(find.text('履歴'), findsOneWidget);
    expect(find.text('過去の会話はまだありません'), findsOneWidget);
    expect(find.text('サインアウト'), findsOneWidget);
    expect(find.byIcon(Icons.logout), findsOneWidget);
  });

  testWidgets('入力欄で文字を選ぶと翻訳を表示する', (WidgetTester tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    await tester.pumpWidget(const MaterialApp(home: ConversationScreen()));
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'こんにちは');
    await tester.pump();

    final field = find.byType(EditableText);
    final state = tester.state<EditableTextState>(field);
    state.userUpdateTextEditingValue(
      const TextEditingValue(
        text: 'こんにちは',
        selection: TextSelection(baseOffset: 0, extentOffset: 5),
      ),
      SelectionChangedCause.longPress,
    );
    state.showToolbar();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('翻訳'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('入力欄は改行でき、聞き方の文をコピーできる', (WidgetTester tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await tester.pumpWidget(const MaterialApp(home: ConversationScreen()));
    await tester.pump();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.keyboardType, TextInputType.multiline);
    expect(field.textInputAction, TextInputAction.newline);
    expect(field.maxLines, greaterThan(1));
    final ask = find.text('マレー語で__ってなんていうの');
    final difference = find.text('_と_の違いは何');
    expect(
      tester.getRect(ask).top,
      greaterThan(tester.getRect(find.byType(TextField)).bottom),
    );
    expect(tester.getRect(difference).left, greaterThan(tester.getRect(ask).left));

    await tester.tap(ask);
    await tester.pump();
    expect(copied, 'マレー語で__ってなんていうの');

    await tester.tap(difference);
    await tester.pump();
    expect(copied, '_と_の違いは何');
    expect(find.text('コピーしました'), findsOneWidget);
  });

  testWidgets('会話画面はキーボード入力すると送信できる', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: ConversationScreen()));
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'Apa khabar');
    await tester.pump();

    expect(find.text('Apa khabar'), findsOneWidget);
    expect(find.byIcon(Icons.send), findsOneWidget);
  });

  testWidgets('下部タブで会話と単語を切り替えられる', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeShell()));
    await tester.pump();

    expect(find.text('会話'), findsOneWidget);
    expect(find.text('単語'), findsOneWidget);
    expect(find.text('コース'), findsOneWidget);
    expect(find.text('マレー語で会話'), findsOneWidget);

    await tester.tap(find.text('コース'));
    await tester.pumpAndSettle();

    expect(find.text('朝友達とばったり'), findsOneWidget);
    expect(find.text('コース開始'), findsOneWidget);

    await tester.tap(find.text('単語'));
    await tester.pump();

    expect(find.text('単語'), findsWidgets);
    expect(find.text('会話の単語や文を追加できます'), findsOneWidget);
    expect(find.byTooltip('単語を追加'), findsOneWidget);

    await tester.tap(find.byTooltip('単語を追加'));
    await tester.pumpAndSettle();

    expect(find.text('マレー語の単語'), findsOneWidget);
    expect(find.text('意味を調べる'), findsOneWidget);

    await tester.tap(find.text('意味を調べる'));
    await tester.pump();

    expect(find.text('単語を入力してください'), findsOneWidget);
  });

  test('会話キャラクターは5人いる', () {
    expect(CharacterCatalog.all, hasLength(5));
    expect(CharacterCatalog.byId('rizal').nameJa, 'リザル');
  });

  test('発声した文は句読点や余分な語があっても一致する', () {
    expect(spokenPhraseMatches('hai apa khabar', 'Hai, apa khabar?'), isTrue);
    expect(
      spokenPhraseMatches('Hai apa khabar lah', 'Hai, apa khabar?'),
      isTrue,
    );
    expect(spokenPhraseMatches('nama saya aina', 'Nama saya Aina.'), isTrue);
    expect(spokenPhraseMatches('apa khabar', 'Hai, apa khabar?'), isFalse);
    expect(spokenPhraseMatches('', 'Hai, apa khabar?'), isFalse);
  });

  test('どのレッスンも発声と文法がある', () {
    for (final level in CourseCatalog.levels) {
      for (final lesson in level.lessons) {
        final exercises = practiceFor(lesson);
        expect(
          exercises.whereType<SpeakExercise>(),
          isNotEmpty,
          reason: lesson.id,
        );
        expect(
          exercises.whereType<GrammarExercise>(),
          isNotEmpty,
          reason: lesson.id,
        );
      }
    }
  });

  test('会話は公開コースの台本になる', () {
    final situation = CourseSituation.fromConversation(
      id: 'session-1',
      fallbackTitle: 'Apa khabar?',
      lessonTitle: '朝友達とばったり',
      lines: [
        CourseLine(text: '  Hello  ', isUser: false),
        CourseLine(text: '', isUser: true),
        CourseLine(text: 'Hey abang, apa khabar?', isUser: true),
      ],
      updatedAt: DateTime.utc(2026, 10, 4),
    );
    expect(situation.id, 'session-1');
    expect(situation.title, '朝友達とばったり');
    expect(situation.messages, [
      CourseLine(text: 'Hello', isUser: false),
      CourseLine(text: 'Hey abang, apa khabar?', isUser: true),
    ]);
  });

  testWidgets('履歴を長押しすると公開コースに追加できる', (WidgetTester tester) async {
    CourseSituation? published;
    SituationRepository.instance.debugPublish = (situation) async {
      published = situation;
    };
    await ChatStore.instance.upsert(
      ChatSession(
        id: 'session-1',
        title: 'Apa khabar?',
        updatedAt: DateTime.utc(2026, 10, 4, 8),
        messages: [
          ChatMessage(text: 'Hello', isUser: false),
          ChatMessage(text: 'Apa khabar?', isUser: true),
        ],
        lessonTitle: '朝友達とばったり',
      ),
    );

    await tester.pumpWidget(const MaterialApp(home: HistoryScreen()));
    await tester.pumpAndSettle();

    await tester.longPress(find.text('Apa khabar?'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('公開する'));
    await tester.pumpAndSettle();

    expect(published?.id, 'session-1');
    expect(published?.title, '朝友達とばったり');
    expect(published?.messages, [
      CourseLine(text: 'Hello', isUser: false),
      CourseLine(text: 'Apa khabar?', isUser: true),
    ]);
    expect(find.text('コースに公開しました'), findsOneWidget);
  });

  testWidgets('履歴の削除ボタンで会話を消せる', (WidgetTester tester) async {
    await ChatStore.instance.upsert(
      ChatSession(
        id: 'session-1',
        title: 'Apa khabar?',
        updatedAt: DateTime.utc(2026, 10, 4, 8),
        messages: [ChatMessage(text: 'Apa khabar?', isUser: true)],
      ),
    );

    await tester.pumpWidget(const MaterialApp(home: HistoryScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('削除'));
    await tester.pumpAndSettle();

    expect(find.text('Apa khabar?'), findsNothing);
    expect(find.text('過去の会話はまだありません'), findsOneWidget);
    expect(ChatStore.instance.sessions, isEmpty);
  });

  test('空の意味は意味合わせに出さない', () {
    final pairs = pairsFromNotes([
      VocabNote(
        word: ' apa ',
        meaning: ' 何 ',
        sentence: '',
        createdAt: DateTime.utc(2026),
      ),
      VocabNote(
        word: 'apa',
        meaning: '別の意味',
        sentence: '',
        createdAt: DateTime.utc(2026),
      ),
      VocabNote(
        word: 'nak',
        meaning: '',
        sentence: '',
        createdAt: DateTime.utc(2026),
      ),
    ]);
    expect(pairs, hasLength(1));
    expect(pairs.single.word, 'apa');
    expect(pairs.single.meaning, '何');
  });

  test('違う意味に置いてもチップは残り、衝突でダメージ5', () {
    final board = MatchBoard(const [
      MatchPair(id: 'apa', word: 'apa', meaning: '何'),
      MatchPair(id: 'nak', word: 'nak', meaning: 'ほしい'),
    ]);
    expect(board.dropOn(wordId: 'apa', meaningId: 'nak'), MatchDrop.wrong);
    expect(board.mistakes, 0);
    expect(board.hp, matchMaxHp);
    expect(board.dropOn(wordId: 'apa', meaningId: 'apa'), MatchDrop.correct);
    expect(board.dropOn(wordId: 'nak', meaningId: 'nak'), MatchDrop.correct);
    expect(board.isComplete, isTrue);
    expect(board.missed, isEmpty);

    final crashed = MatchBoard(const [
      MatchPair(id: 'apa', word: 'apa', meaning: '何'),
    ]);
    expect(crashed.collide('apa'), isTrue);
    expect(crashed.missed.single.word, 'apa');
    expect(crashed.missed.single.meaning, '何');
    expect(crashed.hp, matchMaxHp - matchCollisionDamage);
    expect(crashed.damage, matchCollisionDamage);
    expect(crashed.collide('apa'), isFalse);
    expect(crashed.isComplete, isFalse);
    expect(formatMatchElapsed(const Duration(seconds: 75)), '01:15');
  });

  test('最近のマレー語の意味は見えている日本語チップに入る', () {
    final order = ['a', 'b', 'c', 'd', 'e', 'f'];
    final next = bringAnswerIntoView(
      order: order,
      recentId: 'f',
      visibleSlots: 3,
      matched: const {},
      slotBias: 1,
    );
    expect(next.sublist(0, 3), contains('f'));
    expect(next[1], 'f');
    expect(next.toSet(), order.toSet());

    final stable = bringAnswerIntoView(
      order: next,
      recentId: 'f',
      visibleSlots: 3,
      matched: const {},
      slotBias: 0,
    );
    expect(stable, next);

    final withMatched = bringAnswerIntoView(
      order: ['a', 'b', 'c', 'd', 'e'],
      recentId: 'e',
      visibleSlots: 3,
      matched: const {'a', 'b'},
      slotBias: 0,
    );
    expect(withMatched, ['a', 'b', 'c', 'd', 'e']);

    expect(visibleMeaningSlots(390), 6);
    expect(visibleMeaningSlots(430), 6);
  });

  testWidgets('単語の削除ボタンでノートを消せる', (WidgetTester tester) async {
    await NotesStore.instance.add(
      VocabNote(
        word: 'apa',
        meaning: '何',
        sentence: '',
        createdAt: DateTime.utc(2026),
      ),
    );

    await tester.pumpWidget(const MaterialApp(home: NotesScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('削除'));
    await tester.pumpAndSettle();

    expect(find.text('apa'), findsNothing);
    expect(find.text('会話の単語や文を追加できます'), findsOneWidget);
    expect(NotesStore.instance.notes, isEmpty);
  });

  testWidgets('意味合わせを終えると記録を保存する', (WidgetTester tester) async {
    final createdAt = DateTime.utc(2026);
    await NotesStore.instance.add(
      VocabNote(word: 'apa', meaning: '何', sentence: '', createdAt: createdAt),
    );
    await NotesStore.instance.add(
      VocabNote(
        word: 'nak',
        meaning: 'ほしい',
        sentence: '',
        createdAt: createdAt,
      ),
    );

    await tester.pumpWidget(const MaterialApp(home: NotesScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('意味合わせ'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await _dragWordOntoMeaning(tester, 'apa', 'apa');
    await _dragWordOntoMeaning(tester, 'nak', 'nak');
    await tester.pump();

    expect(find.text('記録を保存しました'), findsOneWidget);
    expect(MatchStore.instance.records, hasLength(1));
    expect(MatchStore.instance.records.single.wordCount, 2);
    expect(MatchStore.instance.records.single.mistakes, 0);
  });

  test('状況のメッセージは順番どおり読む', () {
    final situation = CourseSituation.fromMap('x', {
      'title': '朝友達とばったり',
      'messages': [
        {'order': 2, 'text': 'Hey abang, apa khabar?'},
        {'order': 1, 'text': 'Hello'},
      ],
    });
    expect(situation.messages, [
      CourseLine(text: 'Hello', isUser: false),
      CourseLine(text: 'Hey abang, apa khabar?', isUser: true),
    ]);
  });

  testWidgets('状況のコースを開始すると台本が3秒ごとに出る', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeShell()));
    await tester.pump();

    await tester.tap(find.text('コース'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('コース開始'));
    await tester.pump();
    await tester.pump();

    expect(find.text('入力中'), findsOneWidget);
    expect(find.text('Hello'), findsNothing);

    await tester.pump(const Duration(seconds: 3));

    expect(find.text('Hello'), findsOneWidget);
    expect(find.text('入力中'), findsOneWidget);
    expect(find.text('abang'), findsNothing);

    await tester.pump(const Duration(seconds: 3));

    expect(find.text('abang'), findsOneWidget);
    expect(find.text('khabar'), findsWidgets);
    expect(find.text('入力中'), findsNothing);

    Alignment alignmentOf(String text) {
      final align = find.ancestor(
        of: find.text(text),
        matching: find.byType(Align),
      );
      return tester.widget<Align>(align.first).alignment as Alignment;
    }

    expect(alignmentOf('Hello'), Alignment.centerLeft);
    expect(alignmentOf('abang'), Alignment.centerRight);
  });

  testWidgets('文法練習は選択肢をチェックできる', (WidgetTester tester) async {
    final lesson = CourseCatalog.lessonById('l1-greet')!;
    final exercises = practiceFor(lesson);
    final grammarIndex = exercises.indexWhere(
      (exercise) => exercise is GrammarExercise,
    );
    final grammar = exercises[grammarIndex] as GrammarExercise;

    await tester.pumpWidget(
      MaterialApp(
        home: CoursePracticeScreen(lesson: lesson, initialStep: grammarIndex),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('文法練習'), findsOneWidget);
    expect(find.text(grammar.promptJa), findsOneWidget);

    final check = find.widgetWithText(FilledButton, 'チェック');
    expect(tester.widget<FilledButton>(check).onPressed, isNull);

    await tester.tap(find.text(grammar.choices[grammar.answerIndex]));
    await tester.pumpAndSettle();
    await tester.tap(check);
    await tester.pumpAndSettle();

    expect(find.text('正解！'), findsOneWidget);
    expect(find.text(grammar.explanationJa), findsOneWidget);
    expect(find.text('続ける'), findsOneWidget);
  });
}

Future<void> _dragWordOntoMeaning(
  WidgetTester tester,
  String wordId,
  String meaningId,
) async {
  final malay = find.byKey(ValueKey('malay-$wordId'));
  final meaning = find.byKey(ValueKey('meaning-$meaningId'));
  final playfield = find
      .ancestor(of: malay, matching: find.byType(Stack))
      .first;
  for (var i = 0; i < 160; i++) {
    final field = tester.getRect(playfield);
    final chip = tester.getRect(malay);
    final onScreen =
        chip.top >= field.top + 8 && chip.bottom <= field.bottom - 8;
    if (onScreen) break;
    await tester.pump(const Duration(milliseconds: 50));
  }
  final from = tester.getCenter(malay);
  final to = tester.getCenter(meaning);
  final gesture = await tester.startGesture(from);
  await tester.pump();
  await gesture.moveBy(const Offset(0, 30));
  await tester.pump();
  await gesture.moveTo(to);
  await tester.pump();
  await gesture.up();
  await tester.pump();
}
