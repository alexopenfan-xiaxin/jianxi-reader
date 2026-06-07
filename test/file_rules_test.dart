import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jianxi_reader/core/document_file_service.dart';
import 'package:jianxi_reader/core/file_rules.dart';
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

  group('DocumentFileService', () {
    test('imports supported files and preserves existing copies', () async {
      final sourceDir = Directory.systemTemp.createTempSync('jianxi_source_');
      final targetDir = Directory.systemTemp.createTempSync('jianxi_target_');
      addTearDown(() => sourceDir.deleteSync(recursive: true));
      addTearDown(() => targetDir.deleteSync(recursive: true));

      final source = File(p.join(sourceDir.path, 'article.md'));
      await source.writeAsString('# Title');
      await File(p.join(targetDir.path, 'article.md')).writeAsString('old');

      final imported = await const DocumentFileService().importFileToDirectory(
        source: source,
        directory: targetDir,
      );

      expect(imported.name, 'article (1).md');
      expect(await File(imported.path).readAsString(), '# Title');
    });

    test('renames a managed document and keeps the extension', () async {
      final targetDir = Directory.systemTemp.createTempSync('jianxi_target_');
      addTearDown(() => targetDir.deleteSync(recursive: true));

      final originalFile = File(p.join(targetDir.path, 'article.md'));
      await originalFile.writeAsString('# Title');
      final document = await DocumentEntry.fromFile(originalFile);

      final renamed = await const DocumentFileService().renameDocument(
        document,
        'renamed article',
      );

      expect(renamed.name, 'renamed article.md');
      expect(await File(renamed.path).readAsString(), '# Title');
      expect(originalFile.existsSync(), isFalse);
    });

    test('does not overwrite another document when renaming', () async {
      final targetDir = Directory.systemTemp.createTempSync('jianxi_target_');
      addTearDown(() => targetDir.deleteSync(recursive: true));

      final originalFile = File(p.join(targetDir.path, 'article.md'));
      await originalFile.writeAsString('# Title');
      await File(p.join(targetDir.path, 'existing.md')).writeAsString('old');
      final document = await DocumentEntry.fromFile(originalFile);

      expect(
        () => const DocumentFileService().renameDocument(document, 'existing'),
        throwsA(isA<FileSystemException>()),
      );
      expect(originalFile.existsSync(), isTrue);
    });

    test('removes only the managed copy from the library', () async {
      final sourceDir = Directory.systemTemp.createTempSync('jianxi_source_');
      final targetDir = Directory.systemTemp.createTempSync('jianxi_target_');
      addTearDown(() => sourceDir.deleteSync(recursive: true));
      addTearDown(() => targetDir.deleteSync(recursive: true));

      final source = File(p.join(sourceDir.path, 'article.md'));
      await source.writeAsString('# Source');
      final imported = await const DocumentFileService().importFileToDirectory(
        source: source,
        directory: targetDir,
      );

      await const DocumentFileService().removeDocument(imported);

      expect(source.existsSync(), isTrue);
      expect(File(imported.path).existsSync(), isFalse);
    });

    test('moves and clears reading offset with document metadata', () async {
      final targetDir = Directory.systemTemp.createTempSync('jianxi_target_');
      addTearDown(() => targetDir.deleteSync(recursive: true));

      final originalFile = File(p.join(targetDir.path, 'article.md'));
      await originalFile.writeAsString('# Title');
      final document = await DocumentEntry.fromFile(originalFile);
      const service = DocumentFileService();

      await service.saveReadingOffset(document, 128.5);
      expect(await service.loadReadingOffset(document), 128.5);

      final renamed = await service.renameDocument(document, 'renamed article');
      expect(await service.loadReadingOffset(document), 0);
      expect(await service.loadReadingOffset(renamed), 128.5);

      await service.removeDocument(renamed);
      expect(await service.loadReadingOffset(renamed), 0);
    });
  });
}
