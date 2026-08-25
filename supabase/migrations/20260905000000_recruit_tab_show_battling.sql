-- ============================================================
-- Migration: recruit_tab_show_battling
-- 対戦募集タブ: 対戦中(accepted)の募集も一覧に残して観戦できるようにする
--
-- 従来: status = 'pending'（募集中）のみ表示
--   → 対戦成立と同時にカードが一覧から消え、ライブ観戦の導線がなくなる
-- 変更: status IN ('pending', 'accepted') を表示
--   → 対戦中のカードは「👁 観戦する」でライブ観戦できる（掲示板のレスバと同じ仕様）
--   → 試合終了(finished)になると一覧から消える（観戦ログはマイレスバ一覧・掲示板から閲覧可）
-- ============================================================

CREATE OR REPLACE FUNCTION public.get_recruit_resbas(p_user_id uuid)
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
      'sender_name', u.name,
      'sender_avatar', u.avatar_url,
      'sender_trophy', u.trophy,
      'attach_type', b.attach_type,
      'attach_id', b.attach_id,
      'theme', b.theme,
      'choice1', b.choice1,
      'choice2', b.choice2,
      'status', b.status,
      'responder_id', b.responder_id,
      'battle_room_id', b.battle_room_id,
      'created_at', b.created_at,
      'responded_at', b.responded_at,
      'is_sender', (b.sender_id = p_user_id),
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
  WHERE b.attach_type = 'recruit' AND b.status IN ('pending', 'accepted');

  RETURN v_result;
END;
$function$;

GRANT ALL ON FUNCTION public.get_recruit_resbas(uuid) TO anon;
GRANT ALL ON FUNCTION public.get_recruit_resbas(uuid) TO authenticated;
GRANT ALL ON FUNCTION public.get_recruit_resbas(uuid) TO service_role;