-- 1. トークンの重複を自動で解消する関数の作成
CREATE OR REPLACE FUNCTION public.handle_fcm_token_uniqueness()
RETURNS TRIGGER AS $$
BEGIN
  -- もし新しいトークンがセットされ、かつNULLでない場合
  IF (NEW.fcm_token IS NOT NULL) AND (OLD.fcm_token IS DISTINCT FROM NEW.fcm_token) THEN
    -- 他のユーザーが同じトークンを持っていたら、そのユーザーのトークンをNULLにして解除する
    UPDATE public.users 
    SET fcm_token = NULL 
    WHERE fcm_token = NEW.fcm_token 
    AND id != NEW.id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 2. usersテーブルにトリガーを設定 (fcm_tokenの更新前に実行)
DROP TRIGGER IF EXISTS tr_fcm_token_uniqueness ON public.users;
CREATE TRIGGER tr_fcm_token_uniqueness
BEFORE UPDATE OF fcm_token ON public.users
FOR EACH ROW
EXECUTE FUNCTION public.handle_fcm_token_uniqueness();

-- 3. データ移行関数の修正（設定の引き継ぎとクリーンアップを追加）
CREATE OR REPLACE FUNCTION "public"."complete_data_transfer"("p_transfer_id" "text", "p_password" "text", "p_receiver_id" "uuid") RETURNS "text"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$DECLARE
    v_transfer_record public.transfer%ROWTYPE;
    v_sender_user_data public.users%ROWTYPE;
BEGIN
    -- 移行情報を取得
    SELECT * INTO v_transfer_record
    FROM public.transfer
    WHERE id = p_transfer_id
      AND password = p_password
      AND delete_at > now()
      AND receive_id IS NULL;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Invalid transfer ID, password, expired, or already used.';
    END IF;

    -- 移行情報の更新
    UPDATE public.transfer SET receive_id = p_receiver_id WHERE id = v_transfer_record.id;

    -- 送信者（移行元）のデータを取得
    SELECT * INTO v_sender_user_data FROM public.users WHERE id = v_transfer_record.send_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Sender user not found.';
    END IF;

    -- 受信者（移行先）を更新：通知設定 (is_notification_enabled) も引き継ぐ
    UPDATE public.users
    SET
        win = v_sender_user_data.win,
        lose = v_sender_user_data.lose,
        trophy = v_sender_user_data.trophy,
        created_at = v_sender_user_data.created_at,
        is_notification_enabled = v_sender_user_data.is_notification_enabled -- ★追加：通知設定の引き継ぎ
    WHERE id = p_receiver_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Receiver user not found.';
    END IF;

    -- 送信者（移行元）を初期化：通知関連も完全にリセットしてクリーンにする
    UPDATE public.users
    SET
        win = 0,
        lose = 0,
        trophy = 0,
        status = true,
        created_at = now(),
        fcm_token = NULL,               -- ★追加：通知IDを削除
        is_notification_enabled = false -- ★追加：通知設定をOFFに
    WHERE id = v_transfer_record.send_id;

    RETURN 'Data transfer completed successfully.';

EXCEPTION
    WHEN OTHERS THEN
        RAISE;
END;$$;
