-- ==============================================================================
-- マイグレーション: クラブ管理人・副管理人ロールシステム (v2 修正版)
-- ------------------------------------------------------------------------------
-- v1 からの修正:
--   * owner_id カラム削除の前に、依存する RLS ポリシーをすべて DROP する順序に変更
--     (v1 は DROP POLICY をカラム削除より後に置いていたため 2BP01 で失敗)
--   * "送信者または管理者はメッセージを論理削除可能" (open_chat_messages) の
--     owner_id 参照を members.role IN ('owner','admin') に置き換えて再作成
--   * delete_open_chat_message RPC を owner_id 参照から role ベースに修正
--   * complete_data_transfer_v2 の owner_id 更新を削除 (members 置換で引き継ぐ)
-- 全ステップ冪等 (IF EXISTS / IF NOT EXISTS) のため、v1 を途中まで実行済みでも
-- そのまま再実行できます。
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. CHECK制約の変更 (admin/member → owner/admin/member)
-- ------------------------------------------------------------------------------
ALTER TABLE public.open_chat_members
  DROP CONSTRAINT IF EXISTS open_chat_members_role_check;

ALTER TABLE public.open_chat_members
  ADD CONSTRAINT open_chat_members_role_check
  CHECK (role IN ('owner', 'admin', 'member'));

-- ------------------------------------------------------------------------------
-- 2. 既存オーナー (open_chat_rooms.owner_id 参照) を role='owner' に変換
--    ※ owner_id カラムを削除する前に必ず実行すること
-- ------------------------------------------------------------------------------
UPDATE public.open_chat_members m
SET role = 'owner'
FROM public.open_chat_rooms r
WHERE m.room_id = r.id
  AND m.user_id = r.owner_id
  AND m.role = 'admin';

-- ------------------------------------------------------------------------------
-- 3. owner_id に依存する RLS ポリシーを DROP (カラム削除より先!)
-- ------------------------------------------------------------------------------
DROP POLICY IF EXISTS "ルーム管理者は更新可能" ON public.open_chat_rooms;
DROP POLICY IF EXISTS "ルーム管理者は削除可能" ON public.open_chat_rooms;
DROP POLICY IF EXISTS "送信者または管理者はメッセージを論理削除可能" ON public.open_chat_messages;
DROP POLICY IF EXISTS "管理者は再参加禁止リストを参照可能" ON public.open_chat_banned_users;
DROP POLICY IF EXISTS "管理者は再参加禁止リストを操作可能" ON public.open_chat_banned_users;

-- ------------------------------------------------------------------------------
-- 4. open_chat_rooms.owner_id カラムの廃止
-- ------------------------------------------------------------------------------
ALTER TABLE public.open_chat_rooms
  DROP CONSTRAINT IF EXISTS open_chat_rooms_owner_id_fkey;

ALTER TABLE public.open_chat_rooms
  DROP COLUMN IF EXISTS owner_id;

-- ------------------------------------------------------------------------------
-- 5. 各ルームにオーナー1名のみを保証する UNIQUE 部分インデックス
-- ------------------------------------------------------------------------------
CREATE UNIQUE INDEX IF NOT EXISTS idx_open_chat_one_owner_per_room
  ON public.open_chat_members (room_id)
  WHERE role = 'owner';

-- ------------------------------------------------------------------------------
-- 6. RLS ポリシーの再作成 (members.role ベース)
-- ------------------------------------------------------------------------------

-- 6-1. open_chat_rooms: 更新・削除はオーナー(role='owner')のみ
CREATE POLICY "ルーム管理者は更新可能" ON public.open_chat_rooms
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM public.open_chat_members
      WHERE room_id = open_chat_rooms.id
        AND user_id = auth.uid()
        AND role = 'owner'
    )
  );

CREATE POLICY "ルーム管理者は削除可能" ON public.open_chat_rooms
  FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM public.open_chat_members
      WHERE room_id = open_chat_rooms.id
        AND user_id = auth.uid()
        AND role = 'owner'
    )
  );

-- 6-2. open_chat_messages: 論理削除は送信者本人 or オーナー/副管理人 (owner/admin)
CREATE POLICY "送信者または管理者はメッセージを論理削除可能" ON public.open_chat_messages
  FOR UPDATE USING (
    auth.uid() = user_id
    OR EXISTS (
      SELECT 1 FROM public.open_chat_members m
      WHERE m.room_id = open_chat_messages.room_id
        AND m.user_id = auth.uid()
        AND m.role IN ('owner', 'admin')
    )
  );

-- 6-3. open_chat_banned_users: 閲覧・操作はオーナー/副管理人 (owner/admin)
CREATE POLICY "管理者は再参加禁止リストを参照可能"
  ON public.open_chat_banned_users
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.open_chat_members
      WHERE room_id = open_chat_banned_users.room_id
        AND user_id = auth.uid()
        AND role IN ('owner', 'admin')
    )
  );

CREATE POLICY "管理者は再参加禁止リストを操作可能"
  ON public.open_chat_banned_users
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.open_chat_members
      WHERE room_id = open_chat_banned_users.room_id
        AND user_id = auth.uid()
        AND role IN ('owner', 'admin')
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.open_chat_members
      WHERE room_id = open_chat_banned_users.room_id
        AND user_id = auth.uid()
        AND role IN ('owner', 'admin')
    )
  );

-- ==============================================================================
-- 7. create_open_chat_room: owner_id 廃止 + 作成者を role='owner' で登録
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.create_open_chat_room (
  p_name           text,
  p_description    text,
  p_icon_url       text,
  p_background_url text DEFAULT NULL::text,
  p_password       text DEFAULT NULL::text,
  p_tags           text[] DEFAULT '{}'::text[]
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  AS $function$
DECLARE
    v_room_id UUID;
    v_user_id UUID;
BEGIN
    -- 現在のユーザーIDを取得
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', '認証されていません');
    END IF;

    -- ルームの作成 (owner_id は廃止)
    INSERT INTO open_chat_rooms (name, description, icon_url, background_url, password, tags)
    VALUES (p_name, p_description, p_icon_url, p_background_url, p_password, COALESCE(p_tags, '{}'::text[]))
    RETURNING id INTO v_room_id;

    -- 作成者を管理人 (owner) としてメンバーに追加
    INSERT INTO open_chat_members (room_id, user_id, role)
    VALUES (v_room_id, v_user_id, 'owner');

    RETURN jsonb_build_object('success', true, 'room_id', v_room_id);
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$function$;

-- ==============================================================================
-- 8. get_open_chat_rooms_with_status: owner_id 列を廃止 (戻り値の型が変わるため DROP して再作成)
-- ==============================================================================
DROP FUNCTION IF EXISTS public.get_open_chat_rooms_with_status(text);

CREATE OR REPLACE FUNCTION public.get_open_chat_rooms_with_status(
  p_search_query text DEFAULT NULL
)
RETURNS TABLE (
  id uuid,
  name text,
  description text,
  icon_url text,
  background_url text,
  password text,
  created_at timestamp with time zone,
  member_count bigint,
  is_joined boolean,
  tags text[]
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_clean_query text := REPLACE(COALESCE(p_search_query, ''), '#', '');
BEGIN
  RETURN QUERY
  SELECT
    r.id,
    r.name,
    r.description,
    r.icon_url,
    r.background_url,
    r.password,
    r.created_at,
    r.member_count,
    EXISTS (SELECT 1 FROM public.open_chat_members m2 WHERE m2.room_id = r.id AND m2.user_id = v_user_id) AS is_joined,
    COALESCE(r.tags, '{}'::text[]) AS tags
  FROM
    public.open_chat_rooms r
  WHERE
    (
      p_search_query IS NULL
      OR p_search_query = ''
      OR r.name ILIKE '%' || p_search_query || '%'
      OR r.description ILIKE '%' || p_search_query || '%'
      OR (v_clean_query <> '' AND v_clean_query = ANY(r.tags))
      OR (v_clean_query <> '' AND EXISTS (SELECT 1 FROM unnest(r.tags) t WHERE t ILIKE '%' || v_clean_query || '%'))
    )
  ORDER BY
    EXISTS (SELECT 1 FROM public.open_chat_members m2 WHERE m2.room_id = r.id AND m2.user_id = v_user_id) DESC,
    r.member_count DESC,
    r.created_at DESC;
END;
$$;

-- ==============================================================================
-- 9. 管理人譲渡 RPC (transfer_room_ownership)
--    旧オーナー → admin に降格 / 新オーナー → owner に昇格
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.transfer_room_ownership(
  p_room_id uuid,
  p_new_owner_id uuid
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_caller_id uuid := auth.uid();
  v_is_owner boolean;
  v_target_exists boolean;
BEGIN
  IF v_caller_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'UNAUTHORIZED');
  END IF;

  -- 呼び出し元がオーナー(owner)か確認
  SELECT EXISTS(
    SELECT 1 FROM public.open_chat_members
    WHERE room_id = p_room_id AND user_id = v_caller_id AND role = 'owner'
  ) INTO v_is_owner;

  IF NOT v_is_owner THEN
    RETURN json_build_object('success', false, 'error', '管理人のみが権限を譲渡できます');
  END IF;

  -- 新しいオーナーがメンバーか確認 (自分への譲渡も不可)
  SELECT EXISTS(
    SELECT 1 FROM public.open_chat_members
    WHERE room_id = p_room_id AND user_id = p_new_owner_id AND user_id != v_caller_id
  ) INTO v_target_exists;

  IF NOT v_target_exists THEN
    RETURN json_build_object('success', false, 'error', 'メンバーではないユーザーには譲渡できません');
  END IF;

  -- 旧オーナーを admin に降格
  UPDATE public.open_chat_members
  SET role = 'admin'
  WHERE room_id = p_room_id AND user_id = v_caller_id;

  -- 新オーナーを owner に昇格
  UPDATE public.open_chat_members
  SET role = 'owner'
  WHERE room_id = p_room_id AND user_id = p_new_owner_id;

  RETURN json_build_object('success', true);
END;
$$;

-- ==============================================================================
-- 10. 副管理人任命 RPC (assign_admin_role) — オーナーのみ
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.assign_admin_role(
  p_room_id uuid,
  p_target_user_id uuid
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_caller_id uuid := auth.uid();
  v_is_owner boolean;
BEGIN
  IF v_caller_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'UNAUTHORIZED');
  END IF;

  -- オーナー(owner)のみ実行可能
  SELECT EXISTS(
    SELECT 1 FROM public.open_chat_members
    WHERE room_id = p_room_id AND user_id = v_caller_id AND role = 'owner'
  ) INTO v_is_owner;

  IF NOT v_is_owner THEN
    RETURN json_build_object('success', false, 'error', '管理人のみが副管理人を任命できます');
  END IF;

  -- 一般メンバー(member)のみを副管理人(admin)に昇格
  UPDATE public.open_chat_members
  SET role = 'admin'
  WHERE room_id = p_room_id AND user_id = p_target_user_id AND role = 'member';

  IF FOUND THEN
    RETURN json_build_object('success', true);
  ELSE
    RETURN json_build_object('success', false, 'error', '対象はこのルームの一般メンバーではありません');
  END IF;
END;
$$;

-- ==============================================================================
-- 11. 副管理人解任 RPC (revoke_admin_role) — オーナーのみ
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.revoke_admin_role(
  p_room_id uuid,
  p_target_user_id uuid
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_caller_id uuid := auth.uid();
  v_is_owner boolean;
  v_target_is_owner boolean;
BEGIN
  IF v_caller_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'UNAUTHORIZED');
  END IF;

  -- オーナー(owner)のみ実行可能
  SELECT EXISTS(
    SELECT 1 FROM public.open_chat_members
    WHERE room_id = p_room_id AND user_id = v_caller_id AND role = 'owner'
  ) INTO v_is_owner;

  IF NOT v_is_owner THEN
    RETURN json_build_object('success', false, 'error', '管理人のみが副管理人を解任できます');
  END IF;

  -- 対象がオーナーの場合は解任不可
  SELECT EXISTS(
    SELECT 1 FROM public.open_chat_members
    WHERE room_id = p_room_id AND user_id = p_target_user_id AND role = 'owner'
  ) INTO v_target_is_owner;

  IF v_target_is_owner THEN
    RETURN json_build_object('success', false, 'error', '管理人を副管理人から外すことはできません');
  END IF;

  -- 副管理人(admin)のみを一般メンバー(member)に降格
  UPDATE public.open_chat_members
  SET role = 'member'
  WHERE room_id = p_room_id AND user_id = p_target_user_id AND role = 'admin';

  IF FOUND THEN
    RETURN json_build_object('success', true);
  ELSE
    RETURN json_build_object('success', false, 'error', '対象はこのルームの副管理人ではありません');
  END IF;
END;
$$;

-- ==============================================================================
-- 12. kick_open_chat_member 更新: 3値化対応 + 権限ガード
--     オーナー(owner) と 副管理人(admin) はキック可能
--     副管理人(admin) は オーナー/他の副管理人 をキック不可
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.kick_open_chat_member(
  p_room_id uuid,
  p_target_user_id uuid,
  p_ban boolean DEFAULT false
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_role text;
  v_target_role text;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'UNAUTHORIZED');
  END IF;

  -- 自分が対象のルームのモデレーター(owner/admin)であるか確認
  SELECT role INTO v_role FROM public.open_chat_members WHERE room_id = p_room_id AND user_id = v_user_id;

  IF v_role IS NULL OR v_role NOT IN ('owner', 'admin') THEN
    RETURN json_build_object('success', false, 'error', 'NOT_ADMIN');
  END IF;

  -- 自分自身はキックできない
  IF v_user_id = p_target_user_id THEN
    RETURN json_build_object('success', false, 'error', 'CANNOT_KICK_SELF');
  END IF;

  -- 対象のロールを取得
  SELECT role INTO v_target_role FROM public.open_chat_members WHERE room_id = p_room_id AND user_id = p_target_user_id;

  -- 副管理人(admin)はオーナー(owner)・他の副管理人(admin)をキック不可
  IF v_role = 'admin' AND v_target_role IN ('owner', 'admin') THEN
    RETURN json_build_object('success', false, 'error', 'CANNOT_KICK_STAFF');
  END IF;

  -- 対象者をメンバーから削除
  DELETE FROM public.open_chat_members WHERE room_id = p_room_id AND user_id = p_target_user_id;

  -- 再参加禁止フラグがONの場合は禁止リストに追加
  IF p_ban THEN
    INSERT INTO public.open_chat_banned_users (room_id, user_id, created_by)
    VALUES (p_room_id, p_target_user_id, v_user_id)
    ON CONFLICT (room_id, user_id) DO NOTHING;
  END IF;

  RETURN json_build_object('success', true);
END;
$$;

-- ==============================================================================
-- 13. unban_open_chat_member 更新: BAN解除はオーナーのみ
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.unban_open_chat_member(
  p_room_id uuid,
  p_target_user_id uuid
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_role text;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'UNAUTHORIZED');
  END IF;

  -- 自分が対象のルームのオーナー(owner)であるか確認
  SELECT role INTO v_role FROM public.open_chat_members WHERE room_id = p_room_id AND user_id = v_user_id;

  IF v_role IS NULL OR v_role != 'owner' THEN
    RETURN json_build_object('success', false, 'error', 'NOT_OWNER');
  END IF;

  -- 再参加禁止リストから削除
  DELETE FROM public.open_chat_banned_users
  WHERE room_id = p_room_id AND user_id = p_target_user_id;

  IF FOUND THEN
    RETURN json_build_object('success', true);
  ELSE
    RETURN json_build_object('success', false, 'error', 'USER_NOT_BANNED');
  END IF;
END;
$$;

-- ==============================================================================
-- 14. get_open_chat_banned_users 更新: owner/admin で閲覧可能
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.get_open_chat_banned_users(
  p_room_id uuid
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_role text;
  v_result json;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'UNAUTHORIZED');
  END IF;

  -- 自分が対象のルームのモデレーター(owner/admin)であるか確認
  SELECT role INTO v_role FROM public.open_chat_members WHERE room_id = p_room_id AND user_id = v_user_id;

  IF v_role IS NULL OR v_role NOT IN ('owner', 'admin') THEN
    RETURN json_build_object('success', false, 'error', 'NOT_ADMIN');
  END IF;

  SELECT json_agg(
    json_build_object(
      'id', b.id,
      'room_id', b.room_id,
      'user_id', b.user_id,
      'created_at', b.created_at,
      'user_name', COALESCE(u.name, '名無しユーザー'),
      'avatar_url', u.avatar_url
    ) ORDER BY b.created_at DESC
  ) INTO v_result
  FROM public.open_chat_banned_users b
  LEFT JOIN public.users u ON u.id = b.user_id
  WHERE b.room_id = p_room_id;

  RETURN json_build_object('success', true, 'data', COALESCE(v_result, '[]'::json));
END;
$$;

-- ==============================================================================
-- 15. delete_open_chat_message 更新: owner_id 参照を members.role ベースに修正
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.delete_open_chat_message(
  p_message_id uuid
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_msg record;
  v_is_admin boolean;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'UNAUTHORIZED');
  END IF;

  -- 対象メッセージを取得
  SELECT * INTO v_msg
  FROM public.open_chat_messages
  WHERE id = p_message_id;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'MESSAGE_NOT_FOUND');
  END IF;

  -- 1. 送信者本人であるか確認（本人の送信取り消し / 削除）
  IF v_msg.user_id = v_user_id THEN
    UPDATE public.open_chat_messages
    SET is_deleted = true,
        is_admin_deleted = false
    WHERE id = p_message_id;

    RETURN json_build_object('success', true, 'is_admin_deleted', false);
  END IF;

  -- 2. ルームのオーナー(owner)または副管理人(admin)であるか確認（管理者による強制削除）
  SELECT EXISTS (
    SELECT 1 FROM public.open_chat_members m
    WHERE m.room_id = v_msg.room_id
      AND m.user_id = v_user_id
      AND m.role IN ('owner', 'admin')
  ) INTO v_is_admin;

  IF v_is_admin THEN
    UPDATE public.open_chat_messages
    SET is_deleted = true,
        is_admin_deleted = true
    WHERE id = p_message_id;

    RETURN json_build_object('success', true, 'is_admin_deleted', true);
  ELSE
    RETURN json_build_object('success', false, 'error', 'PERMISSION_DENIED');
  END IF;
END;
$$;

-- ==============================================================================
-- 16. complete_data_transfer_v2 更新: owner_id 更新を削除
--     members の user_id 置換で role='owner' もそのまま引き継がれる
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.complete_data_transfer_v2(
  p_transfer_id text,
  p_password    text,
  p_receiver_id uuid
)
  RETURNS text
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
    v_transfer_record public.transfer%ROWTYPE;
    v_sender_user_data public.users%ROWTYPE;
    v_send_id uuid;
BEGIN
    -- 1. 移行情報の検証と取得
    SELECT * INTO v_transfer_record
    FROM public.transfer
    WHERE id = p_transfer_id
      AND password = p_password
      AND delete_at > now()
      AND receive_id IS NULL;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Invalid transfer ID, password, expired, or already used.';
    END IF;

    v_send_id := v_transfer_record.send_id;

    -- 同一アカウントへの引き継ぎ防止
    IF v_send_id = p_receiver_id THEN
        RAISE EXCEPTION 'Cannot transfer to the same account.';
    END IF;

    -- 2. 移行情報の更新（受取人を記録）
    UPDATE public.transfer SET receive_id = p_receiver_id WHERE id = v_transfer_record.id;

    -- 3. 送信者（移行元）のデータを取得
    SELECT * INTO v_sender_user_data FROM public.users WHERE id = v_send_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Sender user not found.';
    END IF;

    -- 4. 受信者（移行先）のプロフィール・戦績を更新（完全コピー）
    UPDATE public.users
    SET
        name = COALESCE(v_sender_user_data.name, name),
        avatar_url = v_sender_user_data.avatar_url,
        header_url = v_sender_user_data.header_url,
        bio = v_sender_user_data.bio,
        win = v_sender_user_data.win,
        lose = v_sender_user_data.lose,
        trophy = v_sender_user_data.trophy,
        created_at = v_sender_user_data.created_at,
        is_notification_enabled = v_sender_user_data.is_notification_enabled
    WHERE id = p_receiver_id;

    -- 5. 通知設定（notification_settings）を引き継ぐ
    INSERT INTO public.notification_settings (
        user_id, is_notification_enabled,
        like_enabled, comment_enabled, follow_enabled,
        dm_enabled, open_chat_enabled, match_waiting_enabled
    )
    SELECT
        p_receiver_id, ns.is_notification_enabled,
        ns.like_enabled, ns.comment_enabled, ns.follow_enabled,
        ns.dm_enabled, ns.open_chat_enabled, ns.match_waiting_enabled
    FROM public.notification_settings ns
    WHERE ns.user_id = v_send_id
    ON CONFLICT (user_id) DO UPDATE SET
        is_notification_enabled = EXCLUDED.is_notification_enabled,
        like_enabled = EXCLUDED.like_enabled,
        comment_enabled = EXCLUDED.comment_enabled,
        follow_enabled = EXCLUDED.follow_enabled,
        dm_enabled = EXCLUDED.dm_enabled,
        open_chat_enabled = EXCLUDED.open_chat_enabled,
        match_waiting_enabled = EXCLUDED.match_waiting_enabled,
        updated_at = now();

    -- 6. 掲示板（BBS）データの引き継ぎ
    -- 投稿・コメント
    UPDATE public.bbs_posts SET user_id = p_receiver_id WHERE user_id = v_send_id;
    UPDATE public.bbs_comments SET user_id = p_receiver_id WHERE user_id = v_send_id;
    -- いいね（重複回避して更新）
    DELETE FROM public.bbs_likes WHERE user_id = p_receiver_id AND post_id IN (SELECT post_id FROM public.bbs_likes WHERE user_id = v_send_id);
    UPDATE public.bbs_likes SET user_id = p_receiver_id WHERE user_id = v_send_id;
    -- コメントいいね（重複回避して更新）
    DELETE FROM public.bbs_comment_likes WHERE user_id = p_receiver_id AND comment_id IN (SELECT comment_id FROM public.bbs_comment_likes WHERE user_id = v_send_id);
    UPDATE public.bbs_comment_likes SET user_id = p_receiver_id WHERE user_id = v_send_id;

    -- 7. DMデータの引き継ぎ
    -- ルームメンバーシップ（重複回避して更新）
    DELETE FROM public.dm_room_members WHERE user_id = p_receiver_id AND room_id IN (SELECT room_id FROM public.dm_room_members WHERE user_id = v_send_id);
    UPDATE public.dm_room_members SET user_id = p_receiver_id WHERE user_id = v_send_id;
    -- メッセージ送信者
    UPDATE public.dm_messages SET sender_id = p_receiver_id WHERE sender_id = v_send_id;

    -- 8. オープンチャットデータの引き継ぎ
    -- ※ owner_id カラムは廃止済み。members の user_id 置換により
    --   role='owner' がそのまま受信者に引き継がれる
    -- メンバーシップ（重複回避して更新）
    DELETE FROM public.open_chat_members WHERE user_id = p_receiver_id AND room_id IN (SELECT room_id FROM public.open_chat_members WHERE user_id = v_send_id);
    UPDATE public.open_chat_members SET user_id = p_receiver_id WHERE user_id = v_send_id;
    -- メッセージ送信者
    UPDATE public.open_chat_messages SET user_id = p_receiver_id WHERE user_id = v_send_id;

    -- 9. フォロー関係の引き継ぎ
    -- 自分がフォローしている相手
    DELETE FROM public.user_follows WHERE follower_id = p_receiver_id AND followed_id IN (SELECT followed_id FROM public.user_follows WHERE follower_id = v_send_id);
    UPDATE public.user_follows SET follower_id = p_receiver_id WHERE follower_id = v_send_id AND followed_id <> p_receiver_id;
    -- 自分をフォローしている相手
    DELETE FROM public.user_follows WHERE followed_id = p_receiver_id AND follower_id IN (SELECT follower_id FROM public.user_follows WHERE followed_id = v_send_id);
    UPDATE public.user_follows SET followed_id = p_receiver_id WHERE followed_id = v_send_id AND follower_id <> p_receiver_id;
    -- 自己フォローのクリーンアップ
    DELETE FROM public.user_follows WHERE follower_id = followed_id;

    -- 10. ブロック関係の引き継ぎ
    -- 自分がブロックしている相手
    DELETE FROM public.brock_user WHERE user_id = p_receiver_id AND block_user_id IN (SELECT block_user_id FROM public.brock_user WHERE user_id = v_send_id);
    UPDATE public.brock_user SET user_id = p_receiver_id WHERE user_id = v_send_id AND block_user_id <> p_receiver_id;
    -- 自分をブロックしている相手
    DELETE FROM public.brock_user WHERE block_user_id = p_receiver_id AND user_id IN (SELECT user_id FROM public.brock_user WHERE block_user_id = v_send_id);
    UPDATE public.brock_user SET block_user_id = p_receiver_id WHERE block_user_id = v_send_id AND user_id <> p_receiver_id;
    -- 自己ブロックのクリーンアップ
    DELETE FROM public.brock_user WHERE user_id = block_user_id;

    -- 11. 対戦履歴・チャットログの引き継ぎ
    UPDATE public.match_record SET player1_id = p_receiver_id WHERE player1_id = v_send_id;
    UPDATE public.match_record SET player2_id = p_receiver_id WHERE player2_id = v_send_id;
    UPDATE public.match_record SET winner = p_receiver_id WHERE winner = v_send_id;
    UPDATE public.rooms_v2 SET player1_id = p_receiver_id WHERE player1_id = v_send_id;
    UPDATE public.rooms_v2 SET player2_id = p_receiver_id WHERE player2_id = v_send_id;
    UPDATE public.rooms_v2 SET winner_user_id = p_receiver_id WHERE winner_user_id = v_send_id;
    UPDATE public.messages SET sender_id = p_receiver_id WHERE sender_id = v_send_id;

    -- 12. 通知履歴の引き継ぎ
    UPDATE public.notifications SET user_id = p_receiver_id WHERE user_id = v_send_id;
    UPDATE public.notifications SET actor_id = p_receiver_id WHERE actor_id = v_send_id;

    -- 13. レスバ履歴の引き継ぎ
    -- 過去の完了済みレスバ
    UPDATE public.battle_invites SET sender_id = p_receiver_id WHERE sender_id = v_send_id;
    UPDATE public.battle_invites SET responder_id = p_receiver_id WHERE responder_id = v_send_id;
    UPDATE public.battle_invite_applications SET applicant_id = p_receiver_id WHERE applicant_id = v_send_id;

    -- 14. 送信者（移行元）のアカウントを初期化
    UPDATE public.users
    SET
        name = '退会済みユーザー',
        avatar_url = NULL,
        header_url = NULL,
        bio = NULL,
        win = 0,
        lose = 0,
        trophy = 0,
        status = true,
        created_at = now(),
        fcm_token = NULL,
        is_notification_enabled = false
    WHERE id = v_send_id;

    UPDATE public.notification_settings
    SET
        is_notification_enabled = false,
        like_enabled = false,
        comment_enabled = false,
        follow_enabled = false,
        dm_enabled = false,
        open_chat_enabled = false,
        match_waiting_enabled = false,
        updated_at = now()
    WHERE user_id = v_send_id;

    RETURN 'Data transfer completed successfully.';
EXCEPTION
    WHEN OTHERS THEN
        RAISE;
END;
$function$;

-- 権限付与 (データ移行関連)
GRANT ALL ON FUNCTION public.initiate_data_transfer(uuid) TO anon, authenticated, service_role;
GRANT ALL ON FUNCTION public.complete_data_transfer_v2(text, text, uuid) TO anon, authenticated, service_role;