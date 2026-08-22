-- ============================================================
-- Migration: cleanup_expired_resbas_24h
-- 24時間以上経過した未開始レスバ（pending）と応募（pending）を自動キャンセル
-- ============================================================

-- ---------- 1. cleanup_expired_resbas 関数 ----------
CREATE OR REPLACE FUNCTION public.cleanup_expired_resbas()
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_expired_ids uuid[];
BEGIN
  -- 1. 24時間以上経過した pending 状態のレスバ ID を取得
  SELECT array_agg(id) INTO v_expired_ids
  FROM public.battle_invites
  WHERE status = 'pending'
    AND created_at < now() - INTERVAL '24 hours';

  IF v_expired_ids IS NOT NULL AND array_length(v_expired_ids, 1) > 0 THEN
    -- 2. 該当レスバに応募中の pending な応募をすべて 'cancelled' に更新
    -- (応募者の1件制限ロックが解除され、Realtime でバナーも更新される)
    UPDATE public.battle_invite_applications
       SET status = 'cancelled',
           updated_at = now()
     WHERE invite_id = ANY(v_expired_ids)
       AND status = 'pending';

    -- 3. レスバ本体を 'cancelled' に更新
    UPDATE public.battle_invites
       SET status = 'cancelled',
           updated_at = now()
     WHERE id = ANY(v_expired_ids);
  END IF;
END;
$function$;

GRANT ALL ON FUNCTION public.cleanup_expired_resbas() TO anon;
GRANT ALL ON FUNCTION public.cleanup_expired_resbas() TO authenticated;
GRANT ALL ON FUNCTION public.cleanup_expired_resbas() TO service_role;


-- ---------- 2. 各一覧取得関数に自動クリーンアップ呼び出しを追加 ----------

-- (1) 対戦募集一覧 (get_recruit_resbas)
CREATE OR REPLACE FUNCTION public.get_recruit_resbas(p_user_id uuid)
  RETURNS json
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_result json;
BEGIN
  -- 24時間経過のレスバを事前にクリーンアップ
  PERFORM public.cleanup_expired_resbas();

  SELECT COALESCE(json_agg(json_build_object(
      'id', b.id,
      'sender_id', b.sender_id,
      'sender_name', u.name,
      'sender_avatar', u.avatar_url,
      'sender_trophy', u.trophy,
      'attach_type', b.attach_type,
      'attach_id', b.attach_id,
      'target_user_id', b.target_user_id,
      'theme', b.theme,
      'choice1', b.choice1,
      'choice2', b.choice2,
      'status', b.status,
      'responder_id', b.responder_id,
      'battle_room_id', b.battle_room_id,
      'created_at', b.created_at,
      'responded_at', b.responded_at,
      'is_sender', (b.sender_id = p_user_id),
      'is_target', (b.target_user_id = p_user_id),
      'my_application', (
        SELECT a.status FROM battle_invite_applications a
         WHERE a.invite_id = b.id AND a.applicant_id = p_user_id
         ORDER BY a.created_at DESC LIMIT 1
      ),
      'first_application', (
        CASE WHEN b.sender_id = p_user_id THEN (
          SELECT json_build_object(
            'id', a.id,
            'applicant_id', a.applicant_id,
            'applicant_name', au.name,
            'applicant_avatar', au.avatar_url,
            'applicant_trophy', au.trophy
          )
          FROM battle_invite_applications a
          LEFT JOIN users au ON au.id = a.applicant_id
          WHERE a.invite_id = b.id AND a.status = 'pending'
          ORDER BY a.created_at ASC LIMIT 1
        ) ELSE NULL END
      )
    ) ORDER BY b.created_at DESC), '[]'::json) INTO v_result
  FROM battle_invites b
  LEFT JOIN users u ON u.id = b.sender_id
  WHERE b.attach_type = 'recruit' AND b.status = 'pending';

  RETURN v_result;
END;
$function$;

GRANT ALL ON FUNCTION public.get_recruit_resbas(uuid) TO anon;
GRANT ALL ON FUNCTION public.get_recruit_resbas(uuid) TO authenticated;
GRANT ALL ON FUNCTION public.get_recruit_resbas(uuid) TO service_role;


-- (2) オプチャレスバ一覧 (get_open_chat_resbas)
CREATE OR REPLACE FUNCTION public.get_open_chat_resbas(p_room_id uuid, p_user_id uuid)
  RETURNS json
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_result json;
BEGIN
  -- 24時間経過のレスバを事前にクリーンアップ
  PERFORM public.cleanup_expired_resbas();

  SELECT COALESCE(json_agg(t.item), '[]'::json) INTO v_result
  FROM (
    SELECT json_array_elements(public.get_resba('open_chat', m.id, p_user_id)) AS item
    FROM open_chat_messages m
    WHERE m.room_id = p_room_id
  ) t;
  RETURN v_result;
END;
$function$;

GRANT ALL ON FUNCTION public.get_open_chat_resbas(uuid, uuid) TO anon;
GRANT ALL ON FUNCTION public.get_open_chat_resbas(uuid, uuid) TO authenticated;
GRANT ALL ON FUNCTION public.get_open_chat_resbas(uuid, uuid) TO service_role;


-- (3) レスバ状態取得 (get_my_resba_status)
CREATE OR REPLACE FUNCTION public.get_my_resba_status(p_user_id uuid)
  RETURNS json
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_state          text;
  v_pending_sender int := 0;
  v_pending_app    int := 0;
  v_pending_target int := 0;
  v_battle_room_id uuid;
BEGIN
  -- 24時間経過のレスバを事前にクリーンアップ
  PERFORM public.cleanup_expired_resbas();

  -- 1. レスバの待機件数を常に正確にカウント
  SELECT count(*) INTO v_pending_sender FROM battle_invites
   WHERE sender_id = p_user_id AND status = 'pending';

  SELECT count(*) INTO v_pending_target FROM battle_invites
   WHERE target_user_id = p_user_id AND status = 'pending';

  SELECT count(*) INTO v_pending_app FROM battle_invite_applications
   WHERE applicant_id = p_user_id AND status = 'pending';

  -- 2. 本当に進行中の試合があるか厳格にチェック（キャンセル済み・古い放置部屋は除外）
  SELECT id INTO v_battle_room_id FROM rooms_v2
   WHERE (player1_id = p_user_id OR player2_id = p_user_id)
     AND winner IS NULL
     AND player2_id IS NOT NULL
     AND player1_go IS DISTINCT FROM false
     AND player2_go IS DISTINCT FROM false
     AND updated_at >= now() - INTERVAL '5 minutes'
   ORDER BY created_at DESC
   LIMIT 1;

  -- 3. 状態ステータスの決定
  IF v_battle_room_id IS NOT NULL THEN
    v_state := 'battle';
  ELSIF v_pending_sender > 0 THEN
    v_state := 'proposing';
  ELSIF v_pending_app > 0 THEN
    v_state := 'applying';
  ELSIF v_pending_target > 0 THEN
    v_state := 'invited';
  ELSE
    v_state := 'free';
  END IF;

  -- 4. カウントを含めて返却
  RETURN json_build_object(
    'state', v_state,
    'battle_room_id', v_battle_room_id,
    'pending_sender_count', v_pending_sender,
    'pending_application_count', v_pending_app,
    'pending_target_count', v_pending_target
  );
END;
$function$;

GRANT ALL ON FUNCTION public.get_my_resba_status(uuid) TO anon;
GRANT ALL ON FUNCTION public.get_my_resba_status(uuid) TO authenticated;
GRANT ALL ON FUNCTION public.get_my_resba_status(uuid) TO service_role;


-- ---------- 3. pg_cron 定期実行ジョブの登録 (利用可能な場合) ----------
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_extension WHERE extname = 'pg_cron'
  ) OR EXISTS (
    SELECT 1 FROM pg_available_extensions WHERE name = 'pg_cron'
  ) THEN
    BEGIN
      CREATE EXTENSION IF NOT EXISTS pg_cron;
      -- 既存の同名ジョブがあれば解除
      PERFORM cron.unschedule('cleanup_expired_resbas_job');
    EXCEPTION WHEN OTHERS THEN
      -- エラー時はスキップ
    END;

    BEGIN
      PERFORM cron.schedule(
        'cleanup_expired_resbas_job',
        '*/10 * * * *',
        'SELECT public.cleanup_expired_resbas();'
      );
    EXCEPTION WHEN OTHERS THEN
      -- エラー時はスキップ
    END;
  END IF;
END $$;
