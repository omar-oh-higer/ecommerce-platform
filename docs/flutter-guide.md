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
