import 'package:flutter_smooth_markdown/flutter_smooth_markdown.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jianxi_reader/features/reader/markdown/markdown_document.dart';
import 'package:jianxi_reader/features/reader/markdown/section_height_estimator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('estimator returns positive heights that grow with content', () {
    final estimator = SectionHeightEstimator(
      styleSheet: MarkdownStyleSheet.light(),
      contentWidth: 360,
    );
    final short = MarkdownDocument.parseContent('# 标题\n\n短正文。\n', const {});
    final long = MarkdownDocument.parseContent(
      List.generate(40, (i) => '这是第$i段比较长的正文内容，用来验证估算器随内容增长。').join('\n\n'),
      const {},
    );

    final shortHeight = estimator.estimateSection(short.sections.single);
    final longHeight = estimator.estimateSection(long.sections.single);
    expect(shortHeight, greaterThan(0));
    expect(longHeight, greaterThan(shortHeight));
  });

  test('headings estimate taller than equal-length body text', () {
    final estimator = SectionHeightEstimator(
      styleSheet: MarkdownStyleSheet.light(),
      contentWidth: 360,
    );
    final withHeading = MarkdownDocument.parseContent(
      '# 一级标题\n\n正文内容。\n',
      const {},
    );
    final plainOnly = MarkdownDocument.parseContent(
      '一级标题\n\n正文内容。\n',
      const {},
    );
    expect(
      estimator.estimateSection(withHeading.sections.single),
      greaterThan(estimator.estimateSection(plainOnly.sections.single)),
    );
  });
}
