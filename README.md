# Bankify

**Unofficial** Android app for [Firefly III](https://github.com/firefly-iii/firefly-iii), a free and open source personal finance manager.

Bankify is now a distinct fork of Waterfly III with its own roadmap, release identity, and maintenance flow. The app design is still heavily influenced by [Bluecoins](https://play.google.com/store/apps/details?id=com.rammigsoftware.bluecoins). Please also read the [FAQ](https://github.com/StamosArhon/bankify/blob/master/FAQ.md).

## Features

- General
  - Light and dark mode, with dynamic colors where supported
  - Translation-ready localization files for future Bankify translations
  - Listen to incoming notifications and pre-fill transactions
  - Option to require biometric authentication to open the app
- Dashboard
  - Five different charts for the current balance and recent history
  - Waterfall chart for net earnings in recent months
  - Budget overview for the last 30 days
  - Upcoming bills
- Transactions
  - List transactions by date
  - Filter the list by various fields
  - Add and edit transactions with autocomplete, attachments, pictures, split transactions, and multi-currency support
- Balance Sheet
  - List individual account balances
- Piggy Banks
  - View piggy banks, sorted by category
  - Add and remove money from piggy banks
- Accounts
  - List all asset, expense, revenue, and liability accounts
  - Search for specific accounts
- Categories
  - View monthly transactions split up by category
  - Add, edit, and delete categories
- Bills
  - View bills and their overview organized into groups
  - Inspect bill details and see connected transactions

### Feature Status

The app does **not** try to replicate every single feature that the web interface has. Instead, it aims to be a good companion for the most-used on-the-go flows. More advanced operations such as creating or modifying rules are not planned for this app.

If you are missing anything, feel free to open a [feature request](https://github.com/StamosArhon/bankify/issues/new/choose), or look at what other users [are requesting](https://github.com/StamosArhon/bankify/issues?q=is%3Aissue+is%3Aopen+label%3Aenhancement).

## Releases

Bankify is not published under the original Waterfly III store listings. Releases for this fork should be consumed from the [GitHub releases page](https://github.com/StamosArhon/bankify/releases) until dedicated Bankify store listings exist.

## Screenshots

*All made with a Google Pixel 8, showing Bankify v1.0.0*

|Dashboard|Transactions|Transaction Filters|
| :-: | :-: | :-: |
| <img src=".github/assets/screen_dashboard.png" width="250" /> | <img src=".github/assets/screen_transactions_overview.png" width="250" /> | <img src=".github/assets/screen_transactions_filters.png" width="250" /> |

|Transaction Add|Transaction Edit|Transaction Attachments|
| :-: | :-: | :-: |
| <img src=".github/assets/screen_transaction_add.png" width="250" /> | <img src=".github/assets/screen_transaction_edit.png" width="250" /> | <img src=".github/assets/screen_transaction_attachments.png" width="250" /> |

|Account Screen|Category Screen|Piggy Banks with Chart|
| :-: | :-: | :-: |
| <img src=".github/assets/screen_accounts.png" width="250" /> | <img src=".github/assets/screen_categories.png" width="250" /> | <img src=".github/assets/screen_piggy_chart.png" width="250" /> |

## Technology

The app is built using [Flutter](https://flutter.dev/) and tries to stay close to [Material 3](https://m3.material.io/) design guidelines. The project also aims to stay lean, without trackers or unnecessary external dependencies.

## Development

The repo is pinned to Flutter `3.35.6` through [`pubspec.yaml`](pubspec.yaml), and GitHub Actions reads that exact version during CI. Local workflow and branch-process notes live in [`CONTRIBUTING.md`](CONTRIBUTING.md).
Manual security and privacy release checks live in [`MANUAL_SECURITY_QA.md`](MANUAL_SECURITY_QA.md).
A machine-switch/project-status handoff lives in [`HANDOFF.md`](HANDOFF.md), and the reusable sync prompt for future Codex threads lives in [`MACHINE_SWITCH_PROMPT.md`](MACHINE_SWITCH_PROMPT.md).

## Local Preview

The easiest local UI/UX workflow is an Android emulator with hot reload. After Android Studio and an emulator are set up, you can use [`scripts/preview-android.ps1`](scripts/preview-android.ps1) from PowerShell:

```powershell
.\scripts\preview-android.ps1
```

If you prefer a double-click launcher on Windows, use [`preview-android.cmd`](preview-android.cmd) from the repo root. It starts the PowerShell helper from the correct directory automatically and pauses on errors so the message stays visible.

Useful variants:

```powershell
.\scripts\preview-android.ps1 -AvdName Pixel_8_API_35
.\scripts\preview-android.ps1 -SkipEmulatorLaunch
.\scripts\preview-android.ps1 -FlutterPath C:\appdev\flutter-3.35.6\bin\flutter.bat
```

The script:
- uses the repo's pinned Flutter version as the expected baseline,
- prefers a side-by-side `flutter-<version>` install next to your current Flutter SDK when it finds one,
- tries to find `adb` / `emulator` from PATH or the default Android SDK location,
- launches an emulator if needed,
- runs `flutter pub get` unless `-NoPubGet` is passed,
- starts `flutter run` so you can use hot reload with `r` and hot restart with `R`.

## Fork Direction

Bankify started as a fork of Waterfly III and is now intended to evolve as a separate app with its own release identity, roadmap, and support flow. This fork focuses on faster maintenance, security hardening, and iterative UI/UX improvements for self-hosted Firefly III users.
