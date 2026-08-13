# Plan — orchestrator_2 (Gen 2)

## Objective
Complete Iteration 3 Gate Verification for `SUPABASE_LOCAL_DEV_GUIDE.md`, record `GATE_STATUS.md`, and report final victory to Sentinel (`e003ec0d-ade8-44a0-a2a7-aa85a5c7a039`).

## Execution Steps

1. **Workspace & Cron Setup**:
   - Initialize `orchestrator_2` state files (`DISPATCH.md`, `BRIEFING.md`, `plan.md`, `progress.md`).
   - Start 10-minute heartbeat cron (`schedule`).

2. **Iteration 3 Gate Verification Dispatch**:
   - Create directories for 5 verification subagents:
     - `.agents/reviewer_1_r3`
     - `.agents/reviewer_2_r3`
     - `.agents/challenger_1_r3`
     - `.agents/challenger_2_r3`
     - `.agents/auditor_1_r3`
   - Invoke parallel verification panel:
     - 2 Reviewers (`teamwork_preview_reviewer`): Technical & Operational / Security accuracy of Iteration 3 fixes in `SUPABASE_LOCAL_DEV_GUIDE.md`.
     - 2 Challengers (`teamwork_preview_challenger`): Empirical & Adversarial verification of Section 2.6 `seed.sql` guard and Section 3.6 Dual-Write trigger SQL logic.
     - 1 Forensic Auditor (`teamwork_preview_auditor`): Forensic integrity verification of `SUPABASE_LOCAL_DEV_GUIDE.md`.

3. **Gate Aggregation & Gate Verdict**:
   - Collect handoffs from all 5 verification subagents.
   - Evaluate verdicts: All Reviewers APPROVE, all Challengers APPROVE, Auditor CLEAN.
   - Record `C:\Users\kazuk\program\AppList\debata\.agents\orchestrator_2\GATE_STATUS.md`.

4. **Final Victory Reporting**:
   - Write `C:\Users\kazuk\program\AppList\debata\.agents\orchestrator_2\handoff.md`.
   - Send final message to Sentinel (`e003ec0d-ade8-44a0-a2a7-aa85a5c7a039`) summarizing findings and confirming delivery of `SUPABASE_LOCAL_DEV_GUIDE.md`.
