-- ==========================================
-- オープンチャットメッセージの論理削除 (ソフトデリート)
-- ==========================================

-- 1. is_deleted カラムの追加
ALTER TABLE public.open_chat_messages 
ADD COLUMN IF NOT EXISTS is_deleted boolean DEFAULT false NOT NULL;

-- 2. メッセージ論理削除用RPC関数
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

  -- 1. 送信者本人であるか確認
  IF v_msg.user_id = v_user_id THEN
    UPDATE public.open_chat_messages
    SET is_deleted = true
    WHERE id = p_message_id;

    RETURN json_build_object('success', true);
  END IF;

  -- 2. ルームのオーナーまたは副官(管理者)であるか確認
  SELECT (
    EXISTS (
      SELECT 1 FROM public.open_chat_rooms r
      WHERE r.id = v_msg.room_id AND r.owner_id = v_user_id
    ) OR EXISTS (
      SELECT 1 FROM public.open_chat_members m
      WHERE m.room_id = v_msg.room_id AND m.user_id = v_user_id AND m.role = 'admin'
    )
  ) INTO v_is_admin;

  IF v_is_admin THEN
    UPDATE public.open_chat_messages
    SET is_deleted = true
    WHERE id = p_message_id;

    RETURN json_build_object('success', true);
  ELSE
    RETURN json_build_object('success', false, 'error', 'PERMISSION_DENIED');
  END IF;
END;
$$;

-- 3. RLS ポリシー (UPDATE許可)
CREATE POLICY "送信者または管理者はメッセージを論理削除可能" ON public.open_chat_messages
FOR UPDATE USING (
  auth.uid() = user_id
  OR EXISTS (
    SELECT 1 FROM public.open_chat_rooms r
    WHERE r.id = open_chat_messages.room_id AND r.owner_id = auth.uid()
  )
  OR EXISTS (
    SELECT 1 FROM public.open_chat_members m
    WHERE m.room_id = open_chat_messages.room_id AND m.user_id = auth.uid() AND m.role = 'admin'
  )
);
