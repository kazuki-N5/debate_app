## 2026-08-13T10:16:56Z
You are explorer_r2_1.
Working directory: C:\Users\kazuk\program\AppList\debata\.agents\explorer_r2_1

Objective:
Investigate and document Requirement R2: Development-to-production migration and merge flow for an existing Flutter x Supabase project.

Tasks:
1. Read C:\Users\kazuk\program\AppList\debata\.agents\ORIGINAL_REQUEST.md.
2. Search and analyze Supabase official documentation and migration best practices for schema changes and deployment.
3. Detailed technical items to investigate:
   - Schema change workflow in local environment (UI via local Studio vs SQL scripts).
   - Generating migration files (`supabase db diff -f <migration_name>`, `supabase migration new <name>`).
   - Local validation & testing of migrations (`supabase db reset`).
   - Git version control best practices for `supabase/` directory (`supabase/config.toml`, `supabase/migrations/*`, `supabase/seed.sql`).
   - Applying migrations to production (`supabase db push`, access token requirements, database password vs access token).
   - Automated CI/CD deployment flow via GitHub Actions (official `supabase/setup-cli` action, secrets management `SUPABASE_ACCESS_TOKEN`, `SUPABASE_DB_PASSWORD`, `DB_PROJECT_REF`).
   - Handling Flutter client code changes alongside DB schema changes (backward compatibility, feature flags, deployment order).
4. Verify exact CLI commands, step-by-step merge flow, and recommended deployment strategies.
5. Write your detailed findings to C:\Users\kazuk\program\AppList\debata\.agents\explorer_r2_1\handoff.md and report back via send_message.
