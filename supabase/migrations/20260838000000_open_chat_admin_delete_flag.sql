-- ==========================================
-- オープンチャットメッセージの管理者削除フラグ追加
-- ==========================================

-- 1. is_admin_deleted カラムの追加
ALTER TABLE public.open_chat_messages 
ADD COLUMN IF NOT EXISTS is_admin_deleted boolean DEFAULT false NOT NULL;

-- 2. メッセージ論理削除用RPC関数の更新
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

  -- 2. ルームのオーナーまたは副官(管理者)であるか確認（管理者による強制削除）
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
    SET is_deleted = true,
        is_admin_deleted = true
    WHERE id = p_message_id;

    RETURN json_build_object('success', true, 'is_admin_deleted', true);
  ELSE
    RETURN json_build_object('success', false, 'error', 'PERMISSION_DENIED');
  END IF;
END;
$$;
