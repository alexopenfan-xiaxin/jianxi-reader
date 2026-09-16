import 'package:flutter_test/flutter_test.dart';
import 'package:jianxi_reader/features/reader/document_search_controller.dart';

void main() {
  group('DocumentSearchController section passes', () {
    test('claims indices starting from the given section base', () {
      final controller = DocumentSearchController();
      controller.beginSectionPass(5);
      expect(controller.claimBuildMatchIndex(), 5);
      expect(controller.claimBuildMatchIndex(), 6);
      controller.beginSectionPass(0);
      expect(controller.claimBuildMatchIndex(), 0);
      expect(controller.claimBuildMatchIndex(), 1);
    });

    test('section passes do not disturb match navigation state', () {
      final controller = DocumentSearchController();
      controller.updateQuery('kw');
      controller.updateMatchCount(10);
      controller.next();
      expect(controller.currentIndex, 1);
      controller.beginSectionPass(3);
      controller.claimBuildMatchIndex();
      expect(controller.matchCount, 10);
      expect(controller.currentIndex, 1);
    });
  });
}
