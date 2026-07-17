import 'package:flutter_test/flutter_test.dart';
import 'package:jianxi_reader/core/document_identity.dart';

void main() {
  test('referenced document IDs are deterministic FNV-1a hashes', () {
    expect(
      DocumentIdentityService.sourceIdFor('hello'),
      'ref_a430d84680aabd0b',
    );
  });
}
