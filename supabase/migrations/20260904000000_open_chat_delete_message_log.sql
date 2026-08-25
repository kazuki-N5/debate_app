-- ==============================================================================
-- マイグレーション: メッセージ削除ログの投稿
--   delete_open_chat_message: 本人削除・管理者強制削除のどちらでも
--   「〇〇がメッセージを削除しました」ログ(is_system)をチャットに残す
--   削除されたメッセージ自体の表示はクライアント側で「メッセージは削除されました」
--   (名前なし)に統一するため、DB側で変更は不要
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
  v_deleter_name text;
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

  -- 削除者名を取得 (ログ用)
  SELECT COALESCE(name, '名無しユーザー') INTO v_deleter_name
  FROM public.users WHERE id = v_user_id;

  -- 1. 送信者本人であるか確認（本人の送信取り消し / 削除）
  IF v_msg.user_id = v_user_id THEN
    UPDATE public.open_chat_messages
    SET is_deleted = true,
        is_admin_deleted = false
    WHERE id = p_message_id;

    -- 削除ログをチャットに残す
    INSERT INTO public.open_chat_messages (room_id, user_id, content, is_system)
    VALUES (
      v_msg.room_id,
      v_user_id,
      v_deleter_name || 'がメッセージを削除しました',
      true
    );

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

    -- 削除ログをチャットに残す
    INSERT INTO public.open_chat_messages (room_id, user_id, content, is_system)
    VALUES (
      v_msg.room_id,
      v_user_id,
      v_deleter_name || 'がメッセージを削除しました',
      true
    );

    RETURN json_build_object('success', true, 'is_admin_deleted', true);
  ELSE
    RETURN json_build_object('success', false, 'error', 'PERMISSION_DENIED');
  END IF;
END;
$$;