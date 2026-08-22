-- ============================================================
-- Migration: 20260831100000_full_data_transfer_and_cleanup_resba
-- 1. 使われなくなった指名型レスバ（自分宛て招待）関連の関数・トリガー・カラムのクリーンアップ
-- 2. データ引き継ぎ機能の完全移行（プロフィール・投稿・DM・オプチャ・フォロー・対戦履歴等の全データ引き継ぎ）
-- 3. 引き継ぎ開始時の待機中レスバ応募・募集の自動キャンセル処理
-- ============================================================

-- ---------- 1. 指名型レスバ関連の不要関数・トリガーの削除 ----------
DROP TRIGGER IF EXISTS trg_notify_resba_invite ON public.battle_invites;
DROP FUNCTION IF EXISTS public.notify_resba_invite();
DROP TRIGGER IF EXISTS trg_notify_resba_declined ON public.battle_invites;
DROP FUNCTION IF EXISTS public.notify_resba_declined();
DROP FUNCTION IF EXISTS public.respond_resba(uuid, uuid, boolean);

-- battle_invites から target_user_id カラムと関連インデックスを削除
DROP INDEX IF EXISTS public.battle_invites_target_status_idx;
ALTER TABLE public.battle_invites DROP COLUMN IF EXISTS target_user_id CASCADE;

-- ---------- 2. レスバ取得系RPCの最適化（target_user_id / is_target を排除） ----------
CREATE OR REPLACE FUNCTION public.get_resba(
  p_attach_type text,
  p_attach_id   uuid,
  p_user_id     uuid
)
  RETURNS json
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_result json;
BEGIN
  SELECT COALESCE(json_agg(json_build_object(
      'id', b.id,
      'sender_id', b.sender_id,
      'sender_name', u.name,
      'sender_avatar', u.avatar_url,
      'sender_trophy', u.trophy,
      'attach_type', b.attach_type,
      'attach_id', b.attach_id,
      'theme', b.theme,
      'choice1', b.choice1,
      'choice2', b.choice2,
      'status', b.status,
      'responder_id', b.responder_id,
      'battle_room_id', b.battle_room_id,
      'created_at', b.created_at,
      'responded_at', b.responded_at,
      'is_sender', (b.sender_id = p_user_id),
      'my_application', (
        SELECT a.status FROM battle_invite_applications a
         WHERE a.invite_id = b.id AND a.applicant_id = p_user_id
         ORDER BY a.created_at DESC LIMIT 1
      ),
      'first_application', (
        CASE WHEN b.sender_id = p_user_id THEN (
          SELECT json_build_object(
            'id', a.id,
            'applicant_id', a.applicant_id,
            'applicant_name', au.name,
            'applicant_avatar', au.avatar_url,
            'applicant_trophy', au.trophy
          )
          FROM battle_invite_applications a
          LEFT JOIN users au ON au.id = a.applicant_id
          WHERE a.invite_id = b.id AND a.status = 'pending'
          ORDER BY a.created_at ASC LIMIT 1
        ) ELSE NULL END
      )
    ) ORDER BY b.created_at DESC), '[]'::json) INTO v_result
  FROM battle_invites b
  LEFT JOIN users u ON u.id = b.sender_id
  WHERE b.attach_type = p_attach_type AND b.attach_id = p_attach_id;

  RETURN v_result;
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_recruit_resbas(p_user_id uuid)
  RETURNS json
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_result json;
BEGIN
  SELECT COALESCE(json_agg(json_build_object(
      'id', b.id,
      'sender_id', b.sender_id,
      'sender_name', u.name,
      'sender_avatar', u.avatar_url,
      'sender_trophy', u.trophy,
      'attach_type', b.attach_type,
      'attach_id', b.attach_id,
      'theme', b.theme,
      'choice1', b.choice1,
      'choice2', b.choice2,
      'status', b.status,
      'responder_id', b.responder_id,
      'battle_room_id', b.battle_room_id,
      'created_at', b.created_at,
      'responded_at', b.responded_at,
      'is_sender', (b.sender_id = p_user_id),
      'my_application', (
        SELECT a.status FROM battle_invite_applications a
         WHERE a.invite_id = b.id AND a.applicant_id = p_user_id
         ORDER BY a.created_at DESC LIMIT 1
      ),
      'first_application', (
        CASE WHEN b.sender_id = p_user_id THEN (
          SELECT json_build_object(
            'id', a.id,
            'applicant_id', a.applicant_id,
            'applicant_name', au.name,
            'applicant_avatar', au.avatar_url,
            'applicant_trophy', au.trophy
          )
          FROM battle_invite_applications a
          LEFT JOIN users au ON au.id = a.applicant_id
          WHERE a.invite_id = b.id AND a.status = 'pending'
          ORDER BY a.created_at ASC LIMIT 1
        ) ELSE NULL END
      )
    ) ORDER BY b.created_at DESC), '[]'::json) INTO v_result
  FROM battle_invites b
  LEFT JOIN users u ON u.id = b.sender_id
  WHERE b.attach_type = 'recruit' AND b.status = 'pending';

  RETURN v_result;
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_my_resba_status(p_user_id uuid)
  RETURNS json
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_state     text;
  v_pending_sender int;
  v_pending_app     int;
  v_battle_room_id  uuid;
BEGIN
  -- 対戦中（rooms_v2 進行中）が最優先
  SELECT id INTO v_battle_room_id FROM rooms_v2
   WHERE (player1_id = p_user_id OR player2_id = p_user_id) AND winner IS NULL
   LIMIT 1;
  IF v_battle_room_id IS NOT NULL THEN
    RETURN json_build_object('state', 'battle', 'battle_room_id', v_battle_room_id);
  END IF;

  SELECT count(*) INTO v_pending_sender FROM battle_invites
   WHERE sender_id = p_user_id AND status = 'pending';
  SELECT count(*) INTO v_pending_app FROM battle_invite_applications
   WHERE applicant_id = p_user_id AND status = 'pending';

  IF v_pending_sender > 0 THEN
    v_state := 'proposing';
  ELSIF v_pending_app > 0 THEN
    v_state := 'applying';
  ELSE
    v_state := 'free';
  END IF;

  RETURN json_build_object(
    'state', v_state,
    'pending_sender_count', v_pending_sender,
    'pending_application_count', v_pending_app,
    'pending_target_count', 0
  );
END;
$function$;

-- ---------- 3. 引き継ぎ開始処理の拡張（待機中レスバの自動キャンセル） ----------
CREATE OR REPLACE FUNCTION public.initiate_data_transfer(p_sender_id uuid)
  RETURNS TABLE(transfer_id text, transfer_password text)
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
    v_transfer_id text;
    v_transfer_password text;
    v_delete_at timestamp with time zone;
BEGIN
    -- 1. 既存の未完了移行要求があれば削除
    DELETE FROM public.transfer
    WHERE send_id = p_sender_id
      AND receive_id IS NULL;

    -- 2. 待機中のレスバ募集・応募をすべて安全に自動キャンセル（ゴースト部屋・スタック防止）
    -- 自分がホストしている未成立のレスバ募集をキャンセル
    UPDATE public.battle_invites
    SET status = 'cancelled', updated_at = now()
    WHERE sender_id = p_sender_id AND status = 'pending';

    -- 自分が他人のレスバに応募している未承認の応募を取り下げ
    UPDATE public.battle_invite_applications
    SET status = 'cancelled', updated_at = now()
    WHERE applicant_id = p_sender_id AND status = 'pending';

    -- 未マッチの待機部屋（rooms_v2）を削除
    DELETE FROM public.rooms_v2
    WHERE player1_id = p_sender_id AND is_matched = false;

    -- 3. 新しい移行IDとパスワードを生成
    v_transfer_id := generate_random_id(6);
    v_transfer_password := generate_random_id(6);
    v_delete_at := now() + interval '1 hour';

    -- 4. ユーザーのステータスをfalseに設定（移行待機状態）
    UPDATE public.users
    SET status = false
    WHERE id = p_sender_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'User not found or status could not be updated for user_id: %', p_sender_id;
    END IF;

    -- 5. transferテーブルに新しいレコードを挿入
    INSERT INTO public.transfer (id, send_id, password, delete_at)
    VALUES (v_transfer_id, p_sender_id, v_transfer_password, v_delete_at);

    RETURN QUERY SELECT v_transfer_id, v_transfer_password;
EXCEPTION
    WHEN OTHERS THEN
        RAISE INFO 'Error in initiate_data_transfer for sender_id %: %', p_sender_id, SQLERRM;
        RAISE;
END;
$function$;

-- ---------- 4. 引き継ぎ完了処理の拡張（全データ完全移行） ----------
CREATE OR REPLACE FUNCTION public.complete_data_transfer_v2(
  p_transfer_id text,
  p_password    text,
  p_receiver_id uuid
)
  RETURNS text
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
    v_transfer_record public.transfer%ROWTYPE;
    v_sender_user_data public.users%ROWTYPE;
    v_send_id uuid;
BEGIN
    -- 1. 移行情報の検証と取得
    SELECT * INTO v_transfer_record
    FROM public.transfer
    WHERE id = p_transfer_id
      AND password = p_password
      AND delete_at > now()
      AND receive_id IS NULL;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Invalid transfer ID, password, expired, or already used.';
    END IF;

    v_send_id := v_transfer_record.send_id;

    -- 同一アカウントへの引き継ぎ防止
    IF v_send_id = p_receiver_id THEN
        RAISE EXCEPTION 'Cannot transfer to the same account.';
    END IF;

    -- 2. 移行情報の更新（受取人を記録）
    UPDATE public.transfer SET receive_id = p_receiver_id WHERE id = v_transfer_record.id;

    -- 3. 送信者（移行元）のデータを取得
    SELECT * INTO v_sender_user_data FROM public.users WHERE id = v_send_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Sender user not found.';
    END IF;

    -- 4. 受信者（移行先）のプロフィール・戦績を更新（完全コピー）
    UPDATE public.users
    SET
        name = COALESCE(v_sender_user_data.name, name),
        avatar_url = v_sender_user_data.avatar_url,
        header_url = v_sender_user_data.header_url,
        bio = v_sender_user_data.bio,
        win = v_sender_user_data.win,
        lose = v_sender_user_data.lose,
        trophy = v_sender_user_data.trophy,
        created_at = v_sender_user_data.created_at,
        is_notification_enabled = v_sender_user_data.is_notification_enabled
    WHERE id = p_receiver_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Receiver user not found.';
    END IF;

    -- 5. 通知設定（notification_settings）を引き継ぐ
    INSERT INTO public.notification_settings (
        user_id, is_notification_enabled,
        like_enabled, comment_enabled, follow_enabled,
        dm_enabled, open_chat_enabled, match_waiting_enabled
    )
    SELECT
        p_receiver_id, ns.is_notification_enabled,
        ns.like_enabled, ns.comment_enabled, ns.follow_enabled,
        ns.dm_enabled, ns.open_chat_enabled, ns.match_waiting_enabled
    FROM public.notification_settings ns
    WHERE ns.user_id = v_send_id
    ON CONFLICT (user_id) DO UPDATE SET
        is_notification_enabled = EXCLUDED.is_notification_enabled,
        like_enabled = EXCLUDED.like_enabled,
        comment_enabled = EXCLUDED.comment_enabled,
        follow_enabled = EXCLUDED.follow_enabled,
        dm_enabled = EXCLUDED.dm_enabled,
        open_chat_enabled = EXCLUDED.open_chat_enabled,
        match_waiting_enabled = EXCLUDED.match_waiting_enabled,
        updated_at = now();

    -- 6. 掲示板（BBS）データの引き継ぎ
    -- 投稿・コメント
    UPDATE public.bbs_posts SET user_id = p_receiver_id WHERE user_id = v_send_id;
    UPDATE public.bbs_comments SET user_id = p_receiver_id WHERE user_id = v_send_id;
    -- いいね（重複回避して更新）
    DELETE FROM public.bbs_likes WHERE user_id = p_receiver_id AND post_id IN (SELECT post_id FROM public.bbs_likes WHERE user_id = v_send_id);
    UPDATE public.bbs_likes SET user_id = p_receiver_id WHERE user_id = v_send_id;
    -- コメントいいね（重複回避して更新）
    DELETE FROM public.bbs_comment_likes WHERE user_id = p_receiver_id AND comment_id IN (SELECT comment_id FROM public.bbs_comment_likes WHERE user_id = v_send_id);
    UPDATE public.bbs_comment_likes SET user_id = p_receiver_id WHERE user_id = v_send_id;

    -- 7. DMデータの引き継ぎ
    -- ルームメンバーシップ（重複回避して更新）
    DELETE FROM public.dm_room_members WHERE user_id = p_receiver_id AND room_id IN (SELECT room_id FROM public.dm_room_members WHERE user_id = v_send_id);
    UPDATE public.dm_room_members SET user_id = p_receiver_id WHERE user_id = v_send_id;
    -- メッセージ送信者
    UPDATE public.dm_messages SET sender_id = p_receiver_id WHERE sender_id = v_send_id;

    -- 8. オープンチャットデータの引き継ぎ
    -- オーナー権限
    UPDATE public.open_chat_rooms SET owner_id = p_receiver_id WHERE owner_id = v_send_id;
    -- メンバーシップ（重複回避して更新）
    DELETE FROM public.open_chat_members WHERE user_id = p_receiver_id AND room_id IN (SELECT room_id FROM public.open_chat_members WHERE user_id = v_send_id);
    UPDATE public.open_chat_members SET user_id = p_receiver_id WHERE user_id = v_send_id;
    -- メッセージ送信者
    UPDATE public.open_chat_messages SET user_id = p_receiver_id WHERE user_id = v_send_id;

    -- 9. フォロー関係の引き継ぎ
    -- 自分がフォローしている相手
    DELETE FROM public.user_follows WHERE follower_id = p_receiver_id AND followed_id IN (SELECT followed_id FROM public.user_follows WHERE follower_id = v_send_id);
    UPDATE public.user_follows SET follower_id = p_receiver_id WHERE follower_id = v_send_id AND followed_id <> p_receiver_id;
    -- 自分をフォローしている相手
    DELETE FROM public.user_follows WHERE followed_id = p_receiver_id AND follower_id IN (SELECT follower_id FROM public.user_follows WHERE followed_id = v_send_id);
    UPDATE public.user_follows SET followed_id = p_receiver_id WHERE followed_id = v_send_id AND follower_id <> p_receiver_id;
    -- 自己フォローのクリーンアップ
    DELETE FROM public.user_follows WHERE follower_id = followed_id;

    -- 10. ブロック関係の引き継ぎ
    -- 自分がブロックしている相手
    DELETE FROM public.brock_user WHERE user_id = p_receiver_id AND block_user_id IN (SELECT block_user_id FROM public.brock_user WHERE user_id = v_send_id);
    UPDATE public.brock_user SET user_id = p_receiver_id WHERE user_id = v_send_id AND block_user_id <> p_receiver_id;
    -- 自分をブロックしている相手
    DELETE FROM public.brock_user WHERE block_user_id = p_receiver_id AND user_id IN (SELECT user_id FROM public.brock_user WHERE block_user_id = v_send_id);
    UPDATE public.brock_user SET block_user_id = p_receiver_id WHERE block_user_id = v_send_id AND user_id <> p_receiver_id;
    -- 自己ブロックのクリーンアップ
    DELETE FROM public.brock_user WHERE user_id = block_user_id;

    -- 11. 対戦履歴・チャットログの引き継ぎ
    UPDATE public.match_record SET player1_id = p_receiver_id WHERE player1_id = v_send_id;
    UPDATE public.match_record SET player2_id = p_receiver_id WHERE player2_id = v_send_id;
    UPDATE public.match_record SET winner = p_receiver_id WHERE winner = v_send_id;
    UPDATE public.rooms_v2 SET player1_id = p_receiver_id WHERE player1_id = v_send_id;
    UPDATE public.rooms_v2 SET player2_id = p_receiver_id WHERE player2_id = v_send_id;
    UPDATE public.rooms_v2 SET winner_user_id = p_receiver_id WHERE winner_user_id = v_send_id;
    UPDATE public.messages SET sender_id = p_receiver_id WHERE sender_id = v_send_id;

    -- 12. 通知履歴の引き継ぎ
    UPDATE public.notifications SET user_id = p_receiver_id WHERE user_id = v_send_id;
    UPDATE public.notifications SET actor_id = p_receiver_id WHERE actor_id = v_send_id;

    -- 13. レスバ履歴の引き継ぎ
    -- 過去の完了済みレスバ
    UPDATE public.battle_invites SET sender_id = p_receiver_id WHERE sender_id = v_send_id;
    UPDATE public.battle_invites SET responder_id = p_receiver_id WHERE responder_id = v_send_id;
    UPDATE public.battle_invite_applications SET applicant_id = p_receiver_id WHERE applicant_id = v_send_id;

    -- 14. 送信者（移行元）のアカウントを初期化
    UPDATE public.users
    SET
        name = '退会済みユーザー',
        avatar_url = NULL,
        header_url = NULL,
        bio = NULL,
        win = 0,
        lose = 0,
        trophy = 0,
        status = true,
        created_at = now(),
        fcm_token = NULL,
        is_notification_enabled = false
    WHERE id = v_send_id;

    UPDATE public.notification_settings
    SET
        is_notification_enabled = false,
        like_enabled = false,
        comment_enabled = false,
        follow_enabled = false,
        dm_enabled = false,
        open_chat_enabled = false,
        match_waiting_enabled = false,
        updated_at = now()
    WHERE user_id = v_send_id;

    RETURN 'Data transfer completed successfully.';
EXCEPTION
    WHEN OTHERS THEN
        RAISE;
END;
$function$;

-- 権限付与
GRANT ALL ON FUNCTION public.get_resba(text, uuid, uuid) TO anon, authenticated, service_role;
GRANT ALL ON FUNCTION public.get_recruit_resbas(uuid) TO anon, authenticated, service_role;
GRANT ALL ON FUNCTION public.get_my_resba_status(uuid) TO anon, authenticated, service_role;
GRANT ALL ON FUNCTION public.initiate_data_transfer(uuid) TO anon, authenticated, service_role;
GRANT ALL ON FUNCTION public.complete_data_transfer_v2(text, text, uuid) TO anon, authenticated, service_role;
