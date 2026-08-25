-- ==============================================================================
-- マイグレーション: オプチャ追放機能の改修
--   1. 追放ログ用に open_chat_messages.is_system カラムを追加
--   2. open_chat_members を Realtime 公開 (追放のリアルタイム検知用) + REPLICA IDENTITY FULL
--   3. join_open_chat にも再参加禁止チェックを追加 (クライアントが実際に呼ぶ関数)
--      ※ 既存の join_open_chat_room にも同じチェックがあるが、クライアントは
--        join_open_chat を呼んでいるため、そちらが欠けていた
--      ※ 再参加禁止リストに入っていなければ再参加は許可される
--   4. kick_open_chat_member: 再参加禁止フラグ(p_ban)がONの場合のみ再参加禁止。
--      「AがBを追放しました」ログは常にチャットに残す (is_system = true)
-- ==============================================================================

-- 1. is_system カラム追加 (追放ログなどのシステムメッセージ)
ALTER TABLE public.open_chat_messages
  ADD COLUMN IF NOT EXISTS is_system boolean NOT NULL DEFAULT false;

-- 2. open_chat_members を Realtime 公開 (メンバー削除 → 追放検知)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'open_chat_members'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.open_chat_members;
  END IF;
END $$;

-- DELETE イベントで削除前の行全体 (old_record) を取得できるようにする
ALTER TABLE public.open_chat_members REPLICA IDENTITY FULL;

-- 3. join_open_chat: 再参加禁止チェックを追加
CREATE OR REPLACE FUNCTION public.join_open_chat(
  p_room_id uuid
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id uuid := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'UNAUTHORIZED');
  END IF;

  -- 再参加禁止リストに含まれているかチェック
  IF EXISTS (
    SELECT 1 FROM public.open_chat_banned_users
    WHERE room_id = p_room_id AND user_id = v_user_id
  ) THEN
    RETURN json_build_object('success', false, 'error', 'BANNED_FROM_ROOM');
  END IF;

  -- 既に参加しているかチェック
  IF EXISTS (
    SELECT 1 FROM public.open_chat_members
    WHERE room_id = p_room_id AND user_id = v_user_id
  ) THEN
    RETURN json_build_object('success', false, 'error', 'ALREADY_JOINED');
  END IF;

  INSERT INTO public.open_chat_members (room_id, user_id, role)
  VALUES (p_room_id, v_user_id, 'member');

  RETURN json_build_object('success', true);
END;
$$;

-- join_open_chat_room (別名関数) も同じ定義に揃える
CREATE OR REPLACE FUNCTION public.join_open_chat_room(
  p_room_id uuid
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id uuid := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'UNAUTHORIZED');
  END IF;

  -- 再参加禁止リストに含まれているかチェック
  IF EXISTS (
    SELECT 1 FROM public.open_chat_banned_users
    WHERE room_id = p_room_id AND user_id = v_user_id
  ) THEN
    RETURN json_build_object('success', false, 'error', 'BANNED_FROM_ROOM');
  END IF;

  -- 既に参加しているかチェック
  IF EXISTS (
    SELECT 1 FROM public.open_chat_members
    WHERE room_id = p_room_id AND user_id = v_user_id
  ) THEN
    RETURN json_build_object('success', false, 'error', 'ALREADY_JOINED');
  END IF;

  INSERT INTO public.open_chat_members (room_id, user_id, role)
  VALUES (p_room_id, v_user_id, 'member');

  RETURN json_build_object('success', true);
END;
$$;

-- 4. kick_open_chat_member: 3値ロール対応維持 + 再参加禁止はフラグON時のみ + 追放ログ投稿
--     ・オーナー(owner) と 副管理人(admin) は追放可能
--     ・副管理人(admin) は オーナー/他の副管理人 を追放不可 (CANNOT_KICK_STAFF)
--     ・p_ban = true の場合のみ再参加禁止リストに追加 (false なら再参加可能)
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
  v_admin_name text;
  v_target_name text;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'UNAUTHORIZED');
  END IF;

  -- 自分が対象のルームのモデレーター(owner/admin)であるか確認
  SELECT role INTO v_role
  FROM public.open_chat_members
  WHERE room_id = p_room_id AND user_id = v_user_id;

  IF v_role IS NULL OR v_role NOT IN ('owner', 'admin') THEN
    RETURN json_build_object('success', false, 'error', 'NOT_ADMIN');
  END IF;

  -- 自分自身は追放できない
  IF v_user_id = p_target_user_id THEN
    RETURN json_build_object('success', false, 'error', 'CANNOT_KICK_SELF');
  END IF;

  -- 対象者のロールを取得し、存在確認も兼ねる
  SELECT role INTO v_target_role
  FROM public.open_chat_members
  WHERE room_id = p_room_id AND user_id = p_target_user_id;

  IF v_target_role IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'USER_NOT_FOUND');
  END IF;

  -- 副管理人(admin)はオーナー(owner)・他の副管理人(admin)を追放不可
  IF v_role = 'admin' AND v_target_role IN ('owner', 'admin') THEN
    RETURN json_build_object('success', false, 'error', 'CANNOT_KICK_STAFF');
  END IF;

  -- 対象者をメンバーから削除
  DELETE FROM public.open_chat_members
  WHERE room_id = p_room_id AND user_id = p_target_user_id;

  -- 再参加禁止フラグがONの場合のみ再参加禁止リストに追加
  -- (OFFの場合は再参加可能。解除は管理人が再参加禁止リストから行う)
  IF p_ban THEN
    INSERT INTO public.open_chat_banned_users (room_id, user_id, created_by)
    VALUES (p_room_id, p_target_user_id, v_user_id)
    ON CONFLICT (room_id, user_id) DO NOTHING;
  END IF;

  -- 追放ログをチャットに残す (「AがBを追放しました」)
  SELECT COALESCE(name, '名無しユーザー') INTO v_admin_name
  FROM public.users WHERE id = v_user_id;

  SELECT COALESCE(name, '名無しユーザー') INTO v_target_name
  FROM public.users WHERE id = p_target_user_id;

  INSERT INTO public.open_chat_messages (room_id, user_id, content, is_system)
  VALUES (
    p_room_id,
    v_user_id,
    v_admin_name || 'が' || v_target_name || 'を追放しました',
    true
  );

  RETURN json_build_object('success', true);
END;
$$;