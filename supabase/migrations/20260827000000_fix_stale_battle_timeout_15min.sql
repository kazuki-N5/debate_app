-- ============================================================
-- Migration: fix_stale_battle_timeout_15min
-- 試合時間が最長10分であることを考慮し、
-- 放置ルームの強制終了（cron / 起動時RPC）の閾値を 3分 → 15分 に変更する
--
-- 1. finalize_stale_rooms : 進行中で15分以上放置されたルームを引き分け終了（cron）
-- 2. finalize_user_stale_room : 進行中で15分以上放置された自分のルームを即終了（RPC）
-- ============================================================

-- ---------- 1. 放置ルームの自動終了（cron・15分） ----------
CREATE OR REPLACE FUNCTION public.finalize_stale_rooms()
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  AS $function$
BEGIN
  -- 進行中（player2確定・winner未確定・キャンセル済みでない）で
  -- 15分以上更新が無いルームを引き分け終了
  UPDATE rooms_v2
     SET winner = 'C', reason = '未選択・放置のため終了', updated_at = now()
   WHERE winner IS NULL AND player2_id IS NOT NULL
     AND player1_go IS DISTINCT FROM false
     AND player2_go IS DISTINCT FROM false
     AND updated_at <= now() - INTERVAL '15 minutes';
END;
$function$;

-- cron ジョブを再登録（jobname が既存なら更新される・冪等）
SELECT cron.schedule(
  'finalize-stale-rooms',
  '*/5 * * * *',
  $$SELECT public.finalize_stale_rooms()$$
);

-- ---------- 2. 起動時即終了: キャンセル済みは対象外・15分以上放置 ----------
CREATE OR REPLACE FUNCTION public.finalize_user_stale_room(p_user_id uuid)
  RETURNS json
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_room_id uuid;
BEGIN
  UPDATE rooms_v2
     SET winner = 'C', reason = '放置のため終了', updated_at = now()
   WHERE winner IS NULL AND player2_id IS NOT NULL
     AND (player1_id = p_user_id OR player2_id = p_user_id)
     AND player1_go IS DISTINCT FROM false
     AND player2_go IS DISTINCT FROM false
     AND updated_at <= now() - INTERVAL '15 minutes'
   RETURNING id INTO v_room_id;

  IF v_room_id IS NULL THEN
    RETURN json_build_object('success', false, 'room_id', NULL);
  END IF;
  RETURN json_build_object('success', true, 'room_id', v_room_id);
END;
$function$;

GRANT ALL ON FUNCTION public.finalize_user_stale_room(uuid) TO anon;
GRANT ALL ON FUNCTION public.finalize_user_stale_room(uuid) TO authenticated;
GRANT ALL ON FUNCTION public.finalize_user_stale_room(uuid) TO service_role;
