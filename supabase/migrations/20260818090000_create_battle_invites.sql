-- ============================================================
-- Migration: create_battle_invites
-- コンテンツ融合型レスバ（対戦招待）基盤
--  ・battle_invites                : レスバ本体（ポスト/返信/DMに添付）
--  ・battle_invite_applications    : ポスト型レスバへの応募（FIFO・一覧表示なし）
--  ・RPC 一式 / RLS / 通知トリガー
--  ・rooms_v2 を再利用してバトル開始（rooms_v3 は使わない）
-- ============================================================

-- ---------- 1. battle_invites ----------
CREATE TABLE public.battle_invites (
  id             uuid        DEFAULT gen_random_uuid() NOT NULL,
  sender_id      uuid        NOT NULL,
  attach_type    text        NOT NULL,
  attach_id      uuid        NOT NULL,
  target_user_id uuid,
  theme          text        NOT NULL,
  choice1        text,
  choice2        text,
  status         text        DEFAULT 'pending' NOT NULL,
  responder_id   uuid,
  battle_room_id uuid,
  created_at     timestamptz DEFAULT now() NOT NULL,
  updated_at     timestamptz DEFAULT now() NOT NULL,
  responded_at   timestamptz
);

ALTER TABLE public.battle_invites
  ADD CONSTRAINT battle_invites_pkey PRIMARY KEY (id);

ALTER TABLE public.battle_invites
  ADD CONSTRAINT battle_invites_sender_id_fkey FOREIGN KEY (sender_id) REFERENCES public.users(id) ON DELETE CASCADE;

ALTER TABLE public.battle_invites
  ADD CONSTRAINT battle_invites_target_user_id_fkey FOREIGN KEY (target_user_id) REFERENCES public.users(id) ON DELETE CASCADE;

ALTER TABLE public.battle_invites
  ADD CONSTRAINT battle_invites_responder_id_fkey FOREIGN KEY (responder_id) REFERENCES public.users(id) ON DELETE CASCADE;

ALTER TABLE public.battle_invites
  ADD CONSTRAINT battle_invites_battle_room_id_fkey FOREIGN KEY (battle_room_id) REFERENCES public.rooms_v2(id) ON DELETE SET NULL;

ALTER TABLE public.battle_invites
  ADD CONSTRAINT battle_invites_attach_type_check CHECK (attach_type IN ('post', 'comment', 'dm'));

ALTER TABLE public.battle_invites
  ADD CONSTRAINT battle_invites_status_check CHECK (status IN ('pending', 'accepted', 'declined', 'cancelled', 'finished'));

CREATE INDEX battle_invites_attach_idx        ON public.battle_invites (attach_type, attach_id);
CREATE INDEX battle_invites_sender_status_idx ON public.battle_invites (sender_id, status);
CREATE INDEX battle_invites_target_status_idx ON public.battle_invites (target_user_id, status);

-- ---------- 2. battle_invite_applications ----------
CREATE TABLE public.battle_invite_applications (
  id           uuid        DEFAULT gen_random_uuid() NOT NULL,
  invite_id    uuid        NOT NULL,
  applicant_id uuid        NOT NULL,
  status       text        DEFAULT 'pending' NOT NULL,
  created_at   timestamptz DEFAULT now() NOT NULL,
  updated_at   timestamptz DEFAULT now() NOT NULL
);

ALTER TABLE public.battle_invite_applications
  ADD CONSTRAINT battle_invite_applications_pkey PRIMARY KEY (id);

ALTER TABLE public.battle_invite_applications
  ADD CONSTRAINT battle_invite_applications_invite_id_fkey FOREIGN KEY (invite_id) REFERENCES public.battle_invites(id) ON DELETE CASCADE;

ALTER TABLE public.battle_invite_applications
  ADD CONSTRAINT battle_invite_applications_applicant_id_fkey FOREIGN KEY (applicant_id) REFERENCES public.users(id) ON DELETE CASCADE;

ALTER TABLE public.battle_invite_applications
  ADD CONSTRAINT battle_invite_applications_status_check CHECK (status IN ('pending', 'accepted', 'rejected', 'cancelled'));

ALTER TABLE public.battle_invite_applications
  ADD CONSTRAINT battle_invite_applications_invite_applicant_key UNIQUE (invite_id, applicant_id);

-- 同時応募は1件のみ（部分ユニーク）
CREATE UNIQUE INDEX battle_invite_applications_one_pending_idx
  ON public.battle_invite_applications (applicant_id)
  WHERE status = 'pending';

CREATE INDEX battle_invite_applications_invite_status_idx
  ON public.battle_invite_applications (invite_id, status, created_at);

CREATE INDEX battle_invite_applications_applicant_status_idx
  ON public.battle_invite_applications (applicant_id, status);

-- ---------- 3. updated_at トリガー ----------
CREATE FUNCTION public.set_battle_invites_updated_at()
  RETURNS trigger
  LANGUAGE plpgsql
  AS $function$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$function$;

CREATE TRIGGER trg_battle_invites_updated_at
  BEFORE UPDATE ON public.battle_invites
  FOR EACH ROW EXECUTE FUNCTION public.set_battle_invites_updated_at();

CREATE TRIGGER trg_battle_invite_applications_updated_at
  BEFORE UPDATE ON public.battle_invite_applications
  FOR EACH ROW EXECUTE FUNCTION public.set_battle_invites_updated_at();

-- ---------- 4. ヘルパー: 対戦中チェック ----------
CREATE FUNCTION public.is_user_in_battle(p_user_id uuid)
  RETURNS boolean
  LANGUAGE sql
  STABLE
  AS $function$
  SELECT EXISTS (
    SELECT 1 FROM rooms_v2
    WHERE (player1_id = p_user_id OR player2_id = p_user_id)
      AND winner IS NULL
  );
$function$;

-- ---------- 5. RPC: 返信コメントにレスバを添付 ----------
CREATE FUNCTION public.attach_resba_to_comment(
  p_sender_id  uuid,
  p_comment_id uuid,
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
  v_comment_user uuid;
  v_parent       uuid;
  v_post_id      uuid;
  v_target       uuid;
  v_invite       json;
BEGIN
  IF public.is_user_in_battle(p_sender_id) THEN
    RETURN json_build_object('success', false, 'error', 'IN_BATTLE');
  END IF;

  SELECT user_id, parent_comment_id, post_id
    INTO v_comment_user, v_parent, v_post_id
    FROM bbs_comments WHERE id = p_comment_id;
  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'COMMENT_NOT_FOUND');
  END IF;

  -- 返信先: 親コメントの投稿者、無ければポスト投稿者
  IF v_parent IS NOT NULL THEN
    SELECT user_id INTO v_target FROM bbs_comments WHERE id = v_parent;
    IF NOT FOUND THEN
      RETURN json_build_object('success', false, 'error', 'PARENT_NOT_FOUND');
    END IF;
  ELSE
    SELECT user_id INTO v_target FROM bbs_posts WHERE id = v_post_id;
    IF NOT FOUND THEN
      RETURN json_build_object('success', false, 'error', 'POST_NOT_FOUND');
    END IF;
  END IF;

  IF v_target = p_sender_id THEN
    RETURN json_build_object('success', false, 'error', 'SELF_INVITE');
  END IF;

  INSERT INTO battle_invites (sender_id, attach_type, attach_id, target_user_id, theme, choice1, choice2)
  VALUES (
    p_sender_id, 'comment', p_comment_id, v_target,
    COALESCE(NULLIF(p_theme, ''), 'レスバ対戦'),
    NULLIF(p_choice1, ''), NULLIF(p_choice2, '')
  )
  RETURNING to_jsonb(battle_invites.*)::text::json INTO v_invite;

  RETURN json_build_object('success', true, 'invite', v_invite);
END;
$function$;

GRANT ALL ON FUNCTION public.attach_resba_to_comment(uuid, uuid, text, text, text) TO anon;
GRANT ALL ON FUNCTION public.attach_resba_to_comment(uuid, uuid, text, text, text) TO authenticated;
GRANT ALL ON FUNCTION public.attach_resba_to_comment(uuid, uuid, text, text, text) TO service_role;

-- ---------- 6. RPC: ポストにレスバを付ける（投稿者のみ・誰でも応募可） ----------
CREATE FUNCTION public.create_post_resba(
  p_sender_id uuid,
  p_post_id   uuid,
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
  v_owner uuid;
  v_invite json;
BEGIN
  IF public.is_user_in_battle(p_sender_id) THEN
    RETURN json_build_object('success', false, 'error', 'IN_BATTLE');
  END IF;

  SELECT user_id INTO v_owner FROM bbs_posts WHERE id = p_post_id;
  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'POST_NOT_FOUND');
  END IF;
  IF v_owner <> p_sender_id THEN
    RETURN json_build_object('success', false, 'error', 'NOT_POST_OWNER');
  END IF;

  INSERT INTO battle_invites (sender_id, attach_type, attach_id, target_user_id, theme, choice1, choice2)
  VALUES (
    p_sender_id, 'post', p_post_id, NULL,
    COALESCE(NULLIF(p_theme, ''), 'レスバ対戦'),
    NULLIF(p_choice1, ''), NULLIF(p_choice2, '')
  )
  RETURNING to_jsonb(battle_invites.*)::text::json INTO v_invite;

  RETURN json_build_object('success', true, 'invite', v_invite);
END;
$function$;

GRANT ALL ON FUNCTION public.create_post_resba(uuid, uuid, text, text, text) TO anon;
GRANT ALL ON FUNCTION public.create_post_resba(uuid, uuid, text, text, text) TO authenticated;
GRANT ALL ON FUNCTION public.create_post_resba(uuid, uuid, text, text, text) TO service_role;

-- ---------- 7. RPC: DMでレスバを送信（相手はルームの相手） ----------
CREATE FUNCTION public.send_dm_resba(
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
  v_room   uuid;
  v_target uuid;
  v_invite json;
BEGIN
  IF public.is_user_in_battle(p_sender_id) THEN
    RETURN json_build_object('success', false, 'error', 'IN_BATTLE');
  END IF;

  SELECT room_id INTO v_room FROM dm_messages WHERE id = p_message_id;
  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'MESSAGE_NOT_FOUND');
  END IF;

  SELECT user_id INTO v_target
    FROM dm_room_members
   WHERE room_id = v_room AND user_id <> p_sender_id
   LIMIT 1;
  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'TARGET_NOT_FOUND');
  END IF;

  INSERT INTO battle_invites (sender_id, attach_type, attach_id, target_user_id, theme, choice1, choice2)
  VALUES (
    p_sender_id, 'dm', p_message_id, v_target,
    COALESCE(NULLIF(p_theme, ''), 'レスバ対戦'),
    NULLIF(p_choice1, ''), NULLIF(p_choice2, '')
  )
  RETURNING to_jsonb(battle_invites.*)::text::json INTO v_invite;

  RETURN json_build_object('success', true, 'invite', v_invite);
END;
$function$;

GRANT ALL ON FUNCTION public.send_dm_resba(uuid, uuid, text, text, text) TO anon;
GRANT ALL ON FUNCTION public.send_dm_resba(uuid, uuid, text, text, text) TO authenticated;
GRANT ALL ON FUNCTION public.send_dm_resba(uuid, uuid, text, text, text) TO service_role;

-- ---------- 8. RPC: 指名型（comment / dm）の承諾・拒否 ----------
CREATE FUNCTION public.respond_resba(
  p_invite_id uuid,
  p_user_id   uuid,
  p_approve   boolean
)
  RETURNS json
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_invite    battle_invites%ROWTYPE;
  v_room_id   uuid;
  v_theme_s   boolean;
BEGIN
  SELECT * INTO v_invite FROM battle_invites WHERE id = p_invite_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'INVITE_NOT_FOUND');
  END IF;
  IF v_invite.status <> 'pending' THEN
    RETURN json_build_object('success', false, 'error', 'INVITE_CLOSED');
  END IF;
  IF v_invite.target_user_id <> p_user_id THEN
    RETURN json_build_object('success', false, 'error', 'NOT_TARGET');
  END IF;

  IF p_approve = TRUE THEN
    IF public.is_user_in_battle(p_user_id) THEN
      RETURN json_build_object('success', false, 'error', 'IN_BATTLE');
    END IF;

    -- rooms_v2 でバトル開始（テーマ・選択肢を引き継ぎ。選択肢未指定時は賛成/反対）
    INSERT INTO rooms_v2 (player1_id, player2_id, current_theme, current_choice1, current_choice2, theme_s, is_matched, is_bbs)
    VALUES (
      v_invite.sender_id, p_user_id,
      COALESCE(NULLIF(v_invite.theme, ''), 'レスバ対戦'),
      COALESCE(NULLIF(v_invite.choice1, ''), '賛成'),
      COALESCE(NULLIF(v_invite.choice2, ''), '反対'),
      TRUE, TRUE, TRUE
    )
    RETURNING id INTO v_room_id;

    UPDATE battle_invites
       SET status = 'accepted', responder_id = p_user_id,
           battle_room_id = v_room_id, responded_at = now(), updated_at = now()
     WHERE id = p_invite_id;

    -- 送信者の他の pending 提案を自動キャンセル（対戦の二重化防止）
    UPDATE battle_invites
       SET status = 'cancelled', updated_at = now()
     WHERE sender_id = v_invite.sender_id AND id <> p_invite_id AND status = 'pending';

    -- 承諾者の保留応募（ポスト型）も自動キャンセル（対戦中の二重応募防止）
    UPDATE battle_invite_applications
       SET status = 'cancelled', updated_at = now()
     WHERE applicant_id = p_user_id AND status = 'pending';

    RETURN json_build_object('success', true, 'room_id', v_room_id);
  ELSE
    UPDATE battle_invites
       SET status = 'declined', responded_at = now(), updated_at = now()
     WHERE id = p_invite_id;
    RETURN json_build_object('success', true);
  END IF;
END;
$function$;

GRANT ALL ON FUNCTION public.respond_resba(uuid, uuid, boolean) TO anon;
GRANT ALL ON FUNCTION public.respond_resba(uuid, uuid, boolean) TO authenticated;
GRANT ALL ON FUNCTION public.respond_resba(uuid, uuid, boolean) TO service_role;

-- ---------- 9. RPC: ポスト型レスバへの応募（⚔️ 応じる） ----------
CREATE FUNCTION public.apply_post_resba(
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
  IF v_invite.attach_type <> 'post' THEN
    RETURN json_build_object('success', false, 'error', 'NOT_POST_TYPE');
  END IF;
  IF v_invite.status <> 'pending' THEN
    RETURN json_build_object('success', false, 'error', 'INVITE_CLOSED');
  END IF;
  IF v_invite.sender_id = p_user_id THEN
    RETURN json_build_object('success', false, 'error', 'SELF_APPLY');
  END IF;
  IF public.is_user_in_battle(p_user_id) THEN
    RETURN json_build_object('success', false, 'error', 'IN_BATTLE');
  END IF;
  IF EXISTS (SELECT 1 FROM battle_invite_applications WHERE applicant_id = p_user_id AND status = 'pending') THEN
    RETURN json_build_object('success', false, 'error', 'ALREADY_APPLYING');
  END IF;

  INSERT INTO battle_invite_applications (invite_id, applicant_id)
  VALUES (p_invite_id, p_user_id);

  RETURN json_build_object('success', true);
END;
$function$;

GRANT ALL ON FUNCTION public.apply_post_resba(uuid, uuid) TO anon;
GRANT ALL ON FUNCTION public.apply_post_resba(uuid, uuid) TO authenticated;
GRANT ALL ON FUNCTION public.apply_post_resba(uuid, uuid) TO service_role;

-- ---------- 10. RPC: ポスト型レスバの承認・拒否（投稿者が1件ずつ処理） ----------
CREATE FUNCTION public.approve_post_resba(
  p_invite_id      uuid,
  p_application_id uuid,
  p_host_id        uuid,
  p_approve        boolean
)
  RETURNS json
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_invite battle_invites%ROWTYPE;
  v_app    battle_invite_applications%ROWTYPE;
  v_room_id uuid;
  v_theme_s boolean;
BEGIN
  SELECT * INTO v_invite FROM battle_invites WHERE id = p_invite_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'INVITE_NOT_FOUND');
  END IF;
  IF v_invite.sender_id <> p_host_id THEN
    RETURN json_build_object('success', false, 'error', 'NOT_HOST');
  END IF;
  IF v_invite.status <> 'pending' THEN
    RETURN json_build_object('success', false, 'error', 'INVITE_CLOSED');
  END IF;

  SELECT * INTO v_app FROM battle_invite_applications
   WHERE id = p_application_id AND invite_id = p_invite_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'APPLICATION_NOT_FOUND');
  END IF;
  IF v_app.status <> 'pending' THEN
    RETURN json_build_object('success', false, 'error', 'APPLICATION_CLOSED');
  END IF;

  IF p_approve = TRUE THEN
    -- rooms_v2 でバトル開始（選択肢未指定時は賛成/反対）
    INSERT INTO rooms_v2 (player1_id, player2_id, current_theme, current_choice1, current_choice2, theme_s, is_matched, is_bbs)
    VALUES (
      v_invite.sender_id, v_app.applicant_id,
      COALESCE(NULLIF(v_invite.theme, ''), 'レスバ対戦'),
      COALESCE(NULLIF(v_invite.choice1, ''), '賛成'),
      COALESCE(NULLIF(v_invite.choice2, ''), '反対'),
      TRUE, TRUE, TRUE
    )
    RETURNING id INTO v_room_id;

    UPDATE battle_invites
       SET status = 'accepted', responder_id = v_app.applicant_id,
           battle_room_id = v_room_id, responded_at = now(), updated_at = now()
     WHERE id = p_invite_id;

    UPDATE battle_invite_applications
       SET status = 'accepted', updated_at = now()
     WHERE id = p_application_id;

    -- 他の応募を自動却下
    UPDATE battle_invite_applications
       SET status = 'rejected', updated_at = now()
     WHERE invite_id = p_invite_id AND id <> p_application_id AND status = 'pending';

    RETURN json_build_object('success', true, 'room_id', v_room_id);
  ELSE
    UPDATE battle_invite_applications
       SET status = 'rejected', updated_at = now()
     WHERE id = p_application_id;
    RETURN json_build_object('success', true);
  END IF;
END;
$function$;

GRANT ALL ON FUNCTION public.approve_post_resba(uuid, uuid, uuid, boolean) TO anon;
GRANT ALL ON FUNCTION public.approve_post_resba(uuid, uuid, uuid, boolean) TO authenticated;
GRANT ALL ON FUNCTION public.approve_post_resba(uuid, uuid, uuid, boolean) TO service_role;

-- ---------- 11. RPC: 送信者のキャンセル ----------
CREATE FUNCTION public.cancel_resba(
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
  UPDATE battle_invites
     SET status = 'cancelled', updated_at = now()
   WHERE id = p_invite_id AND sender_id = p_sender_id AND status = 'pending'
   RETURNING id INTO v_id;

  IF v_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'NOT_FOUND_OR_UNAUTHORIZED');
  END IF;
  RETURN json_build_object('success', true);
END;
$function$;

GRANT ALL ON FUNCTION public.cancel_resba(uuid, uuid) TO anon;
GRANT ALL ON FUNCTION public.cancel_resba(uuid, uuid) TO authenticated;
GRANT ALL ON FUNCTION public.cancel_resba(uuid, uuid) TO service_role;

-- ---------- 11b. RPC: 応募者の取り下げ（ポスト型） ----------
CREATE FUNCTION public.cancel_post_resba_application(
  p_invite_id uuid,
  p_user_id   uuid
)
  RETURNS json
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_id uuid;
BEGIN
  UPDATE battle_invite_applications
     SET status = 'cancelled', updated_at = now()
   WHERE invite_id = p_invite_id AND applicant_id = p_user_id AND status = 'pending'
   RETURNING id INTO v_id;

  IF v_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'NOT_FOUND_OR_UNAUTHORIZED');
  END IF;
  RETURN json_build_object('success', true);
END;
$function$;

GRANT ALL ON FUNCTION public.cancel_post_resba_application(uuid, uuid) TO anon;
GRANT ALL ON FUNCTION public.cancel_post_resba_application(uuid, uuid) TO authenticated;
GRANT ALL ON FUNCTION public.cancel_post_resba_application(uuid, uuid) TO service_role;

-- ---------- 12. RPC: コンテンツに付いたレスバ一覧（+自分の状態） ----------
CREATE FUNCTION public.get_resba(
  p_attach_type text,
  p_attach_id   uuid,
  p_user_id     uuid
)
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
  WHERE b.attach_type = p_attach_type AND b.attach_id = p_attach_id;

  RETURN v_result;
END;
$function$;

GRANT ALL ON FUNCTION public.get_resba(text, uuid, uuid) TO anon;
GRANT ALL ON FUNCTION public.get_resba(text, uuid, uuid) TO authenticated;
GRANT ALL ON FUNCTION public.get_resba(text, uuid, uuid) TO service_role;

-- ---------- 13. RPC: ポスト単位のレスバ一覧（ポスト + そのコメント） ----------
CREATE FUNCTION public.get_post_resbas(
  p_post_id uuid,
  p_user_id uuid
)
  RETURNS json
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_result      json;
  v_comment_id  uuid;
BEGIN
  v_result := public.get_resba('post', p_post_id, p_user_id);
  FOR v_comment_id IN SELECT id FROM bbs_comments WHERE post_id = p_post_id LOOP
    v_result := v_result || public.get_resba('comment', v_comment_id, p_user_id);
  END LOOP;
  RETURN v_result;
END;
$function$;

GRANT ALL ON FUNCTION public.get_post_resbas(uuid, uuid) TO anon;
GRANT ALL ON FUNCTION public.get_post_resbas(uuid, uuid) TO authenticated;
GRANT ALL ON FUNCTION public.get_post_resbas(uuid, uuid) TO service_role;

-- ---------- 13b. RPC: DMルーム単位のレスバ一覧 ----------
CREATE FUNCTION public.get_dm_resbas(
  p_room_id uuid,
  p_user_id uuid
)
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
  FOR v_message_id IN SELECT id FROM dm_messages WHERE room_id = p_room_id LOOP
    v_result := v_result || public.get_resba('dm', v_message_id, p_user_id);
  END LOOP;
  RETURN v_result;
END;
$function$;

GRANT ALL ON FUNCTION public.get_dm_resbas(uuid, uuid) TO anon;
GRANT ALL ON FUNCTION public.get_dm_resbas(uuid, uuid) TO authenticated;
GRANT ALL ON FUNCTION public.get_dm_resbas(uuid, uuid) TO service_role;

-- ---------- 13c. RPC: マイ対戦状態の導出 ----------
CREATE FUNCTION public.get_my_resba_status(p_user_id uuid)
  RETURNS json
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_state     text;
  v_pending_sender int;
  v_pending_app     int;
  v_pending_target  int;
  v_battle_room_id  uuid;
BEGIN
  -- 対戦中（rooms_v2 進行中）が最優先
  SELECT id INTO v_battle_room_id FROM rooms_v2
   WHERE (player1_id = p_user_id OR player2_id = p_user_id) AND winner IS NULL
   LIMIT 1;
  IF v_battle_room_id IS NOT NULL THEN
    RETURN json_build_object('state', 'battle', 'battle_room_id', v_battle_room_id);
  END IF;

  SELECT count(*) INTO v_pending_sender FROM battle_invites
   WHERE sender_id = p_user_id AND status = 'pending';
  SELECT count(*) INTO v_pending_target FROM battle_invites
   WHERE target_user_id = p_user_id AND status = 'pending';
  SELECT count(*) INTO v_pending_app FROM battle_invite_applications
   WHERE applicant_id = p_user_id AND status = 'pending';

  IF v_pending_sender > 0 THEN
    v_state := 'proposing';
  ELSIF v_pending_app > 0 THEN
    v_state := 'applying';
  ELSIF v_pending_target > 0 THEN
    v_state := 'invited';
  ELSE
    v_state := 'free';
  END IF;

  RETURN json_build_object(
    'state', v_state,
    'pending_sender_count', v_pending_sender,
    'pending_application_count', v_pending_app,
    'pending_target_count', v_pending_target
  );
END;
$function$;

GRANT ALL ON FUNCTION public.get_my_resba_status(uuid) TO anon;
GRANT ALL ON FUNCTION public.get_my_resba_status(uuid) TO authenticated;
GRANT ALL ON FUNCTION public.get_my_resba_status(uuid) TO service_role;

-- ---------- 14. RLS ----------
ALTER TABLE public.battle_invites ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.battle_invite_applications ENABLE ROW LEVEL SECURITY;

-- 読み取り: post/comment は全員、dm は当事者2名のみ
CREATE POLICY "battle_invites_select"
  ON public.battle_invites FOR SELECT
  USING (
    attach_type IN ('post', 'comment')
    OR auth.uid() IN (sender_id, target_user_id)
  );

-- 書き込みは RPC（SECURITY DEFINER）経由のみ（INSERT/UPDATE/DELETE ポリシーなし = 拒否）

-- Realtime 購読用に publication へ登録
ALTER PUBLICATION supabase_realtime ADD TABLE public.battle_invites, public.battle_invite_applications;

-- 応募の読み取り: 応募者本人 or 募集ホスト
CREATE POLICY "battle_invite_applications_select"
  ON public.battle_invite_applications FOR SELECT
  USING (
    applicant_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM battle_invites b
      WHERE b.id = invite_id AND b.sender_id = auth.uid()
    )
  );

GRANT ALL ON public.battle_invites TO anon;
GRANT ALL ON public.battle_invites TO authenticated;
GRANT ALL ON public.battle_invites TO service_role;
GRANT ALL ON public.battle_invite_applications TO anon;
GRANT ALL ON public.battle_invite_applications TO authenticated;
GRANT ALL ON public.battle_invite_applications TO service_role;

-- ---------- 15. バトル終了でレスバを finished に ----------
CREATE FUNCTION public.finish_resba_on_battle_end()
  RETURNS trigger
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
BEGIN
  IF NEW.winner IS NOT NULL AND OLD.winner IS NULL THEN
    UPDATE battle_invites
       SET status = 'finished', updated_at = now()
     WHERE battle_room_id = NEW.id AND status = 'accepted';
  END IF;
  RETURN NEW;
END;
$function$;

CREATE TRIGGER trg_finish_resba_on_battle_end
  AFTER UPDATE OF winner ON public.rooms_v2
  FOR EACH ROW EXECUTE FUNCTION public.finish_resba_on_battle_end();

-- ---------- 16. 通知（in-app + FCM） ----------
ALTER TABLE public.notifications
  DROP CONSTRAINT notifications_type_check;

ALTER TABLE public.notifications
  ADD CONSTRAINT notifications_type_check CHECK (
    type = ANY (ARRAY[
      'like_post'::text, 'like_comment'::text, 'follow'::text,
      'reply_comment'::text, 'comment'::text,
      'resba_invite'::text, 'resba_accepted'::text, 'resba_declined'::text
    ])
  );

-- レスバが届いた（指名型）
CREATE FUNCTION public.notify_resba_invite()
  RETURNS trigger
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_actor_name text;
  v_post_id    uuid;
  v_comment_id uuid;
BEGIN
  IF NEW.target_user_id IS NOT NULL AND NEW.target_user_id <> NEW.sender_id THEN
    IF NEW.attach_type = 'post' THEN
      v_post_id := NEW.attach_id;
    ELSIF NEW.attach_type = 'comment' THEN
      v_comment_id := NEW.attach_id;
    END IF;

    INSERT INTO public.notifications (user_id, actor_id, type, post_id, comment_id, count, actor_ids)
    VALUES (NEW.target_user_id, NEW.sender_id, 'resba_invite', v_post_id, v_comment_id, 1, ARRAY[NEW.sender_id]);

    SELECT name INTO v_actor_name FROM public.users WHERE id = NEW.sender_id;
    PERFORM net.http_post(
      url := 'https://ljgvqdcailabzuutaeha.supabase.co/functions/v1/notify_trigger',
      headers := jsonb_build_object('Content-Type', 'application/json', 'x-notify-secret', '4a5d3df69e9baa4456e120a8b1fc45c924730ded80c03fe7b3872b2693847d73'),
      body := jsonb_build_object('user_id', NEW.target_user_id, 'type', 'resba_invite', 'actor_name', v_actor_name)
    );
  END IF;
  RETURN NEW;
END;
$function$;

CREATE TRIGGER trg_notify_resba_invite
  AFTER INSERT ON public.battle_invites
  FOR EACH ROW EXECUTE FUNCTION public.notify_resba_invite();

-- 承諾（成立）
CREATE FUNCTION public.notify_resba_accepted()
  RETURNS trigger
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_actor_name text;
BEGIN
  IF NEW.status = 'accepted' AND OLD.status = 'pending' AND NEW.responder_id IS NOT NULL THEN
    INSERT INTO public.notifications (user_id, actor_id, type, count, actor_ids)
    VALUES (NEW.sender_id, NEW.responder_id, 'resba_accepted', 1, ARRAY[NEW.responder_id]);

    SELECT name INTO v_actor_name FROM public.users WHERE id = NEW.responder_id;
    PERFORM net.http_post(
      url := 'https://ljgvqdcailabzuutaeha.supabase.co/functions/v1/notify_trigger',
      headers := jsonb_build_object('Content-Type', 'application/json', 'x-notify-secret', '4a5d3df69e9baa4456e120a8b1fc45c924730ded80c03fe7b3872b2693847d73'),
      body := jsonb_build_object('user_id', NEW.sender_id, 'type', 'resba_accepted', 'actor_name', v_actor_name)
    );
  END IF;
  RETURN NEW;
END;
$function$;

CREATE TRIGGER trg_notify_resba_accepted
  AFTER UPDATE OF status ON public.battle_invites
  FOR EACH ROW EXECUTE FUNCTION public.notify_resba_accepted();

-- 拒否
CREATE FUNCTION public.notify_resba_declined()
  RETURNS trigger
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_actor_id   uuid;
  v_actor_name text;
BEGIN
  IF NEW.status = 'declined' AND OLD.status = 'pending' THEN
    v_actor_id := COALESCE(NEW.responder_id, NEW.target_user_id);
    IF v_actor_id IS NOT NULL AND v_actor_id <> NEW.sender_id THEN
      INSERT INTO public.notifications (user_id, actor_id, type, count, actor_ids)
      VALUES (NEW.sender_id, v_actor_id, 'resba_declined', 1, ARRAY[v_actor_id]);

      SELECT name INTO v_actor_name FROM public.users WHERE id = v_actor_id;
      PERFORM net.http_post(
        url := 'https://ljgvqdcailabzuutaeha.supabase.co/functions/v1/notify_trigger',
        headers := jsonb_build_object('Content-Type', 'application/json', 'x-notify-secret', '4a5d3df69e9baa4456e120a8b1fc45c924730ded80c03fe7b3872b2693847d73'),
        body := jsonb_build_object('user_id', NEW.sender_id, 'type', 'resba_declined', 'actor_name', v_actor_name)
      );
    END IF;
  END IF;
  RETURN NEW;
END;
$function$;

CREATE TRIGGER trg_notify_resba_declined
  AFTER UPDATE OF status ON public.battle_invites
  FOR EACH ROW EXECUTE FUNCTION public.notify_resba_declined();

-- ---------- 17. 掲示板クエリにレスバ有無を追加 ----------
DROP FUNCTION IF EXISTS public.get_bbs_posts_with_status(uuid, integer);

CREATE FUNCTION public.get_bbs_posts_with_status (
  p_user_id uuid,
  p_limit   integer DEFAULT 50
)
  RETURNS TABLE (
    id             uuid,
    user_id        uuid,
    content        text,
    created_at     timestamp with time zone,
    likes_count    integer,
    replies_count  integer,
    image_urls     text[],
    users          json,
    is_liked_by_me boolean,
    has_resba      boolean
  )
  LANGUAGE plpgsql
  AS $function$
BEGIN
  RETURN QUERY
  SELECT
    p.id,
    p.user_id,
    p.content,
    p.created_at,
    p.likes_count,
    p.replies_count,
    p.image_urls,
    row_to_json(u) AS users,
    EXISTS(SELECT 1 FROM bbs_likes l WHERE l.post_id = p.id AND l.user_id = p_user_id) AS is_liked_by_me,
    EXISTS(SELECT 1 FROM battle_invites b
            WHERE b.attach_type = 'post' AND b.attach_id = p.id
              AND b.status IN ('pending', 'accepted')) AS has_resba
  FROM bbs_posts p
  LEFT JOIN users u ON u.id = p.user_id
  ORDER BY p.created_at DESC
  LIMIT p_limit;
END;
$function$;

GRANT ALL ON FUNCTION public.get_bbs_posts_with_status(uuid, integer) TO anon;
GRANT ALL ON FUNCTION public.get_bbs_posts_with_status(uuid, integer) TO authenticated;
GRANT ALL ON FUNCTION public.get_bbs_posts_with_status(uuid, integer) TO service_role;

DROP FUNCTION IF EXISTS public.get_bbs_comments_with_status(uuid, uuid);

CREATE FUNCTION public.get_bbs_comments_with_status (
  p_post_id uuid,
  p_user_id uuid
)
  RETURNS TABLE (
    id                uuid,
    post_id           uuid,
    user_id           uuid,
    parent_comment_id uuid,
    content           text,
    created_at        timestamp with time zone,
    likes_count       integer,
    image_url         text,
    users             json,
    is_liked_by_me    boolean,
    has_resba         boolean
  )
  LANGUAGE plpgsql
  AS $function$
BEGIN
  RETURN QUERY
  SELECT
    c.id,
    c.post_id,
    c.user_id,
    c.parent_comment_id,
    c.content,
    c.created_at,
    c.likes_count,
    c.image_url,
    row_to_json(u) AS users,
    EXISTS(SELECT 1 FROM bbs_comment_likes cl WHERE cl.comment_id = c.id AND cl.user_id = p_user_id) AS is_liked_by_me,
    EXISTS(SELECT 1 FROM battle_invites b
            WHERE b.attach_type = 'comment' AND b.attach_id = c.id
              AND b.status IN ('pending', 'accepted')) AS has_resba
  FROM bbs_comments c
  LEFT JOIN users u ON u.id = c.user_id
  WHERE c.post_id = p_post_id
  ORDER BY c.created_at ASC;
END;
$function$;

GRANT ALL ON FUNCTION public.get_bbs_comments_with_status(uuid, uuid) TO anon;
GRANT ALL ON FUNCTION public.get_bbs_comments_with_status(uuid, uuid) TO authenticated;
GRANT ALL ON FUNCTION public.get_bbs_comments_with_status(uuid, uuid) TO service_role;
