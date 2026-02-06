# actual-native

Native mobile app (iOS + Android) for **Actual Budget**.

## TL;DR (how to run)

```bash
cd apps/mobile
flutter run
```

### Server URLs
- **Android emulator → host machine:** `http://10.0.2.2:5006`
- **Real device on LAN:** use your host LAN IP, e.g. `http://192.168.1.X:5006`

## What “MVP” means for this project

MVP is only considered done when the app can:
- Login
- Select a budget
- Display **Accounts**, **Transactions**, and **Budget**
- Use Actual’s **real sync** protocol (`/sync/sync`) so it’s usable day-to-day

## Current state (today)

This repo is actively iterating on a YNAB-inspired mobile UX.

On the `sync-bridge` branch, the app currently supports:
- Connect + login + select budget
- First-run hydration (download + open local sqlite) + incremental sync bridge
- Basic transactions workflow: add, edit, categorize (local sqlite)
- Early UX polish passes: theme + reusable list/card components
- Dashboard refresh + last-sync status banner + sync progress/snackbars

### What’s still in-flight

- Budget tab overhaul: month picker, top totals (to-budget/over, budgeted/spent/available), collapsible category groups w/ group totals, clearer unassigned states
- Accounts tab: clearer balances, closed/off-budget indicators, totals row, account detail header balance
- Transactions: better filtering + account-scoped transaction list, clearer cleared/uncleared UX

## Build APK

```bash
cd apps/mobile
flutter build apk --release --split-per-abi
```

Outputs:
- `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`
- `build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk`
- `build/app/outputs/flutter-apk/app-x86_64-release.apk`

## Decisions / project notes

See:
- `DECISIONS.md`

## Repo structure

```
apps/
  mobile/       # Flutter app
packages/
  core/         # shared code (placeholder; optional)
```

## Development workflow

- Main branch stays runnable.
- Larger efforts go to feature branches and PRs (e.g. `sync-bridge`).
