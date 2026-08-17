-- 1. DMルームテーブル
CREATE TABLE public.dm_rooms (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2. DMルームメンバーテーブル (誰がどのルームに参加しているか)
CREATE TABLE public.dm_room_members (
    room_id UUID REFERENCES public.dm_rooms(id) ON DELETE CASCADE,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (room_id, user_id)
);

-- 3. DMメッセージテーブル
CREATE TABLE public.dm_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    room_id UUID REFERENCES public.dm_rooms(id) ON DELETE CASCADE,
    sender_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    is_read BOOLEAN NOT NULL DEFAULT false
);

-- 4. 既存ルーム取得または新規作成のRPC
CREATE OR REPLACE FUNCTION get_or_create_dm_room(other_user_id UUID)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_my_id UUID;
    v_room_id UUID;
BEGIN
    -- 自分のユーザーIDを取得
    v_my_id := auth.uid();
    
    IF v_my_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    -- 既に1対1のルームが存在するか確認 (双方のIDがメンバーとして属しているルーム)
    SELECT r.id INTO v_room_id
    FROM dm_rooms r
    JOIN dm_room_members m1 ON r.id = m1.room_id AND m1.user_id = v_my_id
    JOIN dm_room_members m2 ON r.id = m2.room_id AND m2.user_id = other_user_id
    LIMIT 1;

    -- 存在しなければ作成
    IF v_room_id IS NULL THEN
        -- ルーム作成
        INSERT INTO dm_rooms DEFAULT VALUES RETURNING id INTO v_room_id;
        
        -- 自分をメンバー追加
        INSERT INTO dm_room_members (room_id, user_id) VALUES (v_room_id, v_my_id);
        
        -- 相手をメンバー追加
        IF v_my_id != other_user_id THEN
            INSERT INTO dm_room_members (room_id, user_id) VALUES (v_room_id, other_user_id);
        END IF;
    END IF;

    RETURN v_room_id;
END;
$$;

-- 5. Row Level Security (RLS) の有効化
ALTER TABLE public.dm_rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dm_room_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dm_messages ENABLE ROW LEVEL SECURITY;

-- dm_rooms: 自分が参加しているルームのみ見れる
CREATE POLICY "Users can view their own dm_rooms" ON public.dm_rooms
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.dm_room_members
            WHERE room_id = dm_rooms.id AND user_id = auth.uid()
        )
    );

-- dm_room_members: 自分が参加しているルームのメンバーリストを見れる
CREATE POLICY "Users can view room members of their rooms" ON public.dm_room_members
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.dm_room_members as m
            WHERE m.room_id = dm_room_members.room_id AND m.user_id = auth.uid()
        )
    );

-- dm_messages: 自分が参加しているルームのメッセージのみ読み書き可能
CREATE POLICY "Users can read messages in their rooms" ON public.dm_messages
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.dm_room_members
            WHERE room_id = dm_messages.room_id AND user_id = auth.uid()
        )
    );

CREATE POLICY "Users can insert messages in their rooms" ON public.dm_messages
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.dm_room_members
            WHERE room_id = dm_messages.room_id AND user_id = auth.uid()
        )
        AND sender_id = auth.uid()
    );


alter publication supabase_realtime add table dm_messages;
