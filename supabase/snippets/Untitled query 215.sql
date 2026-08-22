-- ============================================================
-- Migration: fix_stale_battles_short
-- 放置ルームの対戦中ブロックを 15分 → 3分 に短縮 + 起動時即終了RPC
--
-- 背景: 両者がアプリを閉じたまま放置すると、誰も終了処理を実行せず
--       15分間「対戦中」扱いで試合に出られなくなる問題への対策
-- ============================================================

-- ---------- 1. 対戦中判定: 3分以上更新が無いルームは対戦中と見なさない ----------
CREATE OR REPLACE FUNCTION public.is_user_in_battle(p_user_id uuid)
  RETURNS boolean
  LANGUAGE sql
  STABLE
  AS $function$
  SELECT EXISTS (
    SELECT 1 FROM rooms_v2
    WHERE (player1_id = p_user_id OR player2_id = p_user_id)
      AND player2_id IS NOT NULL
      AND winner IS NULL
      AND updated_at > now() - INTERVAL '3 minutes'
  );
$function$;

-- ---------- 2. 放置ルームの自動終了（cron・3分） ----------
CREATE OR REPLACE FUNCTION public.finalize_stale_rooms()
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  AS $function$
BEGIN
  UPDATE rooms_v2
     SET winner = 'C', reason = '未選択・放置のため終了', updated_at = now()
   WHERE winner IS NULL AND player2_id IS NOT NULL
     AND updated_at <= now() - INTERVAL '3 minutes';
END;
$function$;

SELECT cron.schedule(
  'finalize-stale-rooms',
  '*/5 * * * *',
  $$SELECT public.finalize_stale_rooms()$$
);

-- ---------- 3. 起動時即終了: 自分の放置ルームをその場で終了する ----------
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
     AND updated_at <= now() - INTERVAL '3 minutes'
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
