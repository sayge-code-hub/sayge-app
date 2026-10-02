# Sayge App

Flutter mobile + web app using **BLoC** and **clean architecture**. Data comes from **Supabase** only (no demo/mock layer).

## Structure

```
lib/
├── core/                  # Shared theme, widgets, errors, config
│   ├── config/
│   ├── theme/
│   ├── widgets/
│   ├── error/
│   └── utils/
├── features/
│   ├── auth/
│   ├── employees/
│   ├── clients/
│   ├── documents/
│   └── settings/
├── injection_container.dart
└── main.dart
```

## Setup

1. Copy `.env.example` → `.env` and fill in values from Supabase → Project Settings → API:
   - `SUPABASE_URL`
   - `SUPABASE_ANON_KEY`
   (`.env` is gitignored and bundled at runtime.)
2. Apply schema: `./scripts/setup_supabase.sh` (or run `supabase/schema.sql` in the SQL editor)
   - Creates `roles` + `users` (profiles linked to Auth), HRMS/DMS tables
   - Employees link to clients via `client_id` (delete client blocked if employees still assigned)
   - `activity_log` records every insert/update/delete on app tables
3. Create users in Authentication → Users (e.g. `aditya.rana@sayge.in`)
   - A `public.users` row is auto-created (default role: Employee)
   - `aditya.rana@sayge.in` is promoted to Owner by the schema backfill

Only `@sayge.in` emails are accepted at login.

## Run

```bash
flutter pub get
flutter run -d chrome          # web
flutter run                    # mobile / desktop
```

After login: **Modules → HRMS → Employees**, **DMS**, and **Settings → Manage clients**.
