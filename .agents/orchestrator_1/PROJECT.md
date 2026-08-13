# Project: Flutter x Supabase Local Dev & Dev-to-Prod Merge Best Practices

## Architecture
- Framework: Flutter (Dart)
- Backend Infrastructure: Supabase (PostgreSQL, Auth, Storage, Edge Functions, Studio)
- CLI / Local Stack: Supabase CLI + Docker Desktop / Podman
- Version Control: Git (GitHub Actions CI/CD)
- Deployment Model: Infrastructure-as-Code via database migrations (`supabase/migrations/*.sql`)

## Feature Inventory
| # | Feature | Description | Milestone | Source |
|---|---------|-------------|-----------|--------|
| 1 | R1.1 Prerequisites & Installation | Docker & Supabase CLI setup across OS | M1 | survey |
| 2 | R1.2 Project Init & Remote Linking | `supabase init` & `supabase link --project-ref` | M1 | survey |
| 3 | R1.3 Baseline Schema Extraction | `supabase db pull` for existing prod DB | M1 | survey |
| 4 | R1.4 Local Stack Launch & Verification | `supabase start`, `supabase status`, Studio | M1 | survey |
| 5 | R1.5 Mock Seed Data Setup | `supabase/seed.sql` & auth user mocking | M1 | survey |
| 6 | R1.6 Flutter Environment Config | Multi-platform host loopback & `.env` | M1 | survey |
| 7 | R2.1 Local Schema Changes & Migration | Studio UI, `db diff`, `migration new` | M1 | survey |
| 8 | R2.2 Migration Reset & Verification | `supabase db reset` local testing | M1 | survey |
| 9 | R2.3 Git Version Control Strategy | Tracking `config.toml`, `migrations/`, `seed.sql` | M1 | survey |
| 10| R2.4 Prod Migration Deployment | `supabase db push`, CLI auth tokens | M1 | survey |
| 11| R2.5 CI/CD Automation | GitHub Actions `setup-cli` workflow | M1 | survey |
| 12| R2.6 Zero-Downtime Client Sync | Expand-Contract pattern for Flutter | M1 | survey |
| 13| R3.1 Anti-Schema-Drift Safeguards | Prohibiting direct Dashboard edits | M1 | survey |
| 14| R3.2 Database Branching & Previews | Supabase Branching / GitHub PR integration | M1 | survey |
| 15| R3.3 Production Data Protection | Anonymized dumps & mock seed isolation | M1 | survey |
| 16| R3.4 Automated CI Verification | `supabase db lint` & `supabase test db` | M1 | survey |
| 17| R3.5 Disaster Recovery & Rollback | PITR & Forward-fix strategy | M1 | survey |

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| 1 | M1: Comprehensive Best Practice Report | Write SUPABASE_LOCAL_DEV_GUIDE.md covering R1, R2, R3 | Survey Phase | IN_PROGRESS |

## Interface Contracts
### Report Structure ↔ Acceptance Criteria
- Section 1: Executive Summary & Architectural Overview
- Section 2: Requirement R1 - Local Development Environment Setup (Commands & Flutter Config)
- Section 3: Requirement R2 - Dev-to-Prod Merge Flow & CI/CD Migration Deployment
- Section 4: Requirement R3 - Production Data Safeguards, Zero-Downtime & Operations
- Section 5: Step-by-Step Command Cheat Sheet & Verification Checklist

## Code Layout
- Target Report Artifact: `C:\Users\kazuk\program\AppList\debata\.agents\SUPABASE_LOCAL_DEV_GUIDE.md`
