import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jombm/chat/user_memory.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    UserMemoryStore.instance.resetForTest();
  });

  test('個人メモは直近3件だけ読む', () async {
    final store = UserMemoryStore.instance;
    await store.remember('東京に住んでいる');
    await store.remember('名前はコタロウ');
    await store.remember('ナシレマが好き');
    await store.remember('会社員');

    expect(await store.recent(), ['会社員', 'ナシレマが好き', '名前はコタロウ']);
  });

  test('同じメモは新しい順に戻る', () async {
    final store = UserMemoryStore.instance;
    await store.remember('東京に住んでいる');
    await store.remember('名前はコタロウ');
    await store.remember('東京に住んでいる');

    expect(await store.recent(), ['東京に住んでいる', '名前はコタロウ']);
  });

  test('個人情報がない返答はメモにしない', () {
    expect(parseLearnerFact('NONE'), isNull);
    expect(parseLearnerFact('  none \nextra'), isNull);
    expect(parseLearnerFact('- 猫を飼っている'), '猫を飼っている');
  });

  test('メモはプロンプトに3件まで入る', () {
    final prompt = learnerNotesForPrompt([
      '会社員',
      'ナシレマが好き',
      '名前はコタロウ',
      '東京に住んでいる',
    ]);
    expect(prompt, contains('- 会社員'));
    expect(prompt, contains('- 名前はコタロウ'));
    expect(prompt, isNot(contains('東京に住んでいる')));
  });
}
