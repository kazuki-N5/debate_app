## 2026-08-13T10:16:56Z
You are explorer_r3_1.
Working directory: C:\Users\kazuk\program\AppList\debata\.agents\explorer_r3_1

Objective:
Investigate and document Requirement R3: Production data protection, safety measures, and operational best practices for Supabase x Flutter projects.

Tasks:
1. Read C:\Users\kazuk\program\AppList\debata\.agents\ORIGINAL_REQUEST.md.
2. Search and analyze Supabase official documentation, safety guides, and production database administration best practices.
3. Detailed technical items to investigate:
   - Production data non-destruction safeguards (never using `db push` with destructive changes without backup/testing, zero-downtime migration patterns).
   - Destructive migration anti-patterns (e.g. `DROP COLUMN`, `RENAME COLUMN`, incompatible type changes) and safe expansion/contraction refactoring strategies.
   - Database Branching (Supabase Branching feature, Preview Environments, GitHub PR integration).
   - Seed data vs Production data strategy (anonymized dumps, mock seed SQL, avoiding production data in local dev).
   - Pre-deployment validation & linting (`supabase db lint`, `supabase migration list`, automated schema checks in CI).
   - Emergency recovery & rollback readiness (PITR - Point-in-Time Recovery, WAL backups, manual SQL backups).
   - RLS (Row Level Security) and Auth testing safety (local auth emulation vs production auth providers).
4. Verify official Supabase recommendations and security/safety guidelines.
5. Write your detailed findings to C:\Users\kazuk\program\AppList\debata\.agents\explorer_r3_1\handoff.md and report back via send_message.
