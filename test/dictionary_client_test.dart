import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:jombm/conversation/dictionary_client.dart';

void main() {
  test('HTMLの語義から本文だけ取り出せる', () {
    const html = '<a href="/wiki/news">news</a>';
    expect(DictionaryClient.stripHtml(html), 'news');
  });

  test('khabar は Glosbe のマレー語日本語訳になる', () async {
    final client = MockClient((request) async {
      final url = request.url.toString();
      if (url.contains('glosbe.com/ms/ja/khabar')) {
        return _html(_khabarPage);
      }
      if (url.contains('glosbe.com/ms/en/khabar')) {
        return _html('''
<li data-element="translation">
  <h3 class="translation__item__pharse">news</h3>
  <span class="dir-aware-pr-1">noun</span>
  <aside>Dbnary: Wiktionary</aside>
</li>
''');
      }
      fail(url);
    });

    final entry = await DictionaryClient(httpClient: client).lookup('khabar');
    expect(entry, isNotNull);
    expect(entry!.languageLabel, 'マレー語');
    expect(entry.senses, hasLength(1));
    expect(entry.senses.first.partOfSpeech, '名詞');
    expect(entry.senses.first.japanese, 'ニュース');
    expect(entry.senses.first.example, 'surat khabar / 新聞');
    expect(entry.englishGlosses, ['news']);
  });

  test('短縮語は元の語を Glosbe で引き直す', () async {
    final client = MockClient((request) async {
      final url = request.url.toString();
      if (url.contains('glosbe.com/ms/ja/nak')) {
        return _html('''
<li data-element="translation">
  <h3 class="translation__item__pharse">カブ</h3>
  <span class="dir-aware-pr-1">noun</span>
  <aside>Open Multilingual Wordnet</aside>
</li>
''');
      }
      if (url.contains('wiktionary.org') && url.contains('/nak')) {
        return http.Response(
          jsonEncode({
            'ms': [
              {
                'definitions': [
                  {'definition': 'contraction of hendak ("want")'},
                ],
              },
            ],
          }),
          200,
        );
      }
      if (url.contains('glosbe.com/ms/en/hendak')) {
        return _html('''
<li data-element="translation">
  <h3 class="translation__item__pharse">want</h3>
  <span class="dir-aware-pr-1">verb</span>
  <aside>Dbnary: Wiktionary</aside>
</li>
''');
      }
      if (url.contains('glosbe.com/ms/ja/hendak')) {
        return _html('''
<li data-element="translation">
  <h3 class="translation__item__pharse">たい</h3>
  <span class="dir-aware-pr-1">verb</span>
  <aside>Dbnary: Wiktionary</aside>
</li>
<li data-element="translation">
  <h3 class="translation__item__pharse">望む</h3>
  <span class="dir-aware-pr-1">verb</span>
  <aside>Open Multilingual Wordnet</aside>
</li>
''');
      }
      fail(url);
    });

    final entry = await DictionaryClient(httpClient: client).lookup('nak');
    expect(entry, isNotNull);
    expect(entry!.senses.map((sense) => sense.japanese), ['たい', '望む']);
    expect(entry.senses.first.example, '「hendak」の短縮');
    expect(entry.englishGlosses, ['want']);
  });

  test('辞書に無い語は空で返す', () async {
    final client = MockClient((request) async {
      if (request.url.toString().contains('glosbe.com')) {
        return http.Response('missing', 404);
      }
      return http.Response('{}', 404);
    });

    final entry = await DictionaryClient(httpClient: client).lookup('lah');
    expect(entry, isNull);
  });
}

http.Response _html(String body) {
  return http.Response.bytes(utf8.encode(body), 200);
}

const _khabarPage = '''
<li data-element="translation">
  <h3 class="translation__item__pharse">エントロピー</h3>
  <span class="dir-aware-pr-1">noun</span>
  <aside>Open Multilingual Wordnet</aside>
</li>
<li data-element="translation">
  <h3 class="translation__item__pharse">ニュース</h3>
  <span class="dir-aware-pr-1">noun</span>
  <aside>Dbnary: Wiktionary</aside>
  <p lang="ms">surat <b>khabar</b></p>
  <p lang="ja"><b>新聞</b></p>
</li>
<h2>Automatic translations of "khabar"</h2>
<li data-element="translation">
  <h3 class="translation__item__pharse">無視</h3>
  <aside>Dbnary: Wiktionary</aside>
</li>
''';
