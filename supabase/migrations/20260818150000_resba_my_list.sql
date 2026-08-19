-- ============================================================
-- Migration: resba_my_list
-- マイレスバ（自分が送信したレスバの一覧・管理）用RPC
--  ・get_my_sent_resbas : 自分が送信した全レスバ（場所・状態・応募数・battle_room_id）
--  ・delete_resba       : 完全削除（自分が送信した・対戦中以外のみ）
-- ============================================================

-- ---------- 1. 自分の送信レスバ一覧 ----------
CREATE OR REPLACE FUNCTION public.get_my_sent_resbas(p_user_id uuid)
  RETURNS json
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_result json;
BEGIN
  SELECT COALESCE(json_agg(json_build_object(
      'id', b.id,
      'sender_id', b.sender_id,
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
      'is_sender', true,
      'application_count', (
        SELECT count(*) FROM battle_invite_applications a
         WHERE a.invite_id = b.id AND a.status = 'pending'
      ),
      'first_application', (
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
      )
    ) ORDER BY b.created_at DESC), '[]'::json) INTO v_result
  FROM battle_invites b
  WHERE b.sender_id = p_user_id;
  RETURN v_result;
END;
$function$;

GRANT ALL ON FUNCTION public.get_my_sent_resbas(uuid) TO anon;
GRANT ALL ON FUNCTION public.get_my_sent_resbas(uuid) TO authenticated;
GRANT ALL ON FUNCTION public.get_my_sent_resbas(uuid) TO service_role;

-- ---------- 2. レスバの完全削除（自分が送信・対戦中以外のみ） ----------
CREATE OR REPLACE FUNCTION public.delete_resba(
  p_invite_id uuid,
  p_sender_id uuid
)
  RETURNS json
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_id uuid;
BEGIN
  DELETE FROM battle_invites
   WHERE id = p_invite_id
     AND sender_id = p_sender_id
     AND status <> 'accepted'   -- 対戦中（accepted）は削除不可
   RETURNING id INTO v_id;

  IF v_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'NOT_FOUND_OR_UNAUTHORIZED');
  END IF;
  RETURN json_build_object('success', true);
END;
$function$;

GRANT ALL ON FUNCTION public.delete_resba(uuid, uuid) TO anon;
GRANT ALL ON FUNCTION public.delete_resba(uuid, uuid) TO authenticated;
GRANT ALL ON FUNCTION public.delete_resba(uuid, uuid) TO service_role;
