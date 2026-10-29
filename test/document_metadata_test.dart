import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jianxi_reader/core/document_file_service.dart';
import 'package:jianxi_reader/core/metadata_file_store.dart';
import 'package:jianxi_reader/data/metadata/metadata_store.dart';
import 'package:jianxi_reader/features/library/document_entry.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Directory root;
  late Directory documents;

  setUp(() {
    root = Directory.systemTemp.createTempSync('jianxi_schema1_');
    documents = Directory.systemTemp.createTempSync('jianxi_docs_');
    MetadataFileStore.setBaseDirectoryForTesting(root);
    MetadataStore.clearCache();
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    MetadataStore.clearCache();
    MetadataFileStore.setBaseDirectoryForTesting(null);
    root.deleteSync(recursive: true);
    documents.deleteSync(recursive: true);
  });

  Future<DocumentEntry> createDocument(String name) async {
    final file = File(p.join(documents.path, name));
    await file.writeAsString('# $name');
    return DocumentEntry.fromFile(file);
  }

  test('tags, pinning and recency live on the record', () async {
    final service = DocumentFileService();
    final document = await createDocument('notes.md');

    await service.updateDocumentTags(document, ['工作', '读书']);
    await service.setDocumentPinned(document, true);
    final openedAt = await service.markDocumentOpened(document);

    expect(await service.loadTags(), containsAll(<String>['工作', '读书']));
    final record = (await MetadataStore.load()).recordForPath(document.path);
    expect(record, isNotNull);
    expect(record!.tags, ['工作', '读书']);
    expect(record.pinned, isTrue);
    expect(record.recentOpenedAtMillis, openedAt.millisecondsSinceEpoch);

    // Nothing is left in the old per-attribute preference keys.
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getKeys(), isEmpty);
  });

  test('a rename moves the record instead of copying preferences', () async {
    final service = DocumentFileService();
    final document = await createDocument('draft.md');
    await service.updateDocumentTags(document, ['工作']);
    await service.setDocumentPinned(document, true);

    final renamed = await service.renameDocument(document, 'final');
    final snapshot = await MetadataStore.load();

    expect(snapshot.recordForPath(document.path), isNull);
    final moved = snapshot.recordForPath(renamed.path);
    expect(moved, isNotNull);
    expect(moved!.tags, ['工作']);
    expect(moved.pinned, isTrue);
    expect(snapshot.documents, hasLength(1));
  });

  test('undo restores the record the removal captured', () async {
    final service = DocumentFileService();
    final document = await createDocument('keep.md');
    await service.updateDocumentTags(document, ['工作']);
    await service.setDocumentPinned(document, true);

    final removal = await service.removeDocument(document);
    expect((await MetadataStore.load()).recordForPath(document.path), isNull);

    await service.restoreDocument(removal);

    final restored = (await MetadataStore.load()).recordForPath(document.path);
    expect(restored, isNotNull);
    expect(restored!.tags, ['工作']);
    expect(restored.pinned, isTrue);
    expect(File(document.path).existsSync(), isTrue);
  });
}
