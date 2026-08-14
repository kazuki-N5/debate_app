## 2026-08-13T10:24:43Z

You are worker_m1_3.
Working directory: C:\Users\kazuk\program\AppList\debata\.agents\worker_m1_3

Objective:
Apply final SQL logic fixes to C:\Users\kazuk\program\AppList\debata\.agents\SUPABASE_LOCAL_DEV_GUIDE.md as requested in Iteration 2 Gate status.

Inputs:
- Original Request: C:\Users\kazuk\program\AppList\debata\.agents\ORIGINAL_REQUEST.md
- Gate Action Items: C:\Users\kazuk\program\AppList\debata\.agents\orchestrator_1\GATE_STATUS.md
- Reviewer 2 Handoff: C:\Users\kazuk\program\AppList\debata\.agents\reviewer_2_r2\handoff.md
- Challenger 2 Handoff: C:\Users\kazuk\program\AppList\debata\.agents\challenger_2_r2\handoff.md
- Existing Report: C:\Users\kazuk\program\AppList\debata\.agents\SUPABASE_LOCAL_DEV_GUIDE.md

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_preview_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

Required Edits to C:\Users\kazuk\program\AppList\debata\.agents\SUPABASE_LOCAL_DEV_GUIDE.md:

1. **Fix Section 2.6 `seed.sql` Environment Guard Logic**:
   - Replace the flawed condition in Section 2.6 with:
     ```sql
     -- Guard: Prevent seed execution in production
     DO $$
     BEGIN
       IF current_setting('app.environment', true) IN ('production', 'prod', 'staging') THEN
         RAISE EXCEPTION 'CRITICAL: seed.sql execution blocked in non-local environment!';
       END IF;
     END $$;
     ```

2. **Fix Section 3.6 Dual-Write Trigger SQL Logic**:
   - In Section 3.6, update the PL/pgSQL function `sync_profiles_display_name()` to handle UPDATE events bi-directionally without skipping:
     ```sql
     CREATE OR REPLACE FUNCTION sync_profiles_display_name()
     RETURNS TRIGGER AS $$
     BEGIN
       -- Bi-directional synchronization for Expand phase
       IF NEW.new_display_name IS DISTINCT FROM OLD.new_display_name AND NEW.new_display_name IS NOT NULL THEN
         NEW.old_username := NEW.new_display_name;
       ELSIF NEW.old_username IS DISTINCT FROM OLD.old_username AND NEW.old_username IS NOT NULL THEN
         NEW.new_display_name := NEW.old_username;
       ELSIF NEW.new_display_name IS NULL AND NEW.old_username IS NOT NULL THEN
         NEW.new_display_name := NEW.old_username;
       END IF;
       RETURN NEW;
     END;
     $$ LANGUAGE plpgsql;
     ```

Apply these edits directly to C:\Users\kazuk\program\AppList\debata\.agents\SUPABASE_LOCAL_DEV_GUIDE.md.
Write your handoff report to C:\Users\kazuk\program\AppList\debata\.agents\worker_m1_3\handoff.md and report back via send_message.
