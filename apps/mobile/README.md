# actual-native mobile (Flutter)

## Run

```bash
cd /home/danielg/clawd/actual-native/apps/mobile
flutter run
```

## Server URL notes

- **LAN (real device):** `http://192.168.1.182:5006`
- **Android emulator:** `http://10.0.2.2:5006`

If you can’t connect, double-check you are on the same LAN and the server container is running.

## Current UX flow

1. Enter server URL
2. Tap **Connect**
3. Enter password
4. Tap **Login + Load Budgets**
5. Tap a budget to open it

## MVP target

The MVP must be **actually usable**, meaning:
- Accounts list
- Transactions register
- Budget/categories view
- Uses Actual’s real `/sync/sync` protocol (protobuf + CRDT message log), not only file download.

## UX reference

Design should take inspiration from **YNAB** for speed and low-tap daily workflows.
