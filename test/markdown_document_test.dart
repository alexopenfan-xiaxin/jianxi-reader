import 'package:flutter_test/flutter_test.dart';
import 'package:jianxi_reader/features/reader/markdown/markdown_document.dart';

void main() {
  group('MarkdownDocument.parseContent', () {
    test('small document becomes a single section with a complete TOC', () {
      final doc = MarkdownDocument.parseContent(
        '# 总览\n\n正文一段。\n\n## 细节\n\n正文两段。\n',
        const {},
      );
      expect(doc.sections, hasLength(1));
      expect(doc.tocEntries.map((e) => e.title).toList(), ['总览', '细节']);
      expect(doc.tocEntries.map((e) => e.level).toList(), [1, 2]);
      expect(doc.sectionIndexForHeading(0), 0);
      expect(doc.sectionIndexForHeading(1), 0);
      expect(doc.sectionIndexForHeading(2), -1);
    });

    test('large chapters split and heading bases stay global', () {
      final chapter = List.generate(
        120,
        (i) => '段落文字内容示例$i，用于凑足章节的实际长度。',
      ).join('\n\n');
      final data = '# One\n\n$chapter\n\n## Two\n\n$chapter\n\n## Three\n\n$chapter\n';
      final doc = MarkdownDocument.parseContent(data, const {});

      expect(doc.sections.length, greaterThanOrEqualTo(2));
      expect(
        doc.tocEntries.map((e) => e.title).toList(),
        ['One', 'Two', 'Three'],
      );
      for (var global = 0; global < doc.tocEntries.length; global++) {
        final sectionIndex = doc.sectionIndexForHeading(global);
        expect(sectionIndex, greaterThanOrEqualTo(0));
        final section = doc.sections[sectionIndex];
        expect(
          global,
          inInclusiveRange(
            section.headingBase,
            section.headingBase + section.headingCharOffsets.length - 1,
          ),
        );
        expect(section.headingCharOffsets, isNotEmpty);
      }
      var totalLength = 0;
      for (final section in doc.sections) {
        totalLength += section.searchTextLength;
      }
      expect(totalLength, doc.searchText.length);
      // Sections are laid out back to back in the search text.
      for (var i = 1; i < doc.sections.length; i++) {
        expect(
          doc.sections[i].searchTextStart,
          doc.sections[i - 1].searchTextStart +
              doc.sections[i - 1].searchTextLength,
        );
      }
    });

    test('search text flattens inline markup to plain text', () {
      final doc = MarkdownDocument.parseContent(
        '# 标题\n\n这是**加粗**与`代码`混排的正文。\n',
        const {},
      );
      expect(doc.searchText, contains('这是加粗与代码混排的正文。'));
    });

    test('headings beyond level four are excluded from the TOC', () {
      final doc = MarkdownDocument.parseContent(
        '# A\n\n##### Deep\n\n## B\n',
        const {},
      );
      expect(doc.tocEntries.map((e) => e.title).toList(), ['A', 'B']);
    });

    test('empty input produces an empty document', () {
      final doc = MarkdownDocument.parseContent('', const {});
      expect(doc.sections, isEmpty);
      expect(doc.tocEntries, isEmpty);
      expect(doc.searchText, isEmpty);
    });
  });
}
