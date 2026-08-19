-- ============================================================
-- Migration: resba_apply_flow
-- 応募フローUXの新設計に必要なRPC
--  ・get_my_pending_application : 自分が応募中の情報（レスバ・ホスト名・テーマ）を返す
--     ※応募中バナーの表示・入れ替え確認に使用
-- ============================================================

CREATE OR REPLACE FUNCTION public.get_my_pending_application(p_user_id uuid)
  RETURNS json
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_result json;
BEGIN
  SELECT json_build_object(
    'application_id', a.id,
    'invite_id', a.invite_id,
    'theme', b.theme,
    'choice1', b.choice1,
    'choice2', b.choice2,
    'host_name', u.name,
    'host_avatar', u.avatar_url,
    'attach_type', b.attach_type,
    'attach_id', b.attach_id,
    'status', a.status,
    'created_at', a.created_at
  ) INTO v_result
  FROM battle_invite_applications a
  JOIN battle_invites b ON b.id = a.invite_id
  JOIN users u ON u.id = b.sender_id
  WHERE a.applicant_id = p_user_id AND a.status = 'pending'
  ORDER BY a.created_at DESC
  LIMIT 1;

  RETURN v_result;
END;
$function$;

GRANT ALL ON FUNCTION public.get_my_pending_application(uuid) TO anon;
GRANT ALL ON FUNCTION public.get_my_pending_application(uuid) TO authenticated;
GRANT ALL ON FUNCTION public.get_my_pending_application(uuid) TO service_role;
