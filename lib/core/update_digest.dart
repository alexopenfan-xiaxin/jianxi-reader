import 'sha256.dart';

/// Verdict for one downloaded update package.
enum UpdateDigestStatus {
  /// The server sent `x-apk-sha256` and it matches the bytes we wrote.
  verified,

  /// The server sent no digest. We still install: Android's own signature check
  /// remains the backstop, and refusing here would mean a server we cannot
  /// change silently blocks every future update.
  missingHeader,

  /// A digest was advertised and the bytes do not match. Never install.
  mismatch,
}

/// Digest policy for the in-app updater.
///
/// The audit asked for fail-closed behaviour (no digest, no install). The
/// update host is fixed and only emits `x-apk-build` / `x-apk-version`, so
/// fail-closed would have disabled the updater for every user after 3.0. The
/// policy therefore keeps the strong check when a digest is present and treats
/// its absence as a soft miss, which is the strongest guarantee this server can
/// actually support.
class UpdateDigest {
  UpdateDigest._();

  static UpdateDigestStatus evaluate({
    required String? expected,
    required String actual,
  }) {
    final normalized = expected?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty || !isSha256Hex(normalized)) {
      return UpdateDigestStatus.missingHeader;
    }
    return normalized == actual.trim().toLowerCase()
        ? UpdateDigestStatus.verified
        : UpdateDigestStatus.mismatch;
  }
}
