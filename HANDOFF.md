# Bankify Handoff

Last updated: 2026-04-27

## Current State

- Repo: `C:\SoftwareDevelopment\Personal\bankify`
- Baseline branch: `master`
- Remote baseline: `origin/master`
- Current synced commit at handoff creation: `a579b74`
- Working tree status at handoff creation: clean
- Android is the active platform focus. iOS remains out of scope for now.

## What Is Safe To Rely On

- The canonical project history is the Git remote, not local chat state.
- The canonical implementation plan and completed-phase history live in `ROADMAP.md`.
- Manual release/security verification steps live in `MANUAL_SECURITY_QA.md`.
- Local Android preview workflow lives in `preview-android.cmd` and `scripts/preview-android.ps1`.

## Project Snapshot

- Security/privacy hardening phases are complete through the current roadmap.
- Architecture cleanup phases are complete through the current roadmap.
- Phase 6 UX/product backlog slices currently listed in `ROADMAP.md` are complete.
- The next recommended move is not another predefined roadmap slice. It is either:
  - extending the roadmap with a new phase, or
  - starting a user-prioritized feature/UI branch from the current baseline.

## Local Tooling Expectations

- Flutter version: `3.35.6`
- Dart constraint: `>=3.7.0 <4.0.0`
- Preferred local preview entrypoint from repo root:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\preview-android.ps1
```

- Double-click launcher:

```text
preview-android.cmd
```

## Resume Checklist On Another Machine

1. Clone the repo and open it at the repo root.
2. Confirm `git status` is clean and `master` tracks `origin/master`.
3. Install/use Flutter `3.35.6`.
4. Run `flutter pub get`.
5. Use the Android emulator preview workflow if you need UI validation.
6. Read `ROADMAP.md` and this file before starting a new implementation branch.

## Machine-Switch Safety Rule

Before leaving any machine, do not assume Codex chat history will follow you. Instead:

1. Make sure all work you want to keep is committed.
2. Push every branch that contains work you may need later.
3. Update this file if the repo state or next-step guidance has changed materially.

## Reusable Codex Prompt

Use the prompt in `MACHINE_SWITCH_PROMPT.md` in any future thread when you want Codex to do a full machine-switch sync check and leave behind a durable handoff.
