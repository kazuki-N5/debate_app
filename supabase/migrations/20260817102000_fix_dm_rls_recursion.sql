-- 1. 再帰を引き起こす既存のポリシーを削除
DROP POLICY IF EXISTS "Users can view their own dm_rooms" ON public.dm_rooms;
DROP POLICY IF EXISTS "Users can view room members of their rooms" ON public.dm_room_members;
DROP POLICY IF EXISTS "Users can read messages in their rooms" ON public.dm_messages;
DROP POLICY IF EXISTS "Users can insert messages in their rooms" ON public.dm_messages;

-- 2. 自分がルームのメンバーかどうかを判定する関数を作成 (SECURITY DEFINER で RLSをバイパス)
CREATE OR REPLACE FUNCTION public.is_dm_room_member(room_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.dm_room_members
        WHERE dm_room_members.room_id = $1 AND dm_room_members.user_id = auth.uid()
    );
$$;

-- 3. 新しいポリシーを作成 (作成した関数を使用)
-- dm_rooms
CREATE POLICY "Users can view their own dm_rooms" ON public.dm_rooms
    FOR SELECT USING (public.is_dm_room_member(id));

-- dm_room_members
CREATE POLICY "Users can view room members of their rooms" ON public.dm_room_members
    FOR SELECT USING (public.is_dm_room_member(room_id));

-- dm_messages
CREATE POLICY "Users can read messages in their rooms" ON public.dm_messages
    FOR SELECT USING (public.is_dm_room_member(room_id));

CREATE POLICY "Users can insert messages in their rooms" ON public.dm_messages
    FOR INSERT WITH CHECK (
        public.is_dm_room_member(room_id)
        AND sender_id = auth.uid()
    );
