# Release runbook

Release mechanics for 简兮阅读器. `main` is the only long-lived branch; normal code changes do not need this file.

## Authorization

- "run", an ordinary code change, or a push to `main` is not release authorization. Build, GitHub Release, and update-server upload require an explicit full-release request.
- Never put tokens, keystore passwords, or update-server keys in the repository, command output, or a remote URL. Use an approved credential source.
- Do not ask for credentials preemptively. If authentication blocks an explicitly requested push or release, explain the failure and ask for a safe credential path.

## Normal path: `publish.yml`

`.github/workflows/publish.yml` is the normal release path; dispatch defaults to `main`.

1. Build the ARM64 APK once on Flutter 3.44.
2. Read `version` from `pubspec.yaml`; require tag `v<version>+<build>` to be absent or to point at the same commit.
3. Publish the GitHub Release with generated notes and the APK.
4. Upload the APK to the update server.

## Contract

- Tag and release title: `v<version>+<build>`.
- Release asset: `app-arm64-v8a-release.apk`; `build-apk.yml` produces an artifact only (no tag, no release).
- Before tagging, keep `pubspec.yaml` and `_fallbackBuildNumber` in `about_settings.dart` in sync.
- Release notes are generated from commit subjects since the previous tag, so keep the `feat:` / `fix:` / `perf:` / `refactor:` / `style:` prefixes meaningful.

## TLS exception

The update host `blog.openfan.dpdns.org` has an incomplete certificate chain. Two legacy workarounds exist:

- the app allows `badCertificateCallback` for that host (`lib/features/settings/about_settings.dart`);
- the workflow uploads with `curl --insecure` (`.github/workflows/publish.yml`).

Do not add new TLS bypasses or widen these. Removing them requires fixing the server chain first.

## Manual fallback

Use it only when the user explicitly requests it or the workflow is unavailable.

- Match the tag, title, and artifact contract above.
- Do not delete an existing release or tag, or overwrite a divergent remote ref, without explicit approval.
- Use `build-apk.yml` when an APK is needed and the local machine has no Flutter SDK.
