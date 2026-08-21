-- ============================================================
-- Migration: resba_all_recruitment
-- DM / オープンチャット / 対戦募集 のレスバを、ポスト・コメントと
-- 同じ「募集型(応募制)」に統一する
--
-- 変更内容:
--  1. attach_type に 'open_chat' / 'recruit' を追加
--  2. attach_id を nullable に(対戦募集は添付先なし)
--  3. apply_post_resba を全型で応募可能に
--  4. send_dm_resba を指名型 → 募集型(target NULL)に変更
--  5. create_open_chat_resba / create_recruit_resba を新設
--  6. get_open_chat_resbas / get_recruit_resbas を新設
--  7. battle_invites の SELECT RLS を open_chat / recruit にも拡張
-- ============================================================

-- ---------- 1. attach_type 拡張 ----------
ALTER TABLE public.battle_invites
  DROP CONSTRAINT battle_invites_attach_type_check;
ALTER TABLE public.battle_invites
  ADD CONSTRAINT battle_invites_attach_type_check
  CHECK (attach_type IN ('post', 'comment', 'dm', 'open_chat', 'recruit'));

-- ---------- 2. attach_id nullable(対戦募集は添付先なし) ----------
ALTER TABLE public.battle_invites
  ALTER COLUMN attach_id DROP NOT NULL;

-- ---------- 3. battle_invites の SELECT RLS 拡張 ----------
-- post / comment に加えて open_chat / recruit も全員閲覧可能
DROP POLICY IF EXISTS "battle_invites_select" ON public.battle_invites;
CREATE POLICY "battle_invites_select"
  ON public.battle_invites FOR SELECT
  USING (
    attach_type IN ('post', 'comment', 'open_chat', 'recruit')
    OR auth.uid() IN (sender_id, target_user_id)
  );

-- ---------- 4. apply_post_resba: 全型で応募可能に ----------
CREATE OR REPLACE FUNCTION public.apply_post_resba(
  p_invite_id uuid,
  p_user_id   uuid
)
  RETURNS json
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_invite battle_invites%ROWTYPE;
BEGIN
  SELECT * INTO v_invite FROM battle_invites WHERE id = p_invite_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'INVITE_NOT_FOUND');
  END IF;
  IF v_invite.attach_type NOT IN ('post', 'comment', 'dm', 'open_chat', 'recruit') THEN
    RETURN json_build_object('success', false, 'error', 'NOT_POST_TYPE');
  END IF;
  IF v_invite.status <> 'pending' THEN
    RETURN json_build_object('success', false, 'error', 'INVITE_CLOSED');
  END IF;
  IF v_invite.sender_id = p_user_id THEN
    RETURN json_build_object('success', false, 'error', 'SELF_APPLY');
  END IF;
  -- ★ ブロック判定(モデレーション対応)
  IF public.is_user_blocked(v_invite.sender_id, p_user_id)
     OR public.is_user_blocked(p_user_id, v_invite.sender_id) THEN
    RETURN json_build_object('success', false, 'error', 'BLOCKED');
  END IF;
  IF public.is_user_in_battle(p_user_id) THEN
    RETURN json_build_object('success', false, 'error', 'IN_BATTLE');
  END IF;
  IF EXISTS (SELECT 1 FROM battle_invite_applications WHERE applicant_id = p_user_id AND status = 'pending') THEN
    RETURN json_build_object('success', false, 'error', 'ALREADY_APPLYING');
  END IF;

  -- 再応募対応: 取り下げ(cancelled)・拒否(rejected)済みの行は pending に戻す
  INSERT INTO battle_invite_applications (invite_id, applicant_id)
  VALUES (p_invite_id, p_user_id)
  ON CONFLICT (invite_id, applicant_id)
  DO UPDATE SET status = 'pending', created_at = now(), updated_at = now();

  RETURN json_build_object('success', true);
END;
$function$;

-- ---------- 5. send_dm_resba: 指名型 → 募集型 ----------
-- 試合中の試合発生を防ぐため、DMレスバも「応募制」にする(target NULL)
CREATE OR REPLACE FUNCTION public.send_dm_resba(
  p_sender_id  uuid,
  p_message_id uuid,
  p_theme      text,
  p_choice1    text,
  p_choice2    text
)
  RETURNS json
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_msg_user uuid;
  v_invite   json;
BEGIN
  IF public.is_user_in_battle(p_sender_id) THEN
    RETURN json_build_object('success', false, 'error', 'IN_BATTLE');
  END IF;

  SELECT sender_id INTO v_msg_user FROM dm_messages WHERE id = p_message_id;
  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'MESSAGE_NOT_FOUND');
  END IF;
  IF v_msg_user <> p_sender_id THEN
    RETURN json_build_object('success', false, 'error', 'NOT_MESSAGE_OWNER');
  END IF;

  INSERT INTO battle_invites (sender_id, attach_type, attach_id, target_user_id, theme, choice1, choice2)
  VALUES (
    p_sender_id, 'dm', p_message_id, NULL,
    COALESCE(NULLIF(p_theme, ''), 'レスバ対戦'),
    NULLIF(p_choice1, ''), NULLIF(p_choice2, '')
  )
  RETURNING to_jsonb(battle_invites.*)::text::json INTO v_invite;

  RETURN json_build_object('success', true, 'invite', v_invite);
END;
$function$;

-- ---------- 6. create_open_chat_resba: オープンチャットの募集型レスバ ----------
CREATE OR REPLACE FUNCTION public.create_open_chat_resba(
  p_sender_id  uuid,
  p_message_id uuid,
  p_theme      text,
  p_choice1    text,
  p_choice2    text
)
  RETURNS json
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_msg_user uuid;
  v_invite   json;
BEGIN
  IF public.is_user_in_battle(p_sender_id) THEN
    RETURN json_build_object('success', false, 'error', 'IN_BATTLE');
  END IF;

  SELECT user_id INTO v_msg_user FROM open_chat_messages WHERE id = p_message_id;
  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'MESSAGE_NOT_FOUND');
  END IF;
  IF v_msg_user <> p_sender_id THEN
    RETURN json_build_object('success', false, 'error', 'NOT_MESSAGE_OWNER');
  END IF;

  INSERT INTO battle_invites (sender_id, attach_type, attach_id, target_user_id, theme, choice1, choice2)
  VALUES (
    p_sender_id, 'open_chat', p_message_id, NULL,
    COALESCE(NULLIF(p_theme, ''), 'レスバ対戦'),
    NULLIF(p_choice1, ''), NULLIF(p_choice2, '')
  )
  RETURNING to_jsonb(battle_invites.*)::text::json INTO v_invite;

  RETURN json_build_object('success', true, 'invite', v_invite);
END;
$function$;

GRANT ALL ON FUNCTION public.create_open_chat_resba(uuid, uuid, text, text, text) TO anon;
GRANT ALL ON FUNCTION public.create_open_chat_resba(uuid, uuid, text, text, text) TO authenticated;
GRANT ALL ON FUNCTION public.create_open_chat_resba(uuid, uuid, text, text, text) TO service_role;

-- ---------- 7. create_recruit_resba: 対戦募集(添付なしの募集型レスバ) ----------
CREATE OR REPLACE FUNCTION public.create_recruit_resba(
  p_sender_id uuid,
  p_theme     text,
  p_choice1   text,
  p_choice2   text
)
  RETURNS json
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_invite json;
BEGIN
  IF public.is_user_in_battle(p_sender_id) THEN
    RETURN json_build_object('success', false, 'error', 'IN_BATTLE');
  END IF;

  INSERT INTO battle_invites (sender_id, attach_type, attach_id, target_user_id, theme, choice1, choice2)
  VALUES (
    p_sender_id, 'recruit', NULL, NULL,
    COALESCE(NULLIF(p_theme, ''), 'レスバ対戦'),
    NULLIF(p_choice1, ''), NULLIF(p_choice2, '')
  )
  RETURNING to_jsonb(battle_invites.*)::text::json INTO v_invite;

  RETURN json_build_object('success', true, 'invite', v_invite);
END;
$function$;

GRANT ALL ON FUNCTION public.create_recruit_resba(uuid, text, text, text) TO anon;
GRANT ALL ON FUNCTION public.create_recruit_resba(uuid, text, text, text) TO authenticated;
GRANT ALL ON FUNCTION public.create_recruit_resba(uuid, text, text, text) TO service_role;

-- ---------- 8. get_open_chat_resbas: オプチャルーム単位のレスバ一覧 ----------
CREATE OR REPLACE FUNCTION public.get_open_chat_resbas(p_room_id uuid, p_user_id uuid)
  RETURNS json
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_result     json;
  v_message_id uuid;
BEGIN
  v_result := '[]'::json;
  FOR v_message_id IN SELECT id FROM open_chat_messages WHERE room_id = p_room_id LOOP
    v_result := v_result || public.get_resba('open_chat', v_message_id, p_user_id);
  END LOOP;
  RETURN v_result;
END;
$function$;

GRANT ALL ON FUNCTION public.get_open_chat_resbas(uuid, uuid) TO anon;
GRANT ALL ON FUNCTION public.get_open_chat_resbas(uuid, uuid) TO authenticated;
GRANT ALL ON FUNCTION public.get_open_chat_resbas(uuid, uuid) TO service_role;

-- ---------- 9. get_recruit_resbas: 募集中の対戦募集一覧 ----------
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

-- ---------- 10. ホスト応募キューを全型対応に ----------
-- (旧実装は post / comment のみ。DM / オプチャ / 対戦募集の応募も
--   ホストの「応募キュー」ダイアログに表示されるようにする)
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
    AND b.attach_type IN ('post', 'comment', 'dm', 'open_chat', 'recruit');

  RETURN v_result;
END;
$function$;

GRANT ALL ON FUNCTION public.get_my_pending_host_applications(uuid) TO anon;
GRANT ALL ON FUNCTION public.get_my_pending_host_applications(uuid) TO authenticated;
GRANT ALL ON FUNCTION public.get_my_pending_host_applications(uuid) TO service_role;
