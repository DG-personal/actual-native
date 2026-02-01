# DECISIONS

This file captures the key decisions made while building `actual-native`.

## 2026-01 to 2026-02: Initial direction

### Mobile stack
- **Flutter** for iOS + Android.
  - Goal: fast iteration, good native feel, single codebase.

### Server / hosting
- Target is **local-only** hosting on Daniel’s LAN.
- We run the Actual server via **Docker** (recommended for stability).
  - LAN URL example: `http://192.168.1.182:5006`
  - Android emulator URL to host: `http://10.0.2.2:5006`

### Authentication
- Password auth is the baseline.
- OpenID/Google login is supported by Actual (server-side), but **not required for MVP**.
  - Flutter has scaffolding for OpenID callback handling.

### MVP definition (current)
MVP is **usable**, meaning:
- Login
- Select budget
- See **Accounts**, **Transactions**, and **Budget** views.
- Uses **real sync** (Actual `/sync/sync` protocol) — no “download sqlite and call it done”.

### Development strategy
- Build a **read-only MVP path** first to validate schema + UI.
  - Interim approach used: download `/sync/download-user-file`, extract `db.sqlite`, render accounts/transactions/categories.
  - This is a stepping stone, not final.
- Then implement proper sync:
  - protobuf `application/actual-sync`
  - CRDT message log
  - HULC timestamps / clock
  - state machine for reset/key mismatch

### Git workflow
- Push incremental commits.
- Create feature branches for larger work (e.g. `sync-bridge`) and open PRs for review.
