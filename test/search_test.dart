import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jianxi_reader/core/metadata_file_store.dart';
import 'package:jianxi_reader/data/search/library_search_index.dart';
import 'package:jianxi_reader/data/search/search_text.dart';
import 'package:jianxi_reader/features/library/document_entry.dart';
import 'package:path/path.dart' as p;

void main() {
  group('tokenize', () {
    test('splits CJK runs into bigrams', () {
      expect(tokenize('缓存失效'), ['缓存', '存失', '失效']);
      expect(tokenize('缓存'), ['缓存']);
      // A single ideograph has no bigram: callers fall back to a scan.
      expect(tokenize('缓'), isEmpty);
    });

    test('lower-cases ASCII words and keeps numbers', () {
      expect(tokenize('Hello World 42'), ['hello', 'world', '42']);
      expect(tokenize('缓存 Cache'), ['缓存', 'cache']);
    });

    test('counts repeated tokens', () {
      expect(countTokens('缓存 缓存 失效')['缓存'], 2);
    });

    test('builds a snippet around the first hit', () {
      final text = '${'a'.padRight(100, 'a')}缓存失效${'b'.padRight(100, 'b')}';
      final snippet = snippetAround(text, ['缓存']);
      expect(snippet, contains('缓存失效'));
      expect(snippet.startsWith('…'), isTrue);
      expect(snippet.endsWith('…'), isTrue);
    });
  });

  group('LibrarySearchIndex', () {
    late Directory root;
    late Directory docs;

    setUp(() {
      root = Directory.systemTemp.createTempSync('jianxi_search_');
      docs = Directory.systemTemp.createTempSync('jianxi_search_docs_');
      MetadataFileStore.setBaseDirectoryForTesting(root);
      LibrarySearchIndex.clearCache();
    });

    tearDown(() {
      LibrarySearchIndex.clearCache();
      MetadataFileStore.setBaseDirectoryForTesting(null);
      root.deleteSync(recursive: true);
      docs.deleteSync(recursive: true);
    });

    Future<DocumentEntry> write(String name, String body) async {
      final file = File(p.join(docs.path, name));
      await file.writeAsString(body);
      return DocumentEntry.fromFile(file);
    }

    test('finds documents by content and reports a snippet', () async {
      final cache = await write('cache.md', '分布式缓存失效策略');
      final other = await write('other.md', '与主题无关的一段话');
      await LibrarySearchIndex.refresh([cache, other]);

      final hits = await LibrarySearchIndex.search('缓存失效');
      expect(hits, hasLength(1));
      expect(hits.single.path, cache.path);
      expect(hits.single.snippet, contains('缓存'));
    });

    test('requires every query token', () async {
      final both = await write('both.md', '缓存失效');
      final onlyCache = await write('one.md', '缓存很好用');
      await LibrarySearchIndex.refresh([both, onlyCache]);

      final hits = await LibrarySearchIndex.search('缓存 失效');
      expect(hits.map((hit) => hit.path), [both.path]);
      expect(await LibrarySearchIndex.search('缓存'), hasLength(2));
    });

    test('falls back to a scan for a single ideograph', () async {
      final document = await write('single.md', '这里提到缓存');
      await LibrarySearchIndex.refresh([document]);

      final hits = await LibrarySearchIndex.search('缓');
      expect(hits, hasLength(1));
      expect(hits.single.snippet, contains('缓'));
    });

    test('reindexes a changed document and forgets deleted ones', () async {
      final document = await write('note.md', '旧的内容');
      await LibrarySearchIndex.refresh([document]);
      expect(await LibrarySearchIndex.search('缓存'), isEmpty);

      final file = File(document.path);
      await file.writeAsString('新的内容：缓存');
      final updated = await DocumentEntry.fromFile(file);
      await LibrarySearchIndex.refresh([updated]);

      expect(await LibrarySearchIndex.search('缓存'), hasLength(1));

      await file.delete();
      await LibrarySearchIndex.refresh(const []);
      expect(await LibrarySearchIndex.search('缓存'), isEmpty);
    });

    test('ranks repeated mentions higher', () async {
      final often = await write('often.md', '缓存 缓存 缓存');
      final once = await write('once.md', '缓存');
      await LibrarySearchIndex.refresh([often, once]);

      final hits = await LibrarySearchIndex.search('缓存');
      expect(hits.first.path, often.path);
    });
  });
}
