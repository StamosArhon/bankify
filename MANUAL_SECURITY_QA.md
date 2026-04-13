# Manual Security QA Checklist

Use this checklist before Android releases and after any branch that touches authentication, network transport, notifications, share intents, attachments, logging, or privacy-sensitive settings.

## Preflight

- [ ] Use the pinned Flutter toolchain: `3.35.6`.
- [ ] Run the baseline automated checks and confirm they pass:
  - `flutter analyze`
  - `flutter test`
  - `flutter build apk --debug`
- [ ] Start from a clean app install unless a scenario explicitly requires persisted state.
- [ ] Have the following test fixtures available:
  - one valid Firefly III host served over trusted HTTPS
  - one private LAN or loopback Firefly III host served over plain HTTP for debug-only local development
  - one optional Firefly III host using a custom CA or self-signed certificate
  - one sample PDF and one sample image for share/attachment testing
  - one watched notification source or a reliable notification test sender

## 1. First Login And Transport

- [ ] Fresh HTTPS login
  - Step: Open Bankify and enter a valid `https://` host plus API key.
  - Expect: Sign-in succeeds and lands on the dashboard.
  - Expect: The API key field is obscured by default and only becomes visible after tapping the reveal toggle.

- [ ] Debug-only local HTTP login
  - Step: In a debug build, enter an explicit private URL such as `http://192.168.x.x:port` or `http://127.0.0.1:port`.
  - Expect: Bankify allows the login attempt to proceed.
  - Expect: A bare host like `192.168.x.x:port` still normalizes to `https://...`, so the explicit `http://` prefix is required for this path.

- [ ] Public HTTP rejection
  - Step: Enter a public HTTP host such as `http://example.com`.
  - Expect: Bankify rejects the host before login and shows the local-HTTP-only validation message.

- [ ] HTTPS protocol mismatch handling
  - Step: Enter an `https://` URL that is actually serving plain HTTP on that port.
  - Expect: Bankify shows an HTTPS protocol error.
  - Expect: Bankify does not show the custom-certificate trust prompt for this case.

- [ ] Custom CA / self-signed certificate trust flow
  - Step: Enter a valid `https://` host backed by a custom or self-signed certificate.
  - Expect: Bankify shows the trust prompt with authority, SHA-256 fingerprint, subject, issuer, and validity dates.
  - Step: Verify the fingerprint against the server, then approve the certificate.
  - Expect: Login succeeds after approval.
  - Step: Fully close and reopen the app, then sign in again with the same host.
  - Expect: The host remains trusted and does not prompt again unless the certificate changes.

## 2. Lock, Logout, And Persistence

- [ ] App lock enablement
  - Step: Enable app lock in settings and complete biometric authentication.
  - Expect: The toggle stays enabled and the lock-timeout selector appears.

- [ ] Lock timeout behavior
  - Step: Select a timeout such as `Immediately`, `1 minute`, or `10 minutes`.
  - Step: Background the app and resume before the timeout expires.
  - Expect: Bankify does not prompt early.
  - Step: Resume again after the selected timeout has fully elapsed.
  - Expect: Bankify requires authentication.

- [ ] Existing-install timeout compatibility
  - Step: Upgrade an install that already had app lock enabled before the timeout selector existed.
  - Expect: The legacy timeout behavior is preserved until the user explicitly changes it.

- [ ] Logout from navigation drawer
  - Step: Sign out from the drawer confirmation dialog.
  - Expect: Credentials are cleared and the app returns to the login flow.
  - Note: The current implementation clears all `SharedPreferences` on logout as well as secure storage. Treat unexpected changes to theme, locale, or notification preferences as a deliberate behavior change that should also update `ROADMAP.md`.

- [ ] Splash reset flow
  - Step: Force a login failure and use the reset/back path from the splash error screen.
  - Expect: The app returns cleanly to the login form without stale credentials or stale trusted-certificate state.

## 3. Share-In And Attachments

- [ ] Share a local image or PDF into Bankify
  - Step: Share a supported file from another app while Bankify is closed.
  - Expect: Bankify opens the transaction composer once and shows the review flow for the shared file.
  - Expect: Accepted files are listed clearly and consumed after handoff so the composer does not reopen repeatedly on restart.

- [ ] Reject unsupported shared payloads
  - Step: Share text, a remote URL, or an invalid/untrusted file path.
  - Expect: Bankify rejects unsupported items and does not silently attach them.
  - Expect: Any app-owned temporary copy created for the rejected item is cleaned up.

- [ ] Attachment download and external open confirmation
  - Step: Download an existing transaction attachment.
  - Expect: The file is written under temporary storage with a sanitized filename.
  - Step: Attempt to open the attachment.
  - Expect: Bankify asks for explicit confirmation before handing the file to another app.

## 4. Notification Listener

- [ ] Permission and service state
  - Step: Grant notification listener and app notification permissions.
  - Expect: The notification-listener settings screen reflects the correct permission and running state.

- [ ] Review-notification flow
  - Step: Trigger a watched notification containing an amount-like string with auto-add disabled.
  - Expect: Bankify stages an opaque payload identifier instead of raw notification JSON.
  - Expect: The review notification is marked private on the lock screen.
  - Step: Tap the review notification.
  - Expect: Bankify opens the transaction review flow without reusing the payload on later taps.

- [ ] Auto-add flow
  - Step: Enable auto-add for a watched app and configure a default account.
  - Step: Trigger a supported watched notification.
  - Expect: Bankify creates the transaction and shows the success notification instead of the manual review notification.

- [ ] Self-notification suppression
  - Step: Trigger Bankify-generated notifications during the above tests.
  - Expect: Bankify does not re-ingest its own notifications.

## 5. Debug Export And Privacy

- [ ] Debug export confirmation
  - Step: Enable debug mode and start the debug log export flow.
  - Expect: Bankify requires explicit user action before exporting logs.

- [ ] Debug export redaction
  - Step: Inspect the produced export.
  - Expect: Sensitive URLs, hosts, local paths, API keys, and bearer-token-like values are redacted.

## Release Notes For Testers

- Debug builds intentionally allow explicit local `http://` hosts on private LAN and loopback addresses for development.
- Release builds must remain HTTPS-only.
- Certificate trust prompts are only valid for custom/self-signed HTTPS, not for plain-HTTP endpoints pretending to be HTTPS.
