# Handoff Report — Adversarial Challenge of Supabase Local Dev Guide

**Agent**: challenger_2
**Role**: EMPIRICAL CHALLENGER (critic, specialist)
**Target Document**: `C:\Users\kazuk\program\AppList\debata\.agents\SUPABASE_LOCAL_DEV_GUIDE.md`
**Verdict**: **REQUEST_CHANGES**

---

## 1. Challenge Summary

- **Overall Risk Assessment**: **HIGH**
- **Core Findings**:
  1. **CRITICAL CI/CD Race Condition**: `cancel-in-progress: true` in database deployment workflow (`supabase_deploy.yml`) can abort running migration transactions mid-flight, causing production database corruption and stuck deployment states.
  2. **MISSING PR Validation CI Workflow**: Guide claims automated linting/testing in PRs (Section 4.4), but provides no `on: pull_request` workflow in Section 3.4. Broken SQL will merge into `main` before any checks run.
  3. **FLAWED Zero-Downtime (Expand & Contract) Specification**: Lacks dual-write Postgres trigger patterns, non-null default enforcement, and Flutter model resilience rules required to prevent legacy Flutter app crashes.
  4. **UNPROTECTED Migration Order**: No rebase or timestamp collision policy for multi-developer teams, leading to out-of-order migration failures in `supabase db push`.
  5. **SEED & Raw SQL Injection Vulnerabilities**: Raw `auth.users` / `auth.identities` inserts in `seed.sql` risk schema version drift across Supabase CLI updates.

---

## 2. Detailed Observations & Logic Chains

### Challenge 1: CI/CD Pipeline Fatal Race Condition (`cancel-in-progress: true`)
- **Observation**:
  `SUPABASE_LOCAL_DEV_GUIDE.md`, Section 3.4, lines 356-358:
  ```yaml
  concurrency:
    group: supabase-deploy-${{ github.ref }}
    cancel-in-progress: true
  ```
- **Logic Chain**:
  1. In GitHub Actions, setting `cancel-in-progress: true` immediately sends a SIGTERM/SIGKILL to any running workflow instance when a new commit is pushed to `main`.
  2. If Developer A merges PR 1 and `supabase db push` starts applying migrations to the production Postgres database, and Developer B merges PR 2 5 seconds later, GitHub Actions cancels Developer A's `supabase db push` mid-execution.
  3. Cancelling a database migration command mid-stream leaves Postgres in a partially migrated state (e.g. migration 1 applied, migration 2 cancelled halfway).
  4. Supabase's migration tracking table (`supabase_migrations.schema_migrations`) becomes desynchronized with the actual database schema.
  5. Subsequent runs of `supabase db push` will fail with SQL execution errors or schema mismatch, causing production deployment failure.
- **Mitigation Required**:
  Change `cancel-in-progress` to `false` for deployment workflows (`supabase_deploy.yml`), ensuring every deployment runs sequentially to completion.

---

### Challenge 2: Missing Pull Request (PR) Validation CI Pipeline
- **Observation**:
  - Section 4.4 (lines 444-484) claims: "プルリクエスト（PR）のCIパイプラインで以下の検証を自動実行し、不良マイグレーションの本番流入を遮断します (`supabase db reset`, `supabase db lint`, `supabase test db`)."
  - Section 3.4 (lines 344-380) only provides `.github/workflows/supabase_deploy.yml` configured for `on: push: branches: [main]`.
- **Logic Chain**:
  1. Developers opening a Pull Request will have NO automated CI feedback checking SQL syntax, RLS security (`db lint`), or schema reset validity (`db reset`).
  2. Invalid SQL, syntax errors, or unindexed foreign keys will be merged directly into `main` undetected.
  3. The error will only trigger *after* merge during production deployment, causing immediate production failure.
- **Mitigation Required**:
  Add a dedicated PR workflow file `.github/workflows/supabase_ci.yml` triggered on `on: pull_request` that executes `supabase db reset`, `supabase db lint`, and `supabase test db`.

---

### Challenge 3: Incomplete & Risky Zero-Downtime (Expand & Contract) Specification
- **Observation**:
  Section 3.5 (lines 384-406) describes Expand & Contract conceptually in 3 phases, but provides no concrete SQL DDL/DML code or Flutter client guidelines.
- **Logic Chain**:
  1. **Dual-Write Synchronization**: In Phase 1 (Expand), when migrating from `old_col` to `new_col`, legacy Flutter clients in the wild write to `old_col`, while updated clients write to `new_col`. Without Postgres **Triggers** or **Generated Columns** synchronizing data between `old_col` and `new_col`, writes from legacy clients will not be reflected in `new_col`, causing silent data loss/divergence.
  2. **NOT NULL Constraints**: Adding a new column with `NOT NULL` without a `DEFAULT` in Phase 1 causes legacy Flutter clients (which don't populate `new_col`) to fail with `null value in column "new_col" violates not-null constraint`.
  3. **Auto-Generated Diff Risk**: Section 3.1 recommends `supabase db diff`, which generates raw DDL statements (`ALTER TABLE ... RENAME COLUMN` or `DROP COLUMN`). Without explicit warnings, developers will commit breaking diffs directly into a single migration file, bypassing Expand & Contract entirely.
  4. **Flutter Client Resiliency**: Legacy Flutter clients parsing JSON responses with rigid non-nullable models will crash if schema fields shift before app update.
- **Mitigation Required**:
  - Provide concrete SQL examples for Phase 1 (Expand) showing `NULL` / `DEFAULT` usage and dual-write triggers (`BEFORE INSERT OR UPDATE ON table FOR EACH ROW EXECUTE FUNCTION sync_columns()`).
  - Add explicit warning that `supabase db diff` outputs breaking single-step DDL that MUST be manually edited into Expand & Contract phases.
  - Detail Flutter model guidelines (nullable field fallbacks in deserialization).

---

### Challenge 4: Migration Timestamp Conflicts in Multi-Developer Teams
- **Observation**:
  Section 3.1 & 3.3 specify migration creation via `supabase db diff -f` or `supabase migration new`, generating timestamp filenames (`YYYYMMDDHHMMSS_name.sql`).
- **Logic Chain**:
  1. Developer A creates `20260813120000_feature_a.sql` on branch A.
  2. Developer B creates `20260813110000_feature_b.sql` on branch B (created earlier, but merged later).
  3. PR A merges first. Production DB applies `20260813120000`.
  4. PR B merges second. Its timestamp `20260813110000` is older than `20260813120000`.
  5. `supabase db push` fails because Supabase CLI rejects out-of-order migrations by default in remote databases.
- **Mitigation Required**:
  Define a git branching policy: before merging PRs, developers must rebase on `main` and update their migration timestamp (`supabase migration list` / rename timestamp to current time).

---

### Challenge 5: `seed.sql` Fragility & GoTrue Version Drift
- **Observation**:
  Section 2.5 (lines 182-213) provides `INSERT INTO auth.users` and `INSERT INTO auth.identities` with hardcoded schema fields (`instance_id`, `aud`, `role`, `encrypted_password`, etc.).
- **Logic Chain**:
  1. Internal columns of GoTrue's `auth.users` schema evolve across Supabase releases (e.g. addition of `is_sso_user`, `deleted_at`, `is_anonymous`).
  2. Direct column inserts into `auth.users` break when Supabase CLI updates to newer Postgres / GoTrue versions if required columns are omitted.
  3. If a developer accidentally runs a script that executes `seed.sql` on a non-local environment, dummy test users will be injected into production.
- **Mitigation Required**:
  Add safety checks to `seed.sql` (e.g., checking `current_database()` or custom GUC setting) and recommend official Supabase CLI test helpers where applicable.

---

## 3. Stress Test Matrix

| Scenario | Claimed Behavior | Actual / Predicted Vulnerability | Result |
| :--- | :--- | :--- | :--- |
| **Concurrent PR Merges to `main`** | CI/CD automatically deploys migrations safely | `cancel-in-progress: true` kills active `supabase db push`, leaving DB partially migrated | **FAIL (CRITICAL)** |
| **PR containing invalid SQL / broken RLS** | Pre-merge validation catches errors | No PR workflow (`on: pull_request`) defined; invalid SQL merges directly into `main` | **FAIL (HIGH)** |
| **Legacy Flutter client writes to old column during Expand phase** | Zero-downtime migration via Expand & Contract | Legacy writes don't populate new column (no dual-write trigger specified); data loss occurs | **FAIL (HIGH)** |
| **Developer uses `supabase db diff` for column rename** | Schema changes exported to migration file | Generates `RENAME COLUMN` breaking legacy Flutter clients instantly upon `db push` | **FAIL (MEDIUM)** |
| **Out-of-order PR merge (older timestamp merged later)** | Migrations pushed cleanly to production DB | `supabase db push` rejects out-of-order timestamp migrations, locking deployment | **FAIL (MEDIUM)** |

---

## 4. Caveats

- No live production Supabase instance was mutated during this analysis (review conducted via static specification analysis and protocol validation).
- Specific versions of Supabase CLI may handle certain out-of-order flags differently, but default `supabase db push` strictly enforces timestamp order.

---

## 5. Conclusion & Actionable Recommendations

### Final Verdict: **REQUEST_CHANGES**

To make `SUPABASE_LOCAL_DEV_GUIDE.md` production-grade and safe for real-world deployment, the following changes MUST be requested:

1. **Fix CI/CD Deployment Workflow (`.github/workflows/supabase_deploy.yml`)**:
   - Set `cancel-in-progress: false` under `concurrency`.
   - Add deployment locking / error handling strategy.

2. **Add CI PR Validation Workflow (`.github/workflows/supabase_ci.yml`)**:
   - Add concrete YAML for `on: pull_request` running `supabase db reset`, `supabase db lint`, and `supabase test db`.

3. **Enhance Expand & Contract Specification (Section 3.5)**:
   - Include SQL code templates for Phase 1 Expand: `NULL` / `DEFAULT` usage and Postgres dual-write triggers (`CREATE TRIGGER sync_old_new_cols`).
   - Add warning against raw `supabase db diff` outputs for breaking DDL changes.
   - Include Flutter JSON parsing safety guidelines (nullable defaults).

4. **Add Multi-Developer Migration Management**:
   - Document timestamp rebase protocol for resolving out-of-order migrations before PR merge.

5. **Harden `seed.sql`**:
   - Add environment check guard at top of `seed.sql` to prevent execution outside local DB.

---

## 6. Verification Method

To verify these findings independently:
1. **CI/CD Concurrency**: Inspect lines 356-358 of `SUPABASE_LOCAL_DEV_GUIDE.md`. Confirm `cancel-in-progress: true` is present in the `supabase-deploy` concurrency group.
2. **PR Workflow Absence**: Search `SUPABASE_LOCAL_DEV_GUIDE.md` for `pull_request`. Note that no `on: pull_request` workflow block exists.
3. **Expand & Contract Code**: Inspect Section 3.5 of `SUPABASE_LOCAL_DEV_GUIDE.md`. Note that no SQL trigger or Flutter code example is provided.
