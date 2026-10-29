import 'package:flutter_test/flutter_test.dart';
import 'package:jianxi_reader/core/update_digest.dart';

void main() {
  const digest =
      'a7cc51fd437b75955ed01122551d2da673a0830d1d21d5295014b91be417e113';

  test('a matching digest verifies', () {
    expect(
      UpdateDigest.evaluate(expected: digest, actual: digest.toUpperCase()),
      UpdateDigestStatus.verified,
    );
  });

  test('a missing or malformed header is a soft miss', () {
    // The update host cannot send this header, so blocking here would have
    // turned the updater off for every user.
    expect(
      UpdateDigest.evaluate(expected: null, actual: digest),
      UpdateDigestStatus.missingHeader,
    );
    expect(
      UpdateDigest.evaluate(expected: '', actual: digest),
      UpdateDigestStatus.missingHeader,
    );
    expect(
      UpdateDigest.evaluate(expected: 'not-a-digest', actual: digest),
      UpdateDigestStatus.missingHeader,
    );
  });

  test('a mismatching digest is refused', () {
    expect(
      UpdateDigest.evaluate(
        expected: digest,
        actual: 'b'.padRight(64, 'b'),
      ),
      UpdateDigestStatus.mismatch,
    );
  });
}
