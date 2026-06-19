import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jianxi_reader/core/document_error_describer.dart';
import 'package:jianxi_reader/core/document_file_service.dart';
import 'package:jianxi_reader/core/file_rules.dart';
import 'package:jianxi_reader/core/reading_progress_service.dart';
import 'package:jianxi_reader/features/library/document_entry.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('DocumentFileRules', () {
    test('detects supported document types by extension', () {
      expect(DocumentFileRules.typeForPath('notes.md'), DocumentType.markdown);
      expect(
        DocumentFileRules.typeForPath('guide.markdown'),
        DocumentType.markdown,
      );
      expect(DocumentFileRules.typeForPath('page.html'), DocumentType.html);
      expect(DocumentFileRules.typeForPath('page.htm'), DocumentType.html);
      expect(DocumentFileRules.typeForPath('image.png'), isNull);
    });

    test('resolves destination name conflicts predictably', () {
      final directory = Directory.systemTemp.createTempSync('jianxi_rules_');
      addTearDown(() => directory.deleteSync(recursive: true));

      final first = p.join(directory.path, 'doc.md');
      final second = p.join(directory.path, 'doc (1).md');
      File(first).writeAsStringSync('first');
      File(second).writeAsStringSync('second');

      final destination = DocumentFileRules.uniqueDestinationPath(
        directory: directory,
        fileName: 'doc.md',
      );

      expect(p.basename(destination), 'doc (2).md');
    });

    test('rejects unsafe rename base names', () {
      expect(
        () => DocumentFileRules.validateBaseName(''),
        throwsA(isA<FileSystemException>()),
      );
      expect(
        () => DocumentFileRules.validateBaseName('../bad'),
        throwsA(isA<FileSystemException>()),
      );
    });
  });

  group('describeDocumentError', () {
    test('maps common document failures to user-facing messages', () {
      expect(
        describeDocumentError(
          const FileSystemException('仅支持 Markdown 和 HTML 文档'),
        ),
        '仅支持 .md、.markdown、.html、.htm 文档',
      );
      expect(
        describeDocumentError(const FileSystemException('文档不存在或已被移出')),
        '文档已被移动或删除，请重新导入',
      );
      expect(
        describeDocumentError(const FileSystemException('权限被拒绝')),
        '无法继续访问该文档，请重新授权或重新导入',
      );
    });
  });

  group('ReadingProgressService', () {
    test('saves, loads, moves, and removes progress', () async {
      await ReadingProgressService.saveProgress('/tmp/a.md', 0.6);

      expect(await ReadingProgressService.loadProgress('/tmp/a.md'), 0.6);

      await ReadingProgressService.moveProgress('/tmp/a.md', '/tmp/b.md');

      expect(await ReadingProgressService.loadProgress('/tmp/a.md'), isNull);
      expect(await ReadingProgressService.loadProgress('/tmp/b.md'), 0.6);

      await ReadingProgressService.removeProgress('/tmp/b.md');

      expect(await ReadingProgressService.loadProgress('/tmp/b.md'), isNull);
    });

    test('near-top progress clears the stored value', () async {
      await ReadingProgressService.saveProgress('/tmp/a.md', 0.5);
      await ReadingProgressService.saveProgress('/tmp/a.md', 0.001);

      expect(await ReadingProgressService.loadProgress('/tmp/a.md'), isNull);
    });
  });

  group('DocumentFileService', () {
    test('renames a managed document and keeps the extension', () async {
      final targetDir = Directory.systemTemp.createTempSync('jianxi_target_');
      addTearDown(() => targetDir.deleteSync(recursive: true));

      final originalFile = File(p.join(targetDir.path, 'article.md'));
      await originalFile.writeAsString('# Title');
      final document = await DocumentEntry.fromFile(originalFile);
      await ReadingProgressService.saveProgress(document.path, 0.6);

      final renamed = await DocumentFileService().renameDocument(
        document,
        'renamed article',
      );

      expect(renamed.name, 'renamed article.md');
      expect(await File(renamed.path).readAsString(), '# Title');
      expect(originalFile.existsSync(), isFalse);
      expect(await ReadingProgressService.loadProgress(document.path), isNull);
      expect(await ReadingProgressService.loadProgress(renamed.path), 0.6);
    });

    test('does not overwrite another document when renaming', () async {
      final targetDir = Directory.systemTemp.createTempSync('jianxi_target_');
      addTearDown(() => targetDir.deleteSync(recursive: true));

      final originalFile = File(p.join(targetDir.path, 'article.md'));
      await originalFile.writeAsString('# Title');
      await File(p.join(targetDir.path, 'existing.md')).writeAsString('old');
      final document = await DocumentEntry.fromFile(originalFile);

      expect(
        () => DocumentFileService().renameDocument(document, 'existing'),
        throwsA(isA<FileSystemException>()),
      );
      expect(originalFile.existsSync(), isTrue);
    });

    test('removes only the managed copy from the library', () async {
      final targetDir = Directory.systemTemp.createTempSync('jianxi_target_');
      addTearDown(() => targetDir.deleteSync(recursive: true));

      final file = File(p.join(targetDir.path, 'article.md'));
      await file.writeAsString('# Source');
      final document = await DocumentEntry.fromFile(file);
      await ReadingProgressService.saveProgress(document.path, 0.7);

      await DocumentFileService().removeDocument(document);

      expect(file.existsSync(), isFalse);
      expect(await ReadingProgressService.loadProgress(document.path), isNull);
    });

  });
}
