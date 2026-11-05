# Flutter side: layout and how to run

| Folder | What it is |
|---|---|
| `mobile/` | Customer app (iOS / Android) |
| `dashboard/` | Admin management dashboard (Flutter Web) |
| `packages/shop_core/` | Shared Dart package: models, API client, error mapping, repositories |

State management: Bloc/Cubit. UI language: English.

## API base URL
Passed with `--dart-define=API_BASE_URL=...` (the app adds `/api/v1`).

| Where it runs | Value |
|---|---|
| iOS Simulator / Chrome | `http://localhost:8000` |
| Android Emulator | `http://10.0.2.2:8000` |
| Real device | `http://<computer IP>:8000` |

```bash
docker compose up -d --build          # backend
cd mobile && flutter run --dart-define=API_BASE_URL=http://localhost:8000
cd dashboard && flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8000
```

## API reference
Interactive docs once the backend is up: `http://localhost:8000/docs/`, `/swagger/`,
`/docs/openapi.yaml`, `/docs/collection.json` (Postman). See `docs/frontend-guide/`.

## Checks before a PR
```bash
(cd packages/shop_core && flutter analyze && flutter test)
(cd mobile && flutter analyze && flutter test)
(cd dashboard && flutter analyze && flutter test)
```

## Running `flutter test` from this folder
The project folder name contains an apostrophe (`Internet Application's project`), which breaks the test runner that
Flutter generates. If `flutter test` fails with "Too many positional arguments", run the tests from a copy of the
project in a path without special characters (or clone the repo to such a path).

## Admin dashboard (Flutter Web)
```bash
cd dashboard && flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8000
```
Sign in with the admin account (`admin@store.test`). A customer account is refused. The token is kept in the
browser's `sessionStorage`, so closing the tab signs you out.

Screens: Orders (real totals per status, page-based table, status buttons taken from the server's
`next_statuses`), Products (search, create with image upload, edit stock), Categories, Notifications.

Known backend limits (no endpoints yet): edit or delete a product or category, list users, sales statistics.
The browser cannot read the `Retry-After` header because the server does not expose it through CORS, so the
rate-limit message there has no countdown.
