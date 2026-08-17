-- ==========================================
-- 1. テーブルの作成
-- ==========================================

-- オープンチャットのルーム管理テーブル
CREATE TABLE public.open_chat_rooms (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  name text NOT NULL,
  description text,
  icon_url text,
  owner_id uuid NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT open_chat_rooms_pkey PRIMARY KEY (id),
  CONSTRAINT open_chat_rooms_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES public.users(id) ON DELETE CASCADE
);

-- オープンチャットのメンバー・権限管理テーブル
CREATE TABLE public.open_chat_members (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  room_id uuid NOT NULL,
  user_id uuid NOT NULL,
  role text DEFAULT 'member'::text CHECK (role IN ('admin', 'member')),
  joined_at timestamp with time zone DEFAULT now(),
  CONSTRAINT open_chat_members_pkey PRIMARY KEY (id),
  CONSTRAINT open_chat_members_room_id_fkey FOREIGN KEY (room_id) REFERENCES public.open_chat_rooms(id) ON DELETE CASCADE,
  CONSTRAINT open_chat_members_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE,
  CONSTRAINT open_chat_members_room_user_unique UNIQUE (room_id, user_id)
);

-- オープンチャットのメッセージ管理テーブル
CREATE TABLE public.open_chat_messages (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  room_id uuid NOT NULL,
  user_id uuid NOT NULL,
  content text NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT open_chat_messages_pkey PRIMARY KEY (id),
  CONSTRAINT open_chat_messages_room_id_fkey FOREIGN KEY (room_id) REFERENCES public.open_chat_rooms(id) ON DELETE CASCADE,
  CONSTRAINT open_chat_messages_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE
);

-- ==========================================
-- 2. RLS (Row Level Security) の設定
-- ==========================================

ALTER TABLE public.open_chat_rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.open_chat_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.open_chat_messages ENABLE ROW LEVEL SECURITY;

-- open_chat_rooms
CREATE POLICY "誰でもルーム一覧を閲覧可能" ON public.open_chat_rooms FOR SELECT USING (true);
CREATE POLICY "認証済みユーザーはルームを作成可能" ON public.open_chat_rooms FOR INSERT WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "ルーム管理者は更新可能" ON public.open_chat_rooms FOR UPDATE USING (auth.uid() = owner_id);
CREATE POLICY "ルーム管理者は削除可能" ON public.open_chat_rooms FOR DELETE USING (auth.uid() = owner_id);

-- open_chat_members
CREATE POLICY "誰でもメンバーを閲覧可能" ON public.open_chat_members FOR SELECT USING (true);
CREATE POLICY "自分のメンバー情報を削除可能(退出)" ON public.open_chat_members FOR DELETE USING (auth.uid() = user_id);
-- ※参加処理やキック処理はRPC経由で行うため、直接のINSERT/UPDATEポリシーは制限するかRPCに任せます。

-- open_chat_messages
CREATE POLICY "誰でもメッセージを閲覧可能" ON public.open_chat_messages FOR SELECT USING (true);
CREATE POLICY "メンバーのみメッセージを送信可能" ON public.open_chat_messages FOR INSERT WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.open_chat_members 
    WHERE room_id = open_chat_messages.room_id AND user_id = auth.uid()
  )
);

-- ==========================================
-- 3. RPC関数 (ビジネスロジック)
-- ==========================================

-- ルーム作成と同時に自身を管理者としてメンバーに追加する関数
CREATE OR REPLACE FUNCTION public.create_open_chat_room(
  p_name text,
  p_description text,
  p_icon_url text
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_room_id uuid;
  v_user_id uuid := auth.uid();
  v_room_data record;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'UNAUTHORIZED');
  END IF;

  -- 1. ルームを作成
  INSERT INTO public.open_chat_rooms (name, description, icon_url, owner_id)
  VALUES (p_name, p_description, p_icon_url, v_user_id)
  RETURNING * INTO v_room_data;

  v_room_id := v_room_data.id;

  -- 2. 自身を管理者(admin)としてメンバーテーブルに追加
  INSERT INTO public.open_chat_members (room_id, user_id, role)
  VALUES (v_room_id, v_user_id, 'admin');

  RETURN json_build_object('success', true, 'room', row_to_json(v_room_data));
END;
$$;

-- ルームに参加する関数
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

  -- 既に参加しているかチェック
  IF EXISTS (SELECT 1 FROM public.open_chat_members WHERE room_id = p_room_id AND user_id = v_user_id) THEN
    RETURN json_build_object('success', false, 'error', 'ALREADY_JOINED');
  END IF;

  INSERT INTO public.open_chat_members (room_id, user_id, role)
  VALUES (p_room_id, v_user_id, 'member');

  RETURN json_build_object('success', true);
END;
$$;

-- メンバーをキック(削除)する関数 (管理者専用)
CREATE OR REPLACE FUNCTION public.kick_open_chat_member(
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

  -- 対象者を削除
  DELETE FROM public.open_chat_members WHERE room_id = p_room_id AND user_id = p_target_user_id;

  IF FOUND THEN
    RETURN json_build_object('success', true);
  ELSE
    RETURN json_build_object('success', false, 'error', 'USER_NOT_FOUND');
  END IF;
END;
$$;
