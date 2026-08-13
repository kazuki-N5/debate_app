# Handoff Report — Requirement R1: Local Development Environment Initialization (Flutter x Supabase)

## Executive Summary
This document provides an exhaustive, authoritative specification and operational guide for initializing a local development environment for an existing production Flutter x Supabase application.

---

## 1. Features & Commands Discovered

| # | Category | Feature | Description | Inputs | Outputs | Error Behavior | Discovered Via |
|---|----------|---------|-------------|--------|---------|----------------|----------------|
| 1 | Prerequisites | Supabase CLI Installation | Installing Supabase CLI tool on dev machine | Brew (`brew install supabase/tap/supabase`), Scoop (`scoop install supabase`), Winget (`winget install Supabase.CLI`), NPM (`npm i -g supabase`) | Executable binary `supabase` in PATH | Command not found if PATH not set; installer error if package manager fails | Supabase Official Docs |
| 2 | Prerequisites | Docker Engine Verification | Checking container runtime status | `docker info` or `docker ps` | Docker daemon info / status | `Cannot connect to the Docker daemon`: Docker not running | Supabase CLI Spec |
| 3 | Authentication | CLI Login | Authenticating CLI with Supabase Cloud | `supabase login` or `SUPABASE_ACCESS_TOKEN` env var | Personal Access Token saved in local config (`~/.config/supabase/`) | Browser timeout / invalid token error | Supabase CLI Spec |
| 4 | Project Setup | Project Initialization | Creating `supabase/` directory with local config | `supabase init` (Optional `--workdir`) | `supabase/config.toml`, `supabase/seed.sql`, `supabase/migrations/` | Error if directory already initialized | Supabase CLI Spec |
| 5 | Linking | Link Remote Project | Linking local workspace to production project | `supabase link --project-ref <ref>` (Flags: `--password <pass>` or `SUPABASE_DB_PASSWORD`) | `supabase/.temp/project-ref` link file created | Prompt failure if wrong password; invalid ref error if project ID incorrect | Supabase CLI Spec |
| 6 | Schema Pull | Pull Remote Schema | Extracting DDL schema from production DB into local migration | `supabase db pull` (Flags: `--schema <name>`, `-f <filename>`) | `supabase/migrations/<TIMESTAMP>_remote_schema.sql` created | Connection timeout / auth failure if password incorrect; migration drift error if schema conflicts | Supabase CLI Spec |
| 7 | Baseline Migration | Dump Database Schema | Alternative export of schema DDL | `supabase db dump --linked -f supabase/migrations/<timestamp>_init.sql` | SQL dump file containing schema DDL | Database connection failure | Supabase CLI Spec |
| 8 | Service Management | Start Local Stack | Launching local Supabase Docker container ecosystem | `supabase start` (Flags: `--ignore-health-check`) | Local services started (Postgres, Auth, Storage, Realtime, Studio, Inbucket, Gateway) | Port conflict error (e.g. 54321/54322 in use); Docker daemon offline error | Supabase CLI Spec |
| 9 | Service Management | Status Inspection | Displaying local URLs, ports, anon keys, and DB credentials | `supabase status` | Text table with API URL, GraphQL URL, DB URL, Studio URL, Inbucket URL, anon key, service_role key | Error if stack not running (`supabase start` required) | Supabase CLI Spec |
| 10 | Data Seeding | Database Reset & Seeding | Dropping local DB, applying all migrations sequentially, running seed script | `supabase db reset` | Rebuilt local DB with applied schema and seeded mock data | SQL syntax error in migration or seed.sql; missing extension error | Supabase CLI Spec |
| 11 | Data Seeding | Auth User Mocking | Inserting test users into `auth.users` with encrypted passwords | SQL script in `supabase/seed.sql` using `extensions.crypt()` and `gen_salt('bf')` | Pre-populated test accounts ready for login | Unique constraint violation if ID/email duplicated; invalid salt error | Supabase Auth Docs |
| 12 | App Integration | Environment Config | Passing local vs production API parameters to Flutter | `--dart-define=SUPABASE_URL=...`, `--dart-define-from-file=.env.json`, or `.env` via `flutter_dotenv`/`envied` | Compile-time / runtime environment variables loaded | Missing variable runtime null error if default not handled | Flutter & Supabase Docs |
| 13 | App Integration | Host Loopback Mapping | Mapping platform-specific loopback addresses for local Supabase API | `127.0.0.1:54321` (iOS/Desktop/Web), `10.0.2.2:54321` (Android Emulator), `<LAN_IP>:54321` (Physical Device) | Successful HTTP/WS connections from Flutter app to local Supabase Gateway | `Connection refused` (SocketException) if wrong host used | Android Emulator & Flutter Docs |
| 14 | App Integration | Port Forwarding Alias | Forwarding Android emulator port to host localhost | `adb reverse tcp:54321 tcp:54321` | Android emulator routes `localhost:54321` directly to host machine | `device not found` if emulator not running | Android ADB Docs |
| 15 | App Integration | Auth Redirect Configuration | Configuring OAuth & Email deep link callbacks in local config | `[auth] site_url`, `additional_redirect_urls` in `supabase/config.toml` | Allowed redirect URIs for local authentication flow | Redirect blocked error (400 Bad Request) if scheme/URL not whitelisted | Supabase Auth Docs |

---

## 2. Observed Edge Cases & Handling Strategies

| # | Feature | Input / Condition | Observed Behavior | Recommended Solution / Prevention |
|---|---------|-------------------|-------------------|-----------------------------------|
| 1 | `supabase start` | Port conflict on 54321 or 54322 (e.g., local PostgreSQL or another service running) | Container failed to start, error: `port is already allocated` | Edit `supabase/config.toml` to change default ports (e.g. `[api] port = 54321` or `[db] port = 54322`) or kill conflicting local service |
| 2 | `supabase db pull` | Production DB uses extensions not installed locally or custom schemas | `db pull` creates SQL referencing non-existent schemas/extensions | Ensure all required extensions are enabled in `config.toml` (`[db] major_version` / extensions) and include custom schemas under `[db] schemas = ["public", "custom_schema"]` |
| 3 | `supabase db reset` | `seed.sql` attempts to insert into `auth.users` without corresponding `auth.identities` | User created in `auth.users` cannot log in via password auth in GoTrue | Always pair `auth.users` insert with matching `auth.identities` insert in `seed.sql` using provider `'email'` |
| 4 | Flutter Android | Flutter app targets `http://127.0.0.1:54321` on Android Emulator | App throws `SocketException: Connection refused (OS Error: Connection refused, errno = 111)` | Change URL to `http://10.0.2.2:54321` for Android, or run `adb reverse tcp:54321 tcp:54321` before running app |
| 5 | Flutter Physical Device | App targeting local Supabase on physical device via LAN IP (`http://192.168.x.x:54321`) | Connection times out or rejected by OS firewall | Ensure PC firewall permits incoming TCP on 54321 & 54322, and device is connected to the same Wi-Fi subnet |
| 6 | Auth Deep Link | OAuth / Email confirmation callback redirects to `com.example.app://login-callback` | Deep link fails or is rejected with `redirect_uri_not_allowed` | Whitelist custom app scheme in `supabase/config.toml` under `additional_redirect_urls = ["com.example.app://login-callback"]` |
| 7 | Baseline Schema | Running `supabase db pull` on project with direct Dashboard SQL changes | Pulls huge schema diff without tracking history | Run `supabase db pull` once to baseline, verify SQL file in `supabase/migrations/`, commit to Git, and prohibit direct Dashboard edits going forward |
| 8 | Production Data Safety | Running `supabase db push` accidentally against production during setup | Local dev migrations prematurely applied to production DB | Never run `db push` during R1 initialization. Keep production credentials isolated and enforce CI/CD deployment pipelines |

---

## 3. Step-by-Step Technical Initialization Guide

### Step 1: Prerequisites Verification & Installation
1. Install Docker Desktop / Podman and start Docker daemon.
   - Verify: `docker info`
2. Install Supabase CLI:
   - **Windows (Scoop)**: `scoop bucket add supabase https://github.com/supabase/scoop-bucket.git` && `scoop install supabase`
   - **Windows (Winget)**: `winget install Supabase.CLI`
   - **Windows/Cross-platform (NPM)**: `npm install -g supabase`
   - **macOS/Linux (Brew)**: `brew install supabase/tap/supabase`
   - Verify: `supabase --version`
3. Login to Supabase CLI:
   - `supabase login`
   - Generates Personal Access Token via browser authentication.

### Step 2: Initialize Project Workspace
In the root directory of the existing Flutter project:
```bash
supabase init
```
This generates:
- `supabase/config.toml` — Configuration file for local ports, auth settings, storage, edge functions, etc.
- `supabase/seed.sql` — Initial seed data script.
- `supabase/migrations/` — Empty directory for migration files.

Update `.gitignore` to include:
```gitignore
# Supabase CLI temporary files
supabase/.temp/
supabase/.branches/
```

### Step 3: Link Local CLI to Production Supabase Project
Obtain the **Project Reference ID** from Supabase Dashboard (`https://supabase.com/dashboard/project/<project-ref>/settings/general`).

Execute link command:
```bash
supabase link --project-ref <project-ref>
```
When prompted, enter the Database Password (or supply via `SUPABASE_DB_PASSWORD` environment variable).

### Step 4: Baseline Remote Production Database Schema (`supabase db pull`)
To import the current production schema into a local migration file:
```bash
supabase db pull
```
This generates a baseline migration file:
`supabase/migrations/<TIMESTAMP>_remote_schema.sql`

Inspect the generated migration file to ensure:
- All custom tables, views, enums, triggers, and functions are captured.
- RLS (Row Level Security) policies are included.

### Step 5: Start Local Supabase Stack (`supabase start`)
Launch all local Supabase services via Docker:
```bash
supabase start
```
Upon startup, retrieve endpoint URLs and API keys by running:
```bash
supabase status
```
Output breakdown:
- **API Gateway (Kong)**: `http://127.0.0.1:54321`
- **DB (PostgreSQL)**: `postgresql://postgres:postgres@127.0.0.1:54322/postgres`
- **Studio (Web GUI)**: `http://127.0.0.1:54323`
- **Inbucket (Email Testing)**: `http://127.0.0.1:54324`
- **anon key**: `<JWT_ANON_KEY>`
- **service_role key**: `<JWT_SERVICE_ROLE_KEY>`

### Step 6: Configure Seed Data (`supabase/seed.sql` & `supabase db reset`)
Populate `supabase/seed.sql` with mock users and domain data:
```sql
-- Seed Mock Auth User
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token
) VALUES (
  '00000000-0000-0000-0000-000000000000',
  '11111111-1111-1111-1111-111111111111',
  'authenticated', 'authenticated',
  'devuser@example.com',
  extensions.crypt('Password123!', extensions.gen_salt('bf')),
  now(),
  '{"provider":"email","providers":["email"]}',
  '{"name":"Dev User"}',
  now(), now(), ''
) ON CONFLICT (id) DO NOTHING;

INSERT INTO auth.identities (
  id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at, provider_id
) VALUES (
  '11111111-1111-1111-1111-111111111111',
  '11111111-1111-1111-1111-111111111111',
  format('{"sub":"%s","email":"%s"}', '11111111-1111-1111-1111-111111111111', 'devuser@example.com')::jsonb,
  'email', now(), now(), now(), 'devuser@example.com'
) ON CONFLICT (id) DO NOTHING;
```

Run database reset to verify clean rebuild:
```bash
supabase db reset
```

### Step 7: Flutter Integration Setup
1. **Environment Configuration**:
   Create `.env.local` for local dev:
   ```env
   SUPABASE_URL=http://127.0.0.1:54321
   SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
   ```
   Create `.env.production` for production builds.

2. **Flutter Platform Host Selector (`lib/core/config/supabase_config.dart`)**:
   ```dart
   import 'package:flutter/foundation.dart';
   import 'package:supabase_flutter/supabase_flutter.dart';

   class SupabaseConfig {
     static String get url {
       const envUrl = String.fromEnvironment('SUPABASE_URL');
       if (envUrl.isNotEmpty) return envUrl;

       // Default local fallback based on target platform
       if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
         return 'http://10.0.2.2:54321';
       }
       return 'http://127.0.0.1:54321';
     }

     static String get anonKey {
       return const String.fromEnvironment(
         'SUPABASE_ANON_KEY',
         defaultValue: 'YOUR_LOCAL_ANON_KEY',
       );
     }

     static Future<void> init() async {
       await Supabase.initialize(
         url: url,
         anonKey: anonKey,
         debug: kDebugMode,
       );
     }
   }
   ```

3. **Running Flutter App**:
   - **Android Emulator**:
     ```bash
     flutter run --dart-define=SUPABASE_URL=http://10.0.2.2:54321 --dart-define=SUPABASE_ANON_KEY=<LOCAL_ANON_KEY>
     ```
     Or use port forwarding:
     ```bash
     adb reverse tcp:54321 tcp:54321
     flutter run --dart-define=SUPABASE_URL=http://127.0.0.1:54321 --dart-define=SUPABASE_ANON_KEY=<LOCAL_ANON_KEY>
     ```
   - **iOS Simulator / macOS / Web**:
     ```bash
     flutter run --dart-define=SUPABASE_URL=http://127.0.0.1:54321 --dart-define=SUPABASE_ANON_KEY=<LOCAL_ANON_KEY>
     ```

---

## 4. Handoff Protocol Specification

### 1. Observation
- Verified Supabase CLI installation routes (`brew`, `scoop`, `winget`, `npm`).
- Evaluated `supabase init`, `supabase link`, `supabase db pull`, `supabase start`, `supabase status`, `supabase db reset`.
- Verified network address rules for Flutter: `127.0.0.1` for iOS/Desktop/Web, `10.0.2.2` for Android Emulator, `adb reverse tcp:54321 tcp:54321` port-forwarding option.
- Analyzed auth mock seeding requirements in PostgreSQL (`auth.users` + `auth.identities` using `extensions.crypt()`).

### 2. Logic Chain
1. Production applications require isolation between production data and developer changes.
2. Initializing `supabase init` creates version-controllable configuration files (`config.toml`) and migration folders.
3. `supabase link` binds the local CLI workspace to the production project metadata.
4. `supabase db pull` extracts the existing production schema to construct an initial baseline migration (`<timestamp>_remote_schema.sql`), ensuring local Docker DB mirrors production structure without importing production customer data (PII).
5. `supabase start` boots local PostgreSQL, Auth, Storage, Edge Functions, and Studio UI using standard Docker containers.
6. `supabase db reset` verifies that the local DB can be completely torn down and rebuilt from scratch using baseline migrations and `supabase/seed.sql`.
7. Dynamic Flutter configuration via `String.fromEnvironment` ensures zero code changes are required when switching between local emulators (`10.0.2.2` / `127.0.0.1`) and production remote URLs.

### 3. Caveats
- `supabase db pull` only extracts database DDL (schemas, tables, RLS, functions, enums, extensions). Storage bucket configurations or custom Auth SMTP settings must be manually reflected in `supabase/config.toml`.
- Physical devices require LAN IP access and host machine firewall configuration.
- Password hashes in `auth.users` require the `pgcrypto` / `extensions.crypt()` function in PostgreSQL.

### 4. Conclusion
Local development environment initialization for an existing production Flutter x Supabase project can be achieved cleanly and safely in 7 discrete steps without exposing production user data or impacting live users.

### 5. Verification Method
1. Run `docker info` to verify container runtime.
2. Run `supabase --version` to check CLI.
3. Run `supabase init` and check generated `supabase/config.toml`.
4. Run `supabase link --project-ref <ref>` and confirm project binding.
5. Run `supabase db pull` and check for `<timestamp>_remote_schema.sql` under `supabase/migrations/`.
6. Run `supabase start` and verify Studio access at `http://127.0.0.1:54323`.
7. Run `supabase db reset` and verify error-free execution of migrations and `seed.sql`.
8. Execute Flutter app with `flutter run --dart-define=SUPABASE_URL=http://10.0.2.2:54321` and verify auth & database calls reach local Supabase.
