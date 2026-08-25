-- ==============================================================================
-- マイグレーション: 削除ログを削除対象メッセージの位置に表示する
--   delete_open_chat_message:
--   削除ログ(is_system)の created_at を、削除された元メッセージの created_at に
--   揃えて挿入する。これにより、チャットは created_at 降順(最新→最古)で整列されるため、
--   「〇〇がメッセージを削除しました / 〇〇が〇〇のメッセージを削除しました」のログが
--   いつまで経っても一番下(最新)に流れず、削除されたメッセージがあった位置に表示される。
--   対象メッセージ自体はクライアント側で非表示(SizedBox.shrink)となるため、表示上
--   同じ位置にログが残る。
--   ※作成当初は created_at を省略しており DEFAULT now()(=削除時刻)が入っていたため、
--     ログが常に最新位置(一番下)に表示されてしまう問題があった。
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
  v_owner_name text;
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

    -- 削除ログをチャットに残す（元メッセージと同じ created_at で、元位置に表示されるようにする）
    INSERT INTO public.open_chat_messages (room_id, user_id, content, is_system, created_at)
    VALUES (
      v_msg.room_id,
      v_user_id,
      v_deleter_name || 'がメッセージを削除しました',
      true,
      v_msg.created_at
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
    -- 対象メッセージの投稿者名を取得 (「〇〇が〇〇のメッセージを削除しました」用)
    SELECT COALESCE(name, '名無しユーザー') INTO v_owner_name
    FROM public.users WHERE id = v_msg.user_id;

    UPDATE public.open_chat_messages
    SET is_deleted = true,
        is_admin_deleted = true
    WHERE id = p_message_id;

    -- 削除ログをチャットに残す（削除者と投稿者の両方が分かる文言にする。元位置に表示）
    INSERT INTO public.open_chat_messages (room_id, user_id, content, is_system, created_at)
    VALUES (
      v_msg.room_id,
      v_user_id,
      v_deleter_name || 'が' || v_owner_name || 'のメッセージを削除しました',
      true,
      v_msg.created_at
    );

    RETURN json_build_object('success', true, 'is_admin_deleted', true);
  ELSE
    RETURN json_build_object('success', false, 'error', 'PERMISSION_DENIED');
  END IF;
END;
$$;
