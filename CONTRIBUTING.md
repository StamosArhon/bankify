# Contributing

## Baseline Branch

- As of 2026-04-11, the baseline branch for this fork is `master`.
- If you rename `master` to `main`, update `ROADMAP.md`, `.github/dependabot.yml`, and `.github/workflows/release.yml` in the same branch.

## Toolchain

- Use Flutter `3.35.6`.
- The exact Flutter version is declared in `pubspec.yaml`.
- GitHub Actions reads the pinned version from `pubspec.yaml`, so local work should use the same SDK line before running checks.

## Local UI Preview

- The recommended local UI/UX workflow is Android emulator + `flutter run`.
- A helper script is available at `scripts/preview-android.ps1`.
- From PowerShell, run `.\scripts\preview-android.ps1` to launch an emulator if needed and start the app with hot reload.
- Use `.\scripts\preview-android.ps1 -AvdName <name>` to choose a specific Android Virtual Device.
- Use `.\scripts\preview-android.ps1 -SkipEmulatorLaunch` if you already have a device or emulator running.
- Use `.\scripts\preview-android.ps1 -FlutterPath <path-to-flutter.bat>` if you keep the pinned Flutter SDK in a side-by-side install.
- Inside the running Flutter session, press `r` for hot reload and `R` for hot restart.

## Branch Workflow

1. Start from `master` until the baseline branch is intentionally renamed.
2. Create focused branches using `stamos/<phase>-<short-slug>`.
3. Keep the branch scoped to one roadmap slice.
4. Run the relevant checks for the slice before reviewing the diff.
5. Review the diff against `master`.
6. Commit once the slice is complete.
7. Merge to `master`.
8. Delete the feature branch locally and remotely.
9. Update `ROADMAP.md` if scope, risks, or next steps changed.

## Recommended Local Checks

```bash
flutter pub get
dart format --set-exit-if-changed .
dart analyze .
flutter test
```
