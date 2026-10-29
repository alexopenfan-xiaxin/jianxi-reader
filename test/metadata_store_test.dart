import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jianxi_reader/core/metadata_file_store.dart';
import 'package:jianxi_reader/data/metadata/library_schema.dart';
import 'package:jianxi_reader/data/metadata/metadata_store.dart';
import 'package:jianxi_reader/data/metadata/migration.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

/// Writes the 2.x layout the way `DocumentFileService` and `BookmarkService`
/// left it: prefs keys per attribute, `id_map.json`, `bookmarks.json`.
Future<void> writeLegacyLibrary(int documentCount) async {
  final preferences = <String, Object>{};
  final idMap = <String, String>{};
  for (var i = 0; i < documentCount; i++) {
    final path = '/library/doc_$i.md';
    final id = 'doc_$i';
    idMap[path] = id;
    if (i % 4 == 0) {
      preferences['document.tags.$path'] = <String>['标签${i % 7}', '共同'];
    }
    if (i % 5 == 0) {
      preferences['document.pinned.$path'] = true;
    }
    if (i % 3 == 0) {
      preferences['document.recentOpened.$path'] = 1700000000000 + i;
    }
  }
  preferences['document.tags'] = <String>[for (var i = 0; i < 7; i++) '标签$i'];
  preferences['document.tags.pinned'] = <String>['标签0'];
  preferences['referenced.paths'] = <String>['/library/doc_0.md'];
  preferences['referenced.sourceUri./library/doc_0.md'] = 'content://docs/0';
  SharedPreferences.setMockInitialValues(preferences);

  final idMapFile = await MetadataFileStore.file('id_map.json');
  await idMapFile.writeAsString(jsonEncode(idMap));

  final bookmarks = [
    for (var i = 0; i < 100; i++)
      {
        'id': 'bm_$i',
        'documentId': 'doc_${i * 2}',
        'progressRatio': 0.5,
        'title': '书签 $i',
        'createdAtMillis': 1700000000000 + i,
      },
  ];
  final bookmarkFile = await MetadataFileStore.file('bookmarks.json');
  await bookmarkFile.writeAsString(jsonEncode(bookmarks));
}

void main() {
  late Directory root;

  setUp(() async {
    root = Directory.systemTemp.createTempSync('jianxi_phase1_');
    MetadataFileStore.setBaseDirectoryForTesting(root);
    MetadataStore.clearCache();
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    MetadataStore.clearCache();
    MetadataFileStore.setBaseDirectoryForTesting(null);
    root.deleteSync(recursive: true);
  });

  test('migrates 200 documents and 100 bookmarks', () async {
    await writeLegacyLibrary(200);
    MetadataStore.clearCache();

    expect(await MetadataMigration.runIfNeeded(), 'rebuilt');

    final read = await MetadataStore.readFromDisk();
    final snapshot = read.snapshot!;
    expect(read.quarantinePath, isNull);
    expect(read.droppedEntries, 0);
    expect(snapshot.schema, librarySchemaVersion);
    expect(snapshot.documents, hasLength(200));
    expect(snapshot.marks, hasLength(100));
    expect(snapshot.pinnedTags, ['标签0']);

    final first = snapshot.recordForPath('/library/doc_0.md')!;
    expect(first.id, 'doc_0');
    expect(first.tags, containsAll(<String>['标签0', '共同']));
    expect(first.pinned, isTrue);
    expect(first.recentOpenedAtMillis, 1700000000000);
    expect(first.sourceUri, 'content://docs/0');

    // doc_1 had no tags/pin/recency in the old layout and must not gain any.
    final second = snapshot.recordForPath('/library/doc_1.md')!;
    expect(second.tags, isEmpty);
    expect(second.pinned, isFalse);
    expect(second.recentOpenedAtMillis, isNull);

    final bookmark = snapshot.marks.firstWhere((mark) => mark.id == 'bm_0');
    expect(bookmark.documentId, 'doc_0');
    expect(bookmark.kind, ReadingMarkKind.bookmark);
    expect(bookmark.ratio, 0.5);

    final backups = Directory(p.join(root.path, 'metadata', 'backups'));
    expect(backups.existsSync(), isTrue);
    expect(backups.listSync(), isNotEmpty);
  });

  test('running the migration twice is a no-op', () async {
    await writeLegacyLibrary(20);
    MetadataStore.clearCache();
    expect(await MetadataMigration.runIfNeeded(), 'rebuilt');

    final file = await MetadataFileStore.file(MetadataStore.fileName);
    final firstPass = await file.readAsString();

    MetadataStore.clearCache();
    expect(await MetadataMigration.runIfNeeded(), 'current');
    expect(await file.readAsString(), firstPass);
  });

  test('a corrupt library.json is rebuilt from legacy', () async {
    await writeLegacyLibrary(12);
    MetadataStore.clearCache();
    final file = await MetadataFileStore.file(MetadataStore.fileName);
    await file.writeAsString('{"schema": 1, "documents": [');

    expect(await MetadataMigration.runIfNeeded(), 'rebuilt');

    final repaired = await MetadataStore.readFromDisk();
    expect(repaired.snapshot!.documents, hasLength(12));
    final metadataDir = Directory(p.join(root.path, 'metadata'));
    final quarantined = metadataDir
        .listSync()
        .map((entity) => p.basename(entity.path))
        .where((name) => name.contains('.corrupt-'));
    expect(quarantined, isNotEmpty);
  });

  test('concurrent transactions keep every update', () async {
    await MetadataStore.replace(LibrarySnapshot.empty());

    await Future.wait([
      for (var i = 0; i < 20; i++)
        MetadataStore.transaction((snapshot) async {
          snapshot.marks.add(
            ReadingMark(
              id: 'mark_$i',
              documentId: 'doc_1',
              kind: ReadingMarkKind.note,
              ratio: 0.1,
              createdAtMillis: i,
            ),
          );
        }),
    ]);

    final snapshot = (await MetadataStore.readFromDisk()).snapshot!;
    expect(snapshot.marks, hasLength(20));
  });

  test('garbage collection drops marks of missing documents', () async {
    await MetadataStore.replace(
      LibrarySnapshot(
        updatedAtMillis: 1,
        documents: [DocumentRecord(id: 'doc_1', path: '/a.md')],
        marks: [
          ReadingMark(
            id: 'keep',
            documentId: 'doc_1',
            kind: ReadingMarkKind.bookmark,
            ratio: 0.2,
            createdAtMillis: 1,
          ),
          ReadingMark(
            id: 'orphan',
            documentId: 'deleted_doc',
            kind: ReadingMarkKind.bookmark,
            ratio: 0.3,
            createdAtMillis: 2,
          ),
        ],
      ),
    );

    expect(await MetadataStore.collectGarbage(), 1);
    final snapshot = (await MetadataStore.readFromDisk()).snapshot!;
    expect(snapshot.marks.map((mark) => mark.id), ['keep']);
  });

  test('a damaged record is dropped alone', () async {
    final file = await MetadataFileStore.file(MetadataStore.fileName);
    await file.writeAsString(
      jsonEncode({
        'schema': librarySchemaVersion,
        'updatedAt': 1,
        'documents': [
          {'id': 'doc_1', 'path': '/a.md', 'pinned': true},
          {'id': 'doc_2'},
        ],
        'marks': [
          {'id': 'm1', 'documentId': 'doc_1', 'kind': 'bookmark', 'ratio': 0.4},
          {'id': 'm2', 'documentId': 'doc_1', 'kind': 'unknown', 'ratio': 0.5},
        ],
        'tags': ['标签0'],
        'pinnedTags': [],
      }),
    );
    MetadataStore.clearCache();

    final read = await MetadataStore.readFromDisk();
    expect(read.quarantinePath, isNull);
    expect(read.droppedEntries, 2);
    expect(read.snapshot!.documents, hasLength(1));
    expect(read.snapshot!.marks, hasLength(1));
  });
}
