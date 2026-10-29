# Release runbook

Release mechanics for 简兮阅读器. `main` is the only long-lived branch; normal code changes do not need this file.

## Authorization

- "run", an ordinary code change, or a push to `main` is not release authorization. Build, GitHub Release, and update-server upload require an explicit full-release request.
- Never put tokens, keystore passwords, or update-server keys in the repository, command output, or a remote URL. Use an approved credential source.
- Do not ask for credentials preemptively. If authentication blocks an explicitly requested push or release, explain the failure and ask for a safe credential path.

## Signing key custody

- Treat the `RELEASE_KEYSTORE` Actions secret as the only managed copy of the release private key.
- GitHub secrets are write-only: they cannot be read, exported, or copied to another repository. A repository transfer may not carry them.
- Do **not** delete, overwrite, rotate, or transfer the repository without a user-migration plan. Losing the secret means existing installs cannot be updated.
- Every release must fail when the secret is missing, and must verify the APK certificate after signing:
  - `apksigner verify --print-certs build/app/outputs/flutter-apk/app-release.apk`
  - expected SHA-256: `b76b05e93f2334aa0f8e7d756388e9d038b72db3315ccbd19b94dcd584beab5a`
- Keep 2FA and recovery codes on the repository owner account, and at least two repository admins.
- If the secret is lost: stop shipping, publish under a new package name, or require uninstall/reinstall (local bookmarks/progress are lost).

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
- Before release, `gh secret list` must show `RELEASE_KEYSTORE`, `KEY_STORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD`, and `UPDATE_SERVER_KEY`. Never rotate `RELEASE_KEYSTORE`.
- Release notes come from the `## <version> (build <N>)` section of `updatelog.md`, so that section must exist before dispatching — the page users open should read like the in-app update log, not like commit subjects.
- If that section is missing, the workflow falls back to grouping commit subjects since the previous tag; that fallback is English, so keep the `feat:` / `fix:` / `perf:` / `refactor:` / `style:` prefixes meaningful for it.

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
