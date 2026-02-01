# actual-native

Native mobile app (iOS + Android) for **Actual Budget**.

This repo contains a Flutter app that connects to a locally-hosted Actual server on Daniel’s LAN.

## TL;DR (how to run)

```bash
cd /home/danielg/clawd/actual-native/apps/mobile
flutter run
```

### Server URLs
- **LAN (real device on your network):** `http://192.168.1.182:5006`
- **Android emulator → host machine:** `http://10.0.2.2:5006`

## What “MVP” means for this project

MVP is only considered done when the app can:
- Login
- Select a budget
- Display **Accounts**, **Transactions**, and **Budget**
- Use Actual’s **real sync** protocol (`/sync/sync`) so it’s actually usable day-to-day

## Current state

- Flutter app scaffolding + password login + budgets list
- Interim viewer implementation exists (download `/sync/download-user-file` → open `db.sqlite`) to accelerate UI iteration
- Proper sync implementation is tracked on branch `sync-bridge`

## Decisions / project notes

See:
- `DECISIONS.md` (high-level decisions: Flutter, Docker server, MVP definition, YNAB-inspired UX)

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
