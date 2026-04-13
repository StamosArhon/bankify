# Bankify Roadmap

## Status Snapshot

- Audit date: 2026-04-11
- Repo audited at: `C:\SoftwareDevelopment\Personal\bankify`
- Audit branch: `stamos/initial-assessment-roadmap`
- Remote branches present at audit time: `master` only. No `main` or `develop` branch was present on origin on 2026-04-11.
- Existing roadmap / next-step docs found: none
- Existing reference docs reviewed: `README.md`, `FAQ.md`, `.playstore/privacy-policy.md`, CI/workflow files, Android manifest/config, main Flutter feature flows
- Local validation gap: local machine has Flutter `3.7.11` / Dart `2.19.6`, while `pubspec.yaml` requires Dart `>=3.7.0` and `pubspec.lock` records Flutter `>=3.35.6`. As of this audit, `flutter pub get`, `flutter test`, and Flutter-aware local analysis were blocked until the toolchain is upgraded.

## Purpose

- This file is the single source of truth for security hardening, privacy improvements, dependency/supply-chain work, architecture cleanup, and post-hardening UX / feature work.
- Security and privacy work happen before new feature work.
- Future threads and subagents should read this file first and keep it updated when priorities, risks, or completed phases change.
- Each implementation slice should ship on its own `stamos/` branch and merge cleanly before the next slice starts.

## Current Product Scope

- Flutter client for a self-hosted Firefly III instance using a host URL plus personal access token.
- Persisted auth via `flutter_secure_storage`.
- Optional biometric app lock.
- Dashboard / home with configurable cards and charts.
- Transaction browsing, filtering, add/edit/delete, split transactions, multi-currency handling, tags, bills, piggy banks, attachments, quick actions, and share-in attachment flows.
- Accounts browsing and search.
- Categories monthly breakdown plus add/edit/delete.
- Bills overview and bill detail flow.
- Piggy bank overview, charts, and balance adjustment.
- Notification listener flow to prefill or auto-add transactions from third-party notifications.
- Debug log capture and email export.
- Localization and dynamic color support.

## Audit Inputs

- Manual repo review of Flutter, Android, CI, and settings/auth flows.
- Security subagent review of app code and Android config.
- Dependency / supply-chain subagent review of Flutter packages, Git dependencies, CI pinning, and update automation.
- Product / maintainability subagent review of screen scope, architecture hotspots, and improvement backlog.
- External dependency/advisory spot checks on 2026-04-11 against `pub.dev`, Flutter GitHub security advisories, GitHub repository security pages, and Google Maven metadata.

## Confirmed Findings

### Critical Security Findings

- Global cleartext transport is enabled in release via `android:usesCleartextTraffic="true"` and `network_security_config.xml`.
- User-installed CAs are trusted app-wide by default, which materially weakens TLS for a finance app.
- The login flow explicitly offers `HTTP`, so insecure transport is a first-class path, not just an edge case.
- Attachment `downloadUrl` / `uploadUrl` values are trusted and receive the bearer token without same-origin validation. A hostile or compromised server response could exfiltrate the personal access token.

### High-Value Privacy / Security Findings

- Attachment downloads build local file paths directly from server-controlled filenames, enabling path traversal inside app storage if malicious filenames are returned.
- The API key input field is not obscured.
- Sensitive screens are not protected against screenshots / app-switcher previews.
- Debug logging can write sensitive data to plaintext temp storage and offers one-tap email export.
- The notification listener copies raw third-party notification content into this app's own local notification payloads, increasing exposure on lock screen and in notification history.
- Share-in entrypoints accept `SEND` / `SEND_MULTIPLE` for `*/*` and keep inbound shared files with minimal validation.
- Android backup exclusions only cover `FlutterSecureStorage`; privacy-sensitive prefs for notification-listener behavior can still be backed up.

### Dependency / Supply-Chain Findings

- `notifications_listener_service` and `open_file_plus` are Git dependencies that track `ref: main`, which creates future lock-refresh risk and weakens provenance.
- `appcheck` is pinned to a personal GitHub fork commit rather than a vetted published release.
- CI uses mutable action tags and an unpinned Flutter channel (`stable`) rather than a concrete version.
- Dependabot targets `develop`, but the remote repo did not have a `develop` branch on 2026-04-11, so update automation is misaligned to the actual branch layout.
- The repo mixes multiple native-touching and high-capability plugins: notification listener, file picker, image picker, share-intent handling, secure storage, local notifications, Cronet HTTP, `open_file_plus`, and installed-app inspection.
- Android native dependencies are behind current upstream versions.

### Code Health / Maintainability Findings

- `lib/pages/transaction.dart` is the biggest hotspot and owns too many responsibilities at once.
- `lib/pages/home/main.dart`, `lib/pages/home/transactions.dart`, and `lib/pages/home/piggybank.dart` are also large, widget-centric files with business logic mixed into UI.
- App-shell state is implicit and spread across providers, callbacks, and page-level mutations.
- Automated coverage is very thin: only one real test file exists and it focuses on notification parsing.
- Logout currently clears all shared preferences, which is broader than necessary and risks wiping user preferences unrelated to session credentials.
- iOS is effectively not implemented in this repo yet, so this roadmap is Android-first.

## Internet-Checked Dependency Notes As Of 2026-04-11

- `flutter_secure_storage` is current at `10.0.0`; repo is aligned.
- `image_picker` is current at `1.2.1`; repo lockfile is aligned.
- Flutter advisory `GHSA-98v2-f47x-89xw` for `image_picker_android` is fixed in `0.8.12+18`; the lockfile uses `0.8.13+10`, which is already patched.
- Flutter advisory `GHSA-3hpf-ff72-j67p` for `shared_preferences_android` is fixed in `2.3.4`; the lockfile uses `2.4.18`, which is already patched.
- `cronet_http` current release is `1.8.0`; repo lockfile is on `1.7.0`.
- `file_picker` current release is `11.0.2`; repo lockfile is on `10.3.8`.
- `appcheck` current published release is `1.7.0`; repo uses a Git fork at `1.5.2`.
- `androidx.window:window` current stable is newer than the repo's `1.0.0`.
- `desugar_jdk_libs` current stable is newer than the repo's `2.1.4`.

## Guiding Principles

- Secure by default, with explicit opt-in for insecure compatibility modes.
- Preserve self-hosted practicality. Features like custom CA support should remain possible, but behind explicit advanced-user paths and warnings.
- Minimize retained sensitive data, minimize permissions, and minimize attack surface.
- Prefer reproducible builds over convenience.
- Prefer pinned, reviewable dependencies over moving branches and personal forks.
- Avoid large multi-concern branches. One branch should correspond to one roadmap slice.

## Branch Workflow

- Until a deliberate branch rename is completed, treat `master` as the baseline branch, because that is the only remote branch confirmed on 2026-04-11.
- If you later rename `master` to `main`, update this file immediately and use `main` from that point onward.
- Branch naming convention: `stamos/<phase>-<short-slug>`
- Example names:
  - `stamos/phase-0-toolchain-baseline`
  - `stamos/phase-1-transport-hardening`
  - `stamos/phase-1-attachment-url-safety`
  - `stamos/phase-2-privacy-logging-redaction`

## Per-Branch Process

1. Start from the baseline branch (`master` until explicitly renamed).
2. Create a focused branch with the `stamos/` prefix.
3. Implement only the scoped change for that branch.
4. Run the required verification for that slice.
5. Review the diff against the baseline branch.
6. Commit the branch once the slice is complete.
7. Merge to the baseline branch.
8. Delete the feature branch locally and remotely.
9. Update this roadmap if scope, risk, or next steps changed.

## Definition Of Done For Any Slice

- Code changes are limited to the branch scope.
- Security implications are documented in the PR / commit notes when relevant.
- Tooling checks pass for the available toolchain.
- Manual QA notes exist for security-sensitive flows.
- Any new setting or compatibility tradeoff has user-facing copy and a sane default.
- Roadmap status is updated before the branch is considered finished.

## Phase 0: Repository, Toolchain, And Workflow Baseline

### Goal

- Make the repo reproducible and runnable before deeper code changes begin.

### Milestones

- Decide the baseline branch strategy.
- Align local and CI toolchains.
- Make automation reflect the actual repo layout.
- Document the workflow so future branches stay consistent.

### Progress Update (2026-04-11)

- Implemented on `stamos/phase-0-toolchain-and-automation-baseline`:
  - Baseline branch assumptions in CI / Dependabot were aligned to `master`.
  - Repo-visible Flutter pinning was added via `pubspec.yaml` (`flutter: 3.35.6`).
  - The shared CI setup action now reads the exact Flutter version from the repo instead of using a floating `stable` channel.
  - Dependabot now covers `pub`, `gradle`, and GitHub Actions against the real baseline branch.
  - A dedicated `CONTRIBUTING.md` workflow doc was added for the `stamos/` branch process.
- Implemented on `stamos/phase-0-local-preview-workflow`:
  - Added a repo-local Android emulator preview helper at `scripts/preview-android.ps1`.
  - Documented the emulator + hot-reload workflow in `README.md` and `CONTRIBUTING.md` so future UI/UX work can be reviewed locally without reinstalling on a phone every time.
- Implemented on `stamos/phase-0-preview-toolchain-unblock`:
  - Removed the legacy direct `test` dev dependency that blocked `flutter pub get` on Flutter `3.35.6`.
  - Updated `scripts/preview-android.ps1` so it can use a side-by-side pinned Flutter install automatically or via `-FlutterPath`, instead of assuming PATH already points to the correct SDK.
- Implemented on `stamos/phase-0-preview-android-sdk-fix`:
  - Updated `scripts/preview-android.ps1` to export the resolved Android SDK path to Flutter so stale local `ANDROID_HOME` values no longer break emulator detection.
  - Adjusted `android/app/build.gradle.kts` so local debug builds no longer require release signing secrets from `android/key.properties`.
- Implemented on `stamos/phase-0-double-click-preview-launcher`:
  - Added a root-level Windows launcher so local emulator preview can be started by double-clicking `preview-android.cmd` without worrying about the current shell directory.
- Implemented on `stamos/phase-0-bankify-branding`:
  - Rebranded the user-facing app name from Waterfly III to Bankify across the Android app label, in-app copy, docs, and Android store metadata.
  - Replaced the shared in-app logo and Android adaptive launcher icon assets with the new Bankify branding.
- Implemented on `stamos/phase-0-distinct-app-identity`:
  - Renamed the internal Flutter package from `waterflyiii` to `bankify` and moved Android to the distinct application ID `io.github.stamosarhon.bankify`.
  - Updated fork-owned support and release surfaces so Bankify no longer points users to the original app's package ID, store listings, sponsor links, or support email.
- Implemented on `stamos/phase-0-ci-and-dependabot-hardening`:
  - Pinned third-party GitHub Actions in reusable actions and workflows by immutable commit SHA instead of mutable tags.
  - Added explicit least-privilege GitHub Actions `permissions`, keeping `contents: write` only on the GitHub release publishing job and defaulting the rest to `contents: read`.
  - Re-ran the local Android baseline on Flutter `3.35.6` with `flutter analyze`, focused tests, and `flutter build apk --debug`.
- Implemented on `stamos/phase-1-self-hosted-certificate-pinning`:
  - Added an explicit self-hosted HTTPS trust flow that shows the presented server certificate fingerprint and requires the user to opt in before retrying.
  - Pinned that trusted certificate per host and reused it for API, timezone, and attachment requests without relaxing the default HTTPS-only / system-CA baseline for other hosts.
- Implemented on `stamos/phase-1-certificate-capture-fix`:
  - Replaced the mixed Cronet/IO auth path with a single certificate-aware client so Android reliably surfaces the self-hosted certificate trust prompt.
  - Removed the now-unused `cronet_http` dependency to keep the transport path simpler and easier to audit.
- Implemented on `stamos/phase-1-https-protocol-mismatch-diagnostics`:
  - Differentiated invalid/self-signed certificate failures from plain-HTTP-on-HTTPS-port failures so self-hosted users get an accurate connection error instead of a misleading trust prompt expectation.
- Implemented on `stamos/phase-1-debug-local-http-development`:
  - Added a debug-only local-development path that permits explicit `http://` connections to localhost and private LAN IPs without weakening release transport policy.
  - Kept Android release builds HTTPS-only while allowing debug builds to reach local cleartext endpoints for emulator and LAN development.

### Task Slices

- Decide whether to keep `master` or rename it to `main`.
- If keeping `master`, update docs/automation to stop referring to `develop` / `main` ambiguously.
- If renaming, do it first and then update release, Dependabot, and local workflow docs.
- Pin Flutter with a repo-visible mechanism such as FVM or another explicit version file.
- Pin CI to an exact Flutter version instead of `stable`.
- Pin third-party GitHub Actions by commit SHA and set explicit minimal `permissions`.
- Fix Dependabot coverage and branch targets.
- Add automation coverage for Gradle dependencies and GitHub Actions/composite actions.
- Add a short `CONTRIBUTING.md` or workflow section describing the `stamos/` branch process.

### Exit Criteria

- A fresh machine can discover the required Flutter/Dart version from the repo alone.
- CI uses pinned versions.
- Branch automation points to the real baseline branch.
- `flutter pub get` is expected to succeed on the pinned toolchain.

### Suggested Branches

- `stamos/phase-0-branch-normalization`
- `stamos/phase-0-toolchain-pinning`
- `stamos/phase-0-ci-and-dependabot-hardening`

## Phase 1: Critical Transport And Token Hardening

### Goal

- Remove the most dangerous finance-app risks first: insecure transport, token exfiltration paths, and unsafe file handling.

### Milestones

- HTTPS-first networking in release builds.
- No bearer token leakage via off-origin attachment URLs.
- Safe local handling of downloaded attachments.
- Safer credential entry and sensitive-screen presentation.

### Progress Update (2026-04-11)

- Implemented on `stamos/phase-1-transport-security`:
  - Android release builds now disable cleartext traffic and only trust the system CA store.
  - Login and auth now reject `http://` Firefly hosts and normalize scheme-less input toward `https://`.
  - Stored insecure hosts now fail with an explicit HTTPS-required error instead of silently continuing.
- Implemented on `stamos/phase-1-attachment-origin-validation`:
  - Attachment upload/download requests now build trusted API endpoints from the configured Firefly base URL plus attachment ID, instead of consuming server-returned absolute URLs.
- Implemented on `stamos/phase-1-attachment-filename-sanitization`:
  - Attachment downloads now sanitize server-provided filenames and always write into app temp storage with a generated safe name.
  - Attachment downloads now stream response bytes directly to disk instead of buffering the entire file in memory first.
- Implemented on `stamos/phase-1-redirect-policy`:
  - Auth, API, and attachment requests now fail closed on redirects instead of automatically following them.
  - The dead debug-only cleartext / user-CA override was removed so the repo matches the enforced HTTPS-only runtime policy.
- Implemented on `stamos/phase-1-login-secret-protection`:
  - The API key field is now obscured by default and disables suggestions, autocorrect, and IME personalized learning.
  - Android now sets `FLAG_SECURE`, which protects screenshots and app-switcher previews for the whole app.
- Implemented on `stamos/phase-1-self-hosted-certificate-pinning`:
  - Added an explicit certificate trust prompt for self-hosted HTTPS deployments that present a custom or self-signed certificate.
  - Persisted the trusted certificate per host only after successful sign-in so future retries stay pinned without widening trust globally.
- Implemented on `stamos/phase-1-certificate-capture-fix`:
  - Simplified the Android auth transport path so certificate capture and trust prompting work reliably on-device.
- Implemented on `stamos/phase-1-https-protocol-mismatch-diagnostics`:
  - Distinguished plain HTTP endpoints from HTTPS certificate failures so local self-hosted setups get the right error explanation.
- Implemented on `stamos/phase-1-debug-local-http-development`:
  - Added a debug-only local-development exception that allows explicit `http://` for localhost and private-network hosts while keeping release Android builds HTTPS-only.

### Task Slices

- Disable cleartext traffic for release builds.
- Change the login flow so HTTPS is the default and normal path.
- Replace app-wide trust of user-installed CAs with a safer advanced-user mechanism.
- Define an explicit compatibility story for self-signed / custom CA users.
- Validate attachment `downloadUrl` and `uploadUrl` against the configured Firefly origin before sending auth headers.
- Prefer constructing attachment endpoints from trusted relative paths when possible.
- Sanitize server-provided filenames to a safe basename and generated temp filename.
- Stream large attachment downloads to disk instead of buffering whole files in memory.
- Obscure the API key field and disable suggestions/autocorrect/personalized learning for it.
- Add screenshot / recents-preview protection for sensitive screens, at minimum for login and unlocked finance views.

### Exit Criteria

- Release builds do not allow arbitrary cleartext Firefly traffic.
- Tokens are never sent to off-origin attachment URLs.
- Downloaded filenames cannot escape the intended temp directory.
- Personal access tokens are not plainly visible during entry.

### Suggested Branches

- `stamos/phase-1-transport-security`
- `stamos/phase-1-attachment-origin-validation`
- `stamos/phase-1-attachment-filename-sanitization`
- `stamos/phase-1-login-secret-protection`

## Phase 2: Privacy, Permissions, And Data-Minimization Hardening

### Goal

- Reduce unnecessary exposure of sensitive finance data on-device and through integrations.

### Milestones

- Sensitive logs are redacted and tightly gated.
- Notification listener flows keep less data and expose less on lock screen.
- Backup behavior matches privacy expectations.
- Shared-file intake is narrowed and validated.

### Progress Update (2026-04-13)

- Implemented on `stamos/phase-2-log-redaction`:
  - Added centralized sanitization for exported and forwarded logs, redacting obvious URLs, hosts, local file paths, and token patterns.
  - Lowered the default release log verbosity to warnings/errors unless the user explicitly enables debug logging, while keeping debug builds verbose for development.
  - Removed low-value logs that included hosts, search queries, notification titles, file paths, and source/destination account names.
  - Strengthened the debug-log export copy so it explicitly warns users to review even redacted logs before sharing.
  - Added focused regression tests for log sanitization and root log-level policy.
- Implemented on `stamos/phase-2-notification-payload-minimization`:
  - Replaced raw third-party notification JSON in local-notification payloads with opaque draft IDs backed by a short-lived app-local temp store.
  - Changed Bankify-generated notification copy to generic review/create messaging instead of echoing third-party app titles on the lock screen.
  - Set Bankify-generated notification visibility to `private` and added focused tests for opaque payload storage and Android visibility defaults.
- Implemented on `stamos/phase-2-backup-and-prefs-privacy`:
  - Expanded Android backup exclusions so secure storage, secure-storage config, legacy Flutter shared preferences, and the DataStore-backed preference file do not roam through cloud backup or device transfer.
  - Added Android 12+ data extraction rules so modern device-to-device restore follows the same privacy policy as legacy full-backup rules.
- Implemented on `stamos/phase-2-share-intent-validation`:
  - Narrowed Android share-entry MIME filters to images and PDFs instead of accepting arbitrary file types.
  - Added centralized inbound shared-file validation for MIME allowlisting, local-file origin checks, file-size limits, and per-batch limits, with regression tests for the acceptance rules.
  - Inserted a review dialog so shared files must be explicitly confirmed before they become transaction attachments, and temporary app-owned copies are cleaned up when discarded.
  - Reset consumed share intents after handoff so a single inbound share does not keep reopening the transaction composer on rebuilds.
- Implemented on `stamos/phase-2-lock-timeout-settings`:
  - Replaced the fixed 10-minute relock window with a configurable timeout that supports immediate, 1-minute, 5-minute, 10-minute, and 30-minute options.
  - Preserved existing locked installs on the legacy 10-minute behavior when no timeout had been saved yet, while giving new lock setups a more conservative 1-minute default.
  - Fixed the background timestamp logic so repeated quick pause/resume cycles do not keep counting from the first pause event.
  - Added focused policy tests for timeout restoration defaults and relock-threshold behavior.

### Task Slices

- Remove stray `debugPrint` and low-value logging of accounts, titles, file paths, and URLs.
- Redact hostnames, account names, notification content, and other sensitive values from any exportable logs.
- Make verbose logging unavailable in normal release usage, or fence it behind an explicit debug build / advanced-user gate.
- Review the email-export debug flow and make the privacy warning stronger and more specific.
- Stop embedding full third-party notification contents in local-notification payloads.
- Use opaque IDs or lightweight in-memory references for notification tap flows.
- Set Android notification visibility to `private` or `secret` where appropriate.
- Revisit notification auto-add defaults and permission copy.
- Expand backup exclusions or disable backup for privacy-sensitive prefs that should not roam.
- Restrict share-in MIME handling to the smallest practical allowlist.
- Add file size limits and clearer confirmation before preserving shared inbound files.
- Make lock timeout configurable rather than fixed at 10 minutes.

### Exit Criteria

- Release logs no longer capture obvious finance-sensitive values by default.
- Local notifications no longer serialize raw third-party notification bodies.
- Backup/restore behavior is aligned with the intended privacy model.
- Shared inbound files are validated before the app retains or uploads them.

### Suggested Branches

- `stamos/phase-2-log-redaction`
- `stamos/phase-2-notification-payload-minimization`
- `stamos/phase-2-backup-and-prefs-privacy`
- `stamos/phase-2-share-intent-validation`
- `stamos/phase-2-lock-timeout-settings`

## Phase 3: Dependency And Supply-Chain Hardening

### Goal

- Make dependency provenance, update cadence, and build reproducibility trustworthy.

### Milestones

- Sensitive Git dependencies are either replaced, vendored, or pinned immutably under your control.
- Hosted package drift is reduced.
- Native dependency hygiene is improved.
- The app ships with less optional attack surface.

### Progress Update (2026-04-13)

- Implemented on `stamos/phase-3-git-dependency-pinning`:
  - Replaced the remaining mutable Git branch refs in `pubspec.yaml` with immutable commit SHAs for `notifications_listener_service` and `open_file_plus`.
  - Refreshed `pubspec.lock` so both the declared Git refs and the resolved refs now point at fixed commits instead of `main`.
  - Confirmed that the remaining direct Git dependency, `appcheck`, was already pinned to a fixed commit and kept that explicit immutable reference in place.
- Implemented on `stamos/phase-3-hosted-package-upgrades`:
  - Upgraded the highest-risk hosted dependencies that directly touch files, notifications, local auth, preferences, package metadata, and timezone/platform integration: `file_picker`, `flutter_local_notifications`, `shared_preferences`, `local_auth`, `package_info_plus`, `flutter_timezone`, `flutter_svg`, `animations`, and `badges`.
  - Pulled their Android-facing implementations forward as part of the same lockfile refresh, including `shared_preferences_android`, `local_auth_android`, `image_picker_android`, `path_provider_android`, `quick_actions_android`, `url_launcher_android`, and `flutter_plugin_android_lifecycle`.
  - Adjusted Bankify's notification initialization and `show()` calls for the `flutter_local_notifications` 20.x named-parameter API so the app compiles cleanly on the pinned toolchain.
  - Confirmed a clean debug APK build after a full `flutter clean`, which also flushed a stale generated Android plugin registrant file from the repo working tree.
  - Intentionally held `file_picker` 11.x, `flutter_local_notifications` 21.x, `package_info_plus` 10.x, `json_annotation` 4.11.x, `chopper` 8.5.x, and `syncfusion_flutter_charts` 33.x for later slices because they either require a newer Dart/toolchain floor or would broaden this branch into codegen/UI churn beyond the native-hosted package hardening scope.
- Implemented on `stamos/phase-3-native-dependency-refresh`:
  - Updated the explicitly managed Android native dependencies in `android/app/build.gradle.kts`, moving `androidx.window:window` and `androidx.window:window-java` from `1.0.0` to `1.5.1`.
  - Updated `coreLibraryDesugaring` from `com.android.tools:desugar_jdk_libs:2.1.4` to `2.1.5`, keeping the project on the current 2.1.x line compatible with the repo's AGP 8.x baseline.
  - Centralized those versions as local Gradle constants so future native dependency refreshes are easier to review and update intentionally.
- Implemented on `stamos/phase-3-attack-surface-reduction`:
  - Removed the installed-app inspection path from notification-listener setup, dropping the external `appcheck` Git dependency and simplifying app selection to packages Bankify has already observed in incoming notifications.
  - Removed the large static Android `<queries>` package allowlist that previously exposed visibility into hundreds of finance and messaging apps just to support installed-app lookup.
  - Added an explicit confirmation dialog before downloaded or draft attachments are handed off to external apps via Android's file-open flow.
  - Kept share-intent support in place for now because Phase 2 already narrowed it to images/PDFs and added explicit review before inbound files become attachments; the remaining risk is now materially smaller than the removed package-visibility and installed-app-inspection surface.

### Task Slices

- Audit why each Git dependency exists.
- Move from `ref: main` to immutable commits in `pubspec.yaml` immediately if the package stays external.
- Prefer moving to vetted `pub.dev` releases where viable.
- If a fork is truly required, vendor it or move it under your own namespace and document the fork reason.
- Reassess `appcheck`; prefer the maintained published release or replace it with a smaller in-house implementation if feasible.
- Upgrade `cronet_http`, `file_picker`, `flutter_local_notifications`, `package_info_plus`, `json_annotation`, and other native-touching packages after review.
- Upgrade Android `window`, `window-java`, and `desugar_jdk_libs`.
- Decide whether both chart libraries are still justified or whether one should be removed.
- Reevaluate whether notification listener, installed-app inspection, arbitrary file open, and share-intent support should all remain enabled in the default product.

### Exit Criteria

- No direct dependency tracks a mutable Git branch.
- Tooling and CI dependencies are pinned and reviewable.
- The hosted/native package set is intentionally curated rather than inherited.

### Suggested Branches

- `stamos/phase-3-git-dependency-pinning`
- `stamos/phase-3-hosted-package-upgrades`
- `stamos/phase-3-native-dependency-refresh`
- `stamos/phase-3-attack-surface-reduction`

## Phase 4: Verification And Security Regression Harness

### Goal

- Build enough automated and repeatable validation to keep security fixes from regressing.

### Milestones

- Baseline checks stay green on the pinned toolchain.
- Security-sensitive units have focused tests.
- Manual security QA is checklist-driven rather than ad hoc.

### Task Slices

- Keep `flutter pub get`, `flutter analyze`, `flutter test`, and `flutter build apk --debug` green on the pinned toolchain as a recurring release gate.
- Add unit tests for transport policy and host validation.
- Add tests for attachment origin validation and filename sanitization.
- Add tests for notification payload minimization and parsing behavior.
- Add widget tests for login secret entry behavior and lock-screen settings where practical.
- Add regression tests around logout behavior and preference retention.
- Add a lightweight manual QA checklist for:
  - first login
  - HTTP rejection / advanced compatibility path
  - custom CA path
  - share-in flow
  - notification listener
  - debug log export
  - attachment download/open

### Exit Criteria

- The pinned local toolchain can run the baseline checks.
- The highest-risk code paths have automated regression coverage.
- Manual security QA has a standard checklist.

### Suggested Branches

- `stamos/phase-4-security-unit-tests`
  Completed on 2026-04-13. Adds expanded transport-policy coverage, attachment filename sanitization tests, shared-attachment cleanup tests, and notification draft expiry/malformed payload regression coverage.
- `stamos/phase-4-widget-and-flow-tests`
  Completed on 2026-04-13. Adds widget coverage for login secret-entry behavior, public-HTTP rejection in debug builds, the certificate-trust retry flow, and app-lock timeout selection.
- `stamos/phase-4-manual-security-qa-checklist`
  Completed on 2026-04-13. Adds a reusable manual release checklist for transport, login, lock, logout, share, notification, attachment, and debug-log privacy verification.

## Phase 5: Architecture Decomposition And Maintainability

### Goal

- Reduce the cost and risk of future feature work by breaking apart the monolithic screen logic.

### Milestones

- Transaction editor is decomposed.
- Shell/navigation state is more declarative.
- Domain fetching and caching are less widget-bound.
- Error/empty/loading states become consistent.

### Task Slices

- Split `TransactionPage` into smaller units:
  - form state / controller
  - payload mapper
  - split transaction editor
  - attachment service
  - notification-prefill adapter
  - save / delete coordinator
- Extract reusable domain services for bills, accounts, piggy banks, and dashboard data.
- Replace shell mutation patterns with a clearer navigation/shell state model.
- Simplify local widget state where `provider` or dedicated controllers would be safer.
- Standardize loading, empty, and error UI states across major screens.
- Narrow `signOut()` so it clears credentials/session data without indiscriminately wiping user preferences.

### Exit Criteria

- No single handwritten screen file is carrying most business logic for a major feature.
- The shell has a documented ownership model.
- Session reset behavior is intentional and limited.

### Suggested Branches

- `stamos/phase-5-transaction-editor-decomposition`
- `stamos/phase-5-shell-state-refactor`
- `stamos/phase-5-domain-service-extraction`
- `stamos/phase-5-logout-preference-retention`

## Phase 6: UX And Feature Improvement Backlog

### Rule

- Do not begin this phase until Phases 1 through 3 have met exit criteria, and Phase 4 has at least a usable baseline in place.

### High-Value UX Improvements

- Rework the transaction editor into clearer sections with progressive disclosure for advanced fields.
- Improve transaction filters with lighter UI, saved presets, and better repeat-use ergonomics.
- Normalize navigation so Settings and other top-level destinations behave consistently.
- Improve loading / error / empty states on bills, dashboard, accounts, and balance screens.
- Finish share-while-open support.
- Turn bills and piggy-bank detail dialogs into richer full-screen flows where it improves context and history visibility.

### Candidate Feature Backlog

- Multi-profile or multi-server support.
- Better onboarding / connection health checks for Firefly host, API version, and certificate trust.
- Safer advanced-user certificate management flow.
- Draft autosave for unfinished transactions.
- Saved transaction templates / shortcuts beyond duplication.
- Read-only offline cache or startup cache for core lists.
- More powerful dashboard customization.
- Explicit privacy center for notification listener, debug logs, and share/file permissions.

## Recommended Execution Order

1. `stamos/phase-3-git-dependency-pinning`
2. `stamos/phase-3-hosted-package-upgrades`
3. `stamos/phase-3-native-dependency-refresh`
4. `stamos/phase-3-attack-surface-reduction`
5. `stamos/phase-4-security-unit-tests`
6. `stamos/phase-4-widget-and-flow-tests`
7. `stamos/phase-4-manual-security-qa-checklist`
8. `stamos/phase-5-transaction-editor-decomposition`
9. Phase 6 work only after the hardening baseline is closed.

## Immediate Next Recommendation

- Phase 4 is complete.
- Next implementation branch should be `stamos/phase-5-transaction-editor-decomposition`.
- That branch should begin breaking `TransactionPage` into smaller, testable units before broader UI and feature work resumes.
