-- ============================================================
-- Migration: fix_stale_battles
-- 相手が選択せずに終了したとき「対戦中」が残る問題の対策
--
-- 1. is_user_in_battle : 15分以上更新が無い放置ルームは「対戦中」と見なさない
-- 2. finalize_stale_rooms : 進行中で15分以上放置されたルームを引き分け終了（cron・保険）
-- ============================================================

-- ---------- 1. 対戦中判定の見直し ----------
CREATE OR REPLACE FUNCTION public.is_user_in_battle(p_user_id uuid)
  RETURNS boolean
  LANGUAGE sql
  STABLE
  AS $function$
  SELECT EXISTS (
    SELECT 1 FROM rooms_v2
    WHERE (player1_id = p_user_id OR player2_id = p_user_id)
      AND player2_id IS NOT NULL  -- 実際に対戦が始まっている
      AND winner IS NULL          -- まだ結果が出ていない
      AND updated_at > now() - INTERVAL '15 minutes'  -- 放置ルームは対戦中と見なさない
  );
$function$;

-- ---------- 2. 放置ルームの自動終了（保険） ----------
CREATE OR REPLACE FUNCTION public.finalize_stale_rooms()
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  AS $function$
BEGIN
  -- 進行中（player2確定・winner未確定）で15分以上更新が無いルームを引き分け終了
  UPDATE rooms_v2
     SET winner = 'C', reason = '未選択・放置のため終了', updated_at = now()
   WHERE winner IS NULL AND player2_id IS NOT NULL
     AND updated_at <= now() - INTERVAL '15 minutes';
END;
$function$;

-- cron ジョブを登録（jobname が既存なら更新される・冪等）
SELECT cron.schedule(
  'finalize-stale-rooms',
  '*/5 * * * *',
  $$SELECT public.finalize_stale_rooms()$$
);
