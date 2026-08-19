-- ============================================================
-- Migration: resba_host_application_queue
-- ホスト側の「応募キュー」取得用RPC
--  ・自分の pending レスバ（ポスト/返信）への「保留中の応募」を
--    古い順（created_at ASC）で全件返す
--  ・応募が複数溜まっても、1件ずつ古いものから承認/拒否できるようにする
-- ============================================================

CREATE OR REPLACE FUNCTION public.get_my_pending_host_applications(p_user_id uuid)
  RETURNS json
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_result json;
BEGIN
  SELECT COALESCE(json_agg(json_build_object(
      'application_id', a.id,
      'invite_id',      b.id,
      'theme',          b.theme,
      'choice1',        b.choice1,
      'choice2',        b.choice2,
      'attach_type',    b.attach_type,
      'attach_id',      b.attach_id,
      'applicant_id',   a.applicant_id,
      'applicant_name', au.name,
      'applicant_avatar', au.avatar_url,
      'applicant_trophy', au.trophy,
      'created_at',     a.created_at
    ) ORDER BY a.created_at ASC), '[]'::json) INTO v_result
  FROM battle_invite_applications a
  JOIN battle_invites b ON b.id = a.invite_id
  LEFT JOIN users au ON au.id = a.applicant_id
  WHERE b.sender_id = p_user_id
    AND b.status = 'pending'
    AND a.status = 'pending'
    AND b.attach_type IN ('post', 'comment');

  RETURN v_result;
END;
$function$;

GRANT ALL ON FUNCTION public.get_my_pending_host_applications(uuid) TO anon;
GRANT ALL ON FUNCTION public.get_my_pending_host_applications(uuid) TO authenticated;
GRANT ALL ON FUNCTION public.get_my_pending_host_applications(uuid) TO service_role;
