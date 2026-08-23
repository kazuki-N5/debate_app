-- ==============================================================================
-- マイグレーション: オプチャの再参加禁止 (BAN) 機能 ＆ リスト管理
-- ==============================================================================

-- 1. open_chat_banned_users テーブルの作成
CREATE TABLE IF NOT EXISTS public.open_chat_banned_users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id UUID NOT NULL REFERENCES public.open_chat_rooms(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
  created_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
  CONSTRAINT uq_open_chat_banned_room_user UNIQUE (room_id, user_id)
);

-- インデックス
CREATE INDEX IF NOT EXISTS idx_open_chat_banned_users_room_id 
  ON public.open_chat_banned_users(room_id);

CREATE INDEX IF NOT EXISTS idx_open_chat_banned_users_user_id 
  ON public.open_chat_banned_users(user_id);

-- RLS有効化
ALTER TABLE public.open_chat_banned_users ENABLE ROW LEVEL SECURITY;

-- 管理者のみ閲覧・操作可能にするRLSポリシー
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'open_chat_banned_users' AND policyname = '管理者は再参加禁止リストを参照可能'
  ) THEN
    CREATE POLICY "管理者は再参加禁止リストを参照可能" 
      ON public.open_chat_banned_users 
      FOR SELECT 
      USING (
        EXISTS (
          SELECT 1 FROM public.open_chat_members 
          WHERE room_id = open_chat_banned_users.room_id 
            AND user_id = auth.uid() 
            AND role = 'admin'
        )
      );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'open_chat_banned_users' AND policyname = '管理者は再参加禁止リストを操作可能'
  ) THEN
    CREATE POLICY "管理者は再参加禁止リストを操作可能" 
      ON public.open_chat_banned_users 
      FOR ALL 
      USING (
        EXISTS (
          SELECT 1 FROM public.open_chat_members 
          WHERE room_id = open_chat_banned_users.room_id 
            AND user_id = auth.uid() 
            AND role = 'admin'
        )
      )
      WITH CHECK (
        EXISTS (
          SELECT 1 FROM public.open_chat_members 
          WHERE room_id = open_chat_banned_users.room_id 
            AND user_id = auth.uid() 
            AND role = 'admin'
        )
      );
  END IF;
END $$;

-- 2. 参加関数 (join_open_chat_room) の更新: 再参加禁止ユーザーをブロック
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

-- 3. メンバー削除・キック関数 (kick_open_chat_member) の拡張
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
BEGIN
  IF v_user_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'UNAUTHORIZED');
  END IF;

  -- 自分が対象のルームの管理者(admin)であるか確認
  SELECT role INTO v_role FROM public.open_chat_members WHERE room_id = p_room_id AND user_id = v_user_id;

  IF v_role IS NULL OR v_role != 'admin' THEN
    RETURN json_build_object('success', false, 'error', 'NOT_ADMIN');
  END IF;

  -- オーナー自身はキックできない
  IF v_user_id = p_target_user_id THEN
    RETURN json_build_object('success', false, 'error', 'CANNOT_KICK_SELF');
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

-- 4. 再参加禁止解除関数 (unban_open_chat_member)
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

  -- 自分が対象のルームの管理者(admin)であるか確認
  SELECT role INTO v_role FROM public.open_chat_members WHERE room_id = p_room_id AND user_id = v_user_id;

  IF v_role IS NULL OR v_role != 'admin' THEN
    RETURN json_build_object('success', false, 'error', 'NOT_ADMIN');
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

-- 5. 再参加禁止メンバー一覧取得関数 (get_open_chat_banned_users)
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

  -- 自分が対象のルームの管理者(admin)であるか確認
  SELECT role INTO v_role FROM public.open_chat_members WHERE room_id = p_room_id AND user_id = v_user_id;

  IF v_role IS NULL OR v_role != 'admin' THEN
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
