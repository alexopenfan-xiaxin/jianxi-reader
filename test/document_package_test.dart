import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jianxi_reader/core/document_file_service.dart';
import 'package:jianxi_reader/core/metadata_file_store.dart';
import 'package:jianxi_reader/data/documents/document_package_importer.dart';
import 'package:jianxi_reader/data/metadata/metadata_store.dart';
import 'package:jianxi_reader/features/library/document_entry.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Directory root;
  late Directory source;
  late Directory library;

  setUp(() {
    root = Directory.systemTemp.createTempSync('jianxi_package_');
    source = Directory(p.join(root.path, 'my-notes'))..createSync();
    library = Directory(p.join(root.path, 'library'))..createSync(recursive: true);
    MetadataFileStore.setBaseDirectoryForTesting(root);
    MetadataStore.clearCache();
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    MetadataStore.clearCache();
    MetadataFileStore.setBaseDirectoryForTesting(null);
    root.deleteSync(recursive: true);
  });

  void write(String relative, String contents) {
    final file = File(p.join(source.path, relative));
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(contents);
  }

  test('copies the folder as a package with its resources', () async {
    write('index.md', '![pic](img/pic.png)');
    write('img/pic.png', 'fakepng');
    write('theme/style.css', 'body{}');
    write('sub/chapter.md', '# Chapter');
    write('.git/config', 'ignored');
    write('Thumbs.db', 'ignored');

    final result = await DocumentPackageImporter.importFolder(
      source,
      libraryRoot: library,
    );

    expect(result.documents, hasLength(2));
    final names = result.documents.map((file) => p.basename(file.path)).toSet();
    expect(names, {'index.md', 'chapter.md'});

    final package = Directory(result.packageDirectory);
    expect(package.existsSync(), isTrue);
    expect(p.isWithin(library.path, package.path), isTrue);

    // Structure survives, so the relative image from index.md resolves.
    final index = result.documents.firstWhere(
      (file) => p.basename(file.path) == 'index.md',
    );
    final image = File(p.join(p.dirname(index.path), 'img', 'pic.png'));
    expect(image.existsSync(), isTrue);
    final css = File(p.join(p.dirname(index.path), 'theme', 'style.css'));
    expect(css.existsSync(), isTrue);

    // Noise is not copied.
    expect(
      File(p.join(package.path, '.git', 'config')).existsSync(),
      isFalse,
    );
    expect(File(p.join(package.path, 'Thumbs.db')).existsSync(), isFalse);
  });

  test('importing the same folder twice keeps both packages', () async {
    write('index.md', '# One');
    final first = await DocumentPackageImporter.importFolder(
      source,
      libraryRoot: library,
    );
    final second = await DocumentPackageImporter.importFolder(
      source,
      libraryRoot: library,
    );
    expect(second.packageDirectory, isNot(first.packageDirectory));
    expect(Directory(first.packageDirectory).existsSync(), isTrue);
    expect(Directory(second.packageDirectory).existsSync(), isTrue);
  });

  test('removing a packaged document parks the whole package', () async {
    write('index.md', '![pic](img/pic.png)');
    write('img/pic.png', 'fakepng');

    final result = await DocumentPackageImporter.importFolder(
      source,
      libraryRoot: library,
    );
    final service = DocumentFileService();
    final document = await DocumentEntry.fromFile(result.documents.single);

    final removal = await service.removeDocument(document);

    expect(removal.trashedPackagePath, isNotNull);
    expect(Directory(result.packageDirectory).existsSync(), isFalse);

    await service.restoreDocument(removal);

    final restored = File(document.path);
    expect(restored.existsSync(), isTrue);
    expect(
      File(p.join(p.dirname(document.path), 'img', 'pic.png')).existsSync(),
      isTrue,
    );
  });
}
