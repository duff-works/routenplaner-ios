# SDD Progress — Routenplaner iOS (Phase 0 + Phase 1)

Plan: `../routenplaner/docs/superpowers/plans/2026-07-13-ios-phase-0-1-walking-skeleton.md` (in the monorepo).
Repo: https://github.com/duff-works/routenplaner-ios (public). Local: C:/Projects/routenplaner-ios.
Verification env: GitHub Actions `macos-15` only (no local Swift/Xcode on Windows).

## Phase 0 — Pipeline proof — ✅ COMPLETE (CI-verified)
- Repo bootstrap, scaffold + CI (commits f03edfe..27b392a).
- CI run 29254774612 green; IPA verify-ipa.py PASS (LC_CODE_SIGNATURE=YES platform=2). IPA at build/Routenplaner-adhoc.ipa.
- Remaining: user sideloads to confirm launch (deferred — will test via the richer Phase 1 IPA).

## Phase 1 — Walking skeleton
- Logic layer (ServerURL, Models, APIError + tests): commits ..c12531b. CI run 29255133731 green (swift test PASS). ✅
- App layer (ConnectionStore, Keychain, APIClient, AppState, ConnectionView, SSHSettingsView, LoginView/VM, MainTabView, root): commits ..856d732. CI run 29255338930 IN PROGRESS (xcodebuild build + archive).
  - Fix applied vs plan: `.cancelButton` -> `.cancellationAction` (valid ToolbarItemPlacement).
- Pending after build green: final whole-branch code review; user on-device login acceptance test.

## Notes
- Auth is `?token=` query for data requests; login/verify/logout carry token in body.
- Do NOT use @Observable (iOS 16 → ObservableObject).
