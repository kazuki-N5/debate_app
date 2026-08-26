-- Migration unit 1: schema_changes
-- Transaction mode: transactional
-- Boundary reason: default

SET check_function_bodies = false;

CREATE OR REPLACE FUNCTION public.complete_data_transfer_v2 (
  p_transfer_id text,
  p_password    text,
  p_receiver_id uuid
)
  RETURNS text
  LANGUAGE plpgsql
  SECURITY DEFINER
  AS $function$DECLARE
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
    -- 受信者（移行先）を更新
    UPDATE public.users
    SET
        win = v_sender_user_data.win,
        lose = v_sender_user_data.lose,
        trophy = v_sender_user_data.trophy,
        created_at = v_sender_user_data.created_at
    WHERE id = p_receiver_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Receiver user not found.';
    END IF;
    -- 通知設定（マスター + カテゴリ）を引き継ぐ
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
    WHERE ns.user_id = v_transfer_record.send_id
    ON CONFLICT (user_id) DO UPDATE SET
        is_notification_enabled = EXCLUDED.is_notification_enabled,
        like_enabled = EXCLUDED.like_enabled,
        comment_enabled = EXCLUDED.comment_enabled,
        follow_enabled = EXCLUDED.follow_enabled,
        dm_enabled = EXCLUDED.dm_enabled,
        open_chat_enabled = EXCLUDED.open_chat_enabled,
        match_waiting_enabled = EXCLUDED.match_waiting_enabled,
        updated_at = now();
    -- 送信者（移行元）を初期化：通知関連もリセット
    UPDATE public.users
    SET
        win = 0,
        lose = 0,
        trophy = 0,
        status = true,
        created_at = now(),
        fcm_token = NULL                -- ★通知IDを削除
    WHERE id = v_transfer_record.send_id;
    UPDATE public.notification_settings
    SET is_notification_enabled = false -- ★マスターをOFFに
    WHERE user_id = v_transfer_record.send_id;
    RETURN 'Data transfer completed successfully.';
EXCEPTION
    WHEN OTHERS THEN
        RAISE;
END;$function$;

CREATE OR REPLACE FUNCTION public.create_open_chat_room (
  p_name           text,
  p_description    text,
  p_icon_url       text,
  p_background_url text DEFAULT NULL::text,
  p_password       text DEFAULT NULL::text
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  AS $function$
DECLARE
    v_room_id UUID;
    v_user_id UUID;
BEGIN
    -- 現在のユーザーIDを取得
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', '認証されていません');
    END IF;

    -- ルームの作成
    INSERT INTO open_chat_rooms (name, description, icon_url, background_url, password, owner_id)
    VALUES (p_name, p_description, p_icon_url, p_background_url, p_password, v_user_id)
    RETURNING id INTO v_room_id;

    -- 作成者をメンバーとして追加 (Admin role に修正)
    INSERT INTO open_chat_members (room_id, user_id, role)
    VALUES (v_room_id, v_user_id, 'admin');

    RETURN jsonb_build_object('success', true, 'room_id', v_room_id);
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$function$;

CREATE OR REPLACE FUNCTION public.decrement_comment_likes_count (
  p_comment_id uuid
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  AS $function$
BEGIN
  UPDATE bbs_comments SET likes_count = GREATEST(COALESCE(likes_count, 0) - 1, 0) WHERE id = p_comment_id;
END;
$function$;

CREATE OR REPLACE FUNCTION public.decrement_likes_count (
  post_id uuid
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  AS $function$
BEGIN
  UPDATE bbs_posts SET likes_count = GREATEST(COALESCE(likes_count, 0) - 1, 0) WHERE id = post_id;
END;
$function$;

CREATE FUNCTION public.get_bbs_comments_with_status (
  p_post_id uuid,
  p_user_id uuid
)
  RETURNS TABLE (
    id                uuid,
    post_id           uuid,
    user_id           uuid,
    parent_comment_id uuid,
    content           text,
    created_at        timestamp with time zone,
    likes_count       integer,
    image_url         text,
    users             json,
    is_liked_by_me    boolean
  )
  LANGUAGE plpgsql
  AS $function$
BEGIN
  RETURN QUERY
  SELECT 
    c.id,
    c.post_id,
    c.user_id,
    c.parent_comment_id,
    c.content,
    c.created_at,
    c.likes_count,
    c.image_url, -- 追加
    row_to_json(u) AS users,
    EXISTS(SELECT 1 FROM bbs_comment_likes cl WHERE cl.comment_id = c.id AND cl.user_id = p_user_id) AS is_liked_by_me
  FROM bbs_comments c
  LEFT JOIN users u ON u.id = c.user_id
  WHERE c.post_id = p_post_id
  ORDER BY c.created_at ASC;
END;
$function$;

GRANT ALL ON FUNCTION public.get_bbs_comments_with_status(uuid, uuid) TO anon;

GRANT ALL ON FUNCTION public.get_bbs_comments_with_status(uuid, uuid) TO authenticated;

GRANT ALL ON FUNCTION public.get_bbs_comments_with_status(uuid, uuid) TO service_role;

CREATE FUNCTION public.get_bbs_posts_with_status (
  p_user_id uuid,
  p_limit   integer DEFAULT 50
)
  RETURNS TABLE (
    id             uuid,
    user_id        uuid,
    content        text,
    created_at     timestamp with time zone,
    likes_count    integer,
    replies_count  integer,
    image_urls     text[],
    users          json,
    is_liked_by_me boolean
  )
  LANGUAGE plpgsql
  AS $function$
BEGIN
  RETURN QUERY
  SELECT 
    p.id,
    p.user_id,
    p.content,
    p.created_at,
    p.likes_count,
    p.replies_count,
    p.image_urls, -- 追加
    row_to_json(u) AS users,
    EXISTS(SELECT 1 FROM bbs_likes l WHERE l.post_id = p.id AND l.user_id = p_user_id) AS is_liked_by_me
  FROM bbs_posts p
  LEFT JOIN users u ON u.id = p.user_id
  ORDER BY p.created_at DESC
  LIMIT p_limit;
END;
$function$;

GRANT ALL ON FUNCTION public.get_bbs_posts_with_status(uuid, integer) TO anon;

GRANT ALL ON FUNCTION public.get_bbs_posts_with_status(uuid, integer) TO authenticated;

GRANT ALL ON FUNCTION public.get_bbs_posts_with_status(uuid, integer) TO service_role;

CREATE FUNCTION public.get_dm_inbox (
  p_user_id uuid
)
  RETURNS TABLE (
    room_id          uuid,
    other_user_id    uuid,
    other_user_name  text,
    other_avatar_url text,
    last_message     text,
    last_message_at  timestamp with time zone,
    unread_count     bigint
  )
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
BEGIN
    IF p_user_id IS DISTINCT FROM auth.uid() THEN
        RAISE EXCEPTION 'Not allowed';
    END IF;
    RETURN QUERY
        SELECT
            m.room_id,
            MAX(CASE WHEN mm.user_id <> p_user_id THEN mm.user_id END),
            MAX(CASE WHEN mm.user_id <> p_user_id THEN u.name END),
            MAX(CASE WHEN mm.user_id <> p_user_id THEN u.avatar_url END),
            (SELECT x.content FROM public.dm_messages x
              WHERE x.room_id = m.room_id ORDER BY x.created_at DESC LIMIT 1),
            (SELECT x.created_at FROM public.dm_messages x
              WHERE x.room_id = m.room_id ORDER BY x.created_at DESC LIMIT 1),
            (SELECT count(*) FROM public.dm_messages x
              WHERE x.room_id = m.room_id AND x.sender_id <> p_user_id
                AND x.created_at > COALESCE(
                    (SELECT lr.last_read_at FROM public.dm_room_members lr
                     WHERE lr.room_id = m.room_id AND lr.user_id = p_user_id),
                    '-infinity'::timestamptz))
        FROM public.dm_room_members m
        JOIN public.dm_room_members mm ON mm.room_id = m.room_id AND mm.user_id <> p_user_id
        LEFT JOIN public.users u ON u.id = mm.user_id
        WHERE m.user_id = p_user_id
        GROUP BY m.room_id;
END $function$;

GRANT ALL ON FUNCTION public.get_dm_inbox(uuid) TO anon;

GRANT ALL ON FUNCTION public.get_dm_inbox(uuid) TO authenticated;

GRANT ALL ON FUNCTION public.get_dm_inbox(uuid) TO service_role;

CREATE FUNCTION public.get_open_chat_inbox (
  p_user_id uuid
)
  RETURNS TABLE (
    room                   jsonb,
    last_message           text,
    last_message_user_name text,
    last_message_at        timestamp with time zone,
    unread_count           bigint
  )
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
BEGIN
    IF p_user_id IS DISTINCT FROM auth.uid() THEN
        RAISE EXCEPTION 'Not allowed';
    END IF;
    RETURN QUERY
        SELECT
            to_jsonb(ocr.*),
            x.content,
            xu.name,
            x.created_at,
            (SELECT count(*) FROM public.open_chat_messages ocmsg
              WHERE ocmsg.room_id = ocr.id AND ocmsg.user_id <> p_user_id
                AND ocmsg.created_at > COALESCE(
                    (SELECT lr.last_read_at FROM public.open_chat_members lr
                     WHERE lr.room_id = ocr.id AND lr.user_id = p_user_id),
                    '-infinity'::timestamptz))
        FROM public.open_chat_rooms ocr
        LEFT JOIN LATERAL (
            SELECT content, user_id, created_at
            FROM public.open_chat_messages
            WHERE room_id = ocr.id
            ORDER BY created_at DESC LIMIT 1
        ) x ON true
        LEFT JOIN public.users xu ON xu.id = x.user_id
        WHERE EXISTS (
            SELECT 1 FROM public.open_chat_members ocm
            WHERE ocm.room_id = ocr.id AND ocm.user_id = p_user_id
        );
END $function$;

GRANT ALL ON FUNCTION public.get_open_chat_inbox(uuid) TO anon;

GRANT ALL ON FUNCTION public.get_open_chat_inbox(uuid) TO authenticated;

GRANT ALL ON FUNCTION public.get_open_chat_inbox(uuid) TO service_role;

CREATE FUNCTION public.handle_new_notification_settings()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
BEGIN
    INSERT INTO public.notification_settings (user_id) VALUES (NEW.id) ON CONFLICT DO NOTHING;
    RETURN NEW;
END $function$;

GRANT ALL ON FUNCTION public.handle_new_notification_settings() TO anon;

GRANT ALL ON FUNCTION public.handle_new_notification_settings() TO authenticated;

GRANT ALL ON FUNCTION public.handle_new_notification_settings() TO service_role;

CREATE OR REPLACE FUNCTION public.increment_replies_count (
  p_post_id uuid
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  AS $function$
BEGIN
  UPDATE bbs_posts SET replies_count = COALESCE(replies_count, 0) + 1 WHERE id = p_post_id;
END;
$function$;

CREATE FUNCTION public.mark_dm_room_read (
  p_room_id uuid
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
BEGIN
    IF NOT public.is_dm_room_member(p_room_id) THEN
        RAISE EXCEPTION 'Not a member of this room';
    END IF;
    UPDATE public.dm_room_members
    SET last_read_at = now()
    WHERE room_id = p_room_id AND user_id = auth.uid();
END $function$;

GRANT ALL ON FUNCTION public.mark_dm_room_read(uuid) TO anon;

GRANT ALL ON FUNCTION public.mark_dm_room_read(uuid) TO authenticated;

GRANT ALL ON FUNCTION public.mark_dm_room_read(uuid) TO service_role;

CREATE FUNCTION public.mark_open_chat_room_read (
  p_room_id uuid
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
BEGIN
    UPDATE public.open_chat_members
    SET last_read_at = now()
    WHERE room_id = p_room_id AND user_id = auth.uid();
END $function$;

GRANT ALL ON FUNCTION public.mark_open_chat_room_read(uuid) TO anon;

GRANT ALL ON FUNCTION public.mark_open_chat_room_read(uuid) TO authenticated;

GRANT ALL ON FUNCTION public.mark_open_chat_room_read(uuid) TO service_role;

CREATE FUNCTION public.notify_bbs_comment_like()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE v_owner UUID; v_post_id UUID; v_batch_id UUID; v_actors UUID[]; v_is_new BOOLEAN;
BEGIN
    SELECT user_id, post_id INTO v_owner, v_post_id
    FROM public.bbs_comments WHERE id = NEW.comment_id;
    IF v_owner IS NOT NULL AND v_owner <> NEW.user_id THEN
        -- 最新の「未読」バッチを探す
        SELECT id, actor_ids INTO v_batch_id, v_actors
        FROM public.notifications
        WHERE user_id = v_owner AND type = 'like_comment' AND comment_id = NEW.comment_id
          AND is_read = false
        ORDER BY created_at DESC LIMIT 1;

        IF v_batch_id IS NULL THEN
            -- 初回 or 前バッチが既読 → 新しいバッチ行 (count=1)
            INSERT INTO public.notifications (user_id, actor_id, type, post_id, comment_id, count, actor_ids)
            VALUES (v_owner, NEW.user_id, 'like_comment', v_post_id, NEW.comment_id, 1, ARRAY[NEW.user_id]);
            v_is_new := true;
        ELSIF NOT (NEW.user_id = ANY(v_actors)) THEN
            -- 未読バッチに追加
            UPDATE public.notifications
            SET count = count + 1,
                actor_ids = actor_ids || NEW.user_id,
                actor_id = NEW.user_id,
                created_at = now()
            WHERE id = v_batch_id;
            v_is_new := true;
        ELSE
            -- 同じ人からの再いいね → 件数もFCMも送らない (連打スパム防止)
            v_is_new := false;
        END IF;

        -- FCMプッシュ通知: 新規いいねのみ送信
        IF v_is_new THEN
            PERFORM net.http_post(
                url := 'https://ljgvqdcailabzuutaeha.supabase.co/functions/v1/notify_trigger',
                headers := jsonb_build_object(
                    'Content-Type', 'application/json',
                    'x-notify-secret', '4a5d3df69e9baa4456e120a8b1fc45c924730ded80c03fe7b3872b2693847d73'
                ),
                body := jsonb_build_object(
                    'user_id', v_owner,
                    'type', 'like_comment',
                    'actor_name', (SELECT name FROM public.users WHERE id = NEW.user_id)
                )
            );
        END IF;
    END IF;
    RETURN NEW;
END $function$;

GRANT ALL ON FUNCTION public.notify_bbs_comment_like() TO anon;

GRANT ALL ON FUNCTION public.notify_bbs_comment_like() TO authenticated;

GRANT ALL ON FUNCTION public.notify_bbs_comment_like() TO service_role;

CREATE FUNCTION public.notify_bbs_post_like()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE v_owner UUID; v_batch_id UUID; v_actors UUID[]; v_is_new BOOLEAN;
BEGIN
    SELECT user_id INTO v_owner FROM public.bbs_posts WHERE id = NEW.post_id;
    IF v_owner IS NOT NULL AND v_owner <> NEW.user_id THEN
        -- 最新の「未読」バッチを探す (既読になったら次のいいねで新しいバッチ行になる)
        SELECT id, actor_ids INTO v_batch_id, v_actors
        FROM public.notifications
        WHERE user_id = v_owner AND type = 'like_post' AND post_id = NEW.post_id
          AND is_read = false
        ORDER BY created_at DESC LIMIT 1;

        IF v_batch_id IS NULL THEN
            -- 初回 or 前バッチが既読 → 新しいバッチ行 (count=1)
            INSERT INTO public.notifications (user_id, actor_id, type, post_id, count, actor_ids)
            VALUES (v_owner, NEW.user_id, 'like_post', NEW.post_id, 1, ARRAY[NEW.user_id]);
            v_is_new := true;
        ELSIF NOT (NEW.user_id = ANY(v_actors)) THEN
            -- 未読バッチに追加 (件数+1・最新のいいね主を actor に・一覧先頭へ)
            UPDATE public.notifications
            SET count = count + 1,
                actor_ids = actor_ids || NEW.user_id,
                actor_id = NEW.user_id,
                created_at = now()
            WHERE id = v_batch_id;
            v_is_new := true;
        ELSE
            -- 同じ人からの再いいね → 件数もFCMも送らない (連打スパム防止)
            v_is_new := false;
        END IF;

        -- FCMプッシュ通知: 新規いいねのみ送信
        -- (URL は環境に合わせて置換。NOTIFY_SECRET 未設定なら x-notify-secret ヘッダー行を削除)
        IF v_is_new THEN
            PERFORM net.http_post(
                url := 'https://ljgvqdcailabzuutaeha.supabase.co/functions/v1/notify_trigger',
                headers := jsonb_build_object(
                    'Content-Type', 'application/json',
                    'x-notify-secret', '4a5d3df69e9baa4456e120a8b1fc45c924730ded80c03fe7b3872b2693847d73'
                ),
                body := jsonb_build_object(
                    'user_id', v_owner,
                    'type', 'like_post',
                    'actor_name', (SELECT name FROM public.users WHERE id = NEW.user_id)
                )
            );
        END IF;
    END IF;
    RETURN NEW;
END $function$;

GRANT ALL ON FUNCTION public.notify_bbs_post_like() TO anon;

GRANT ALL ON FUNCTION public.notify_bbs_post_like() TO authenticated;

GRANT ALL ON FUNCTION public.notify_bbs_post_like() TO service_role;

CREATE FUNCTION public.notify_comment_reply()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE v_target_owner UUID; v_post_id UUID;
BEGIN
    IF NEW.parent_comment_id IS NOT NULL THEN
        -- 返信: 親コメントの作者に通知
        SELECT user_id, post_id INTO v_target_owner, v_post_id
        FROM public.bbs_comments WHERE id = NEW.parent_comment_id;
        IF v_target_owner IS NOT NULL AND v_target_owner <> NEW.user_id THEN
            INSERT INTO public.notifications (user_id, actor_id, type, post_id, comment_id)
            VALUES (v_target_owner, NEW.user_id, 'reply_comment', v_post_id, NEW.id);

            -- FCMプッシュ通知: Edge Function を呼び出し
            PERFORM net.http_post(
                url := 'https://ljgvqdcailabzuutaeha.supabase.co/functions/v1/notify_trigger',
                headers := jsonb_build_object(
                    'Content-Type', 'application/json',
                    'x-notify-secret', '4a5d3df69e9baa4456e120a8b1fc45c924730ded80c03fe7b3872b2693847d73'
                ),
                body := jsonb_build_object(
                    'user_id', v_target_owner,
                    'type', 'reply_comment',
                    'actor_name', (SELECT name FROM public.users WHERE id = NEW.user_id)
                )
            );
        END IF;
    ELSE
        -- トップレベルコメント: ポストの作者に通知
        SELECT user_id INTO v_target_owner FROM public.bbs_posts WHERE id = NEW.post_id;
        IF v_target_owner IS NOT NULL AND v_target_owner <> NEW.user_id THEN
            INSERT INTO public.notifications (user_id, actor_id, type, post_id, comment_id)
            VALUES (v_target_owner, NEW.user_id, 'comment', NEW.post_id, NEW.id);

            -- FCMプッシュ通知: Edge Function を呼び出し
            PERFORM net.http_post(
                url := 'https://ljgvqdcailabzuutaeha.supabase.co/functions/v1/notify_trigger',
                headers := jsonb_build_object(
                    'Content-Type', 'application/json',
                    'x-notify-secret', '4a5d3df69e9baa4456e120a8b1fc45c924730ded80c03fe7b3872b2693847d73'
                ),
                body := jsonb_build_object(
                    'user_id', v_target_owner,
                    'type', 'comment',
                    'actor_name', (SELECT name FROM public.users WHERE id = NEW.user_id)
                )
            );
        END IF;
    END IF;
    RETURN NEW;
END $function$;

GRANT ALL ON FUNCTION public.notify_comment_reply() TO anon;

GRANT ALL ON FUNCTION public.notify_comment_reply() TO authenticated;

GRANT ALL ON FUNCTION public.notify_comment_reply() TO service_role;

CREATE FUNCTION public.notify_dm_message()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
BEGIN
    PERFORM net.http_post(
        url := 'https://ljgvqdcailabzuutaeha.supabase.co/functions/v1/notify_trigger',
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'x-notify-secret', '4a5d3df69e9baa4456e120a8b1fc45c924730ded80c03fe7b3872b2693847d73'
        ),
        body := jsonb_build_object(
            'type', 'dm',
            'room_id', NEW.room_id,
            'sender_id', NEW.sender_id
        )
    );
    RETURN NEW;
END $function$;

GRANT ALL ON FUNCTION public.notify_dm_message() TO anon;

GRANT ALL ON FUNCTION public.notify_dm_message() TO authenticated;

GRANT ALL ON FUNCTION public.notify_dm_message() TO service_role;

CREATE FUNCTION public.notify_follow()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
BEGIN
    INSERT INTO public.notifications (user_id, actor_id, type)
    VALUES (NEW.followed_id, NEW.follower_id, 'follow');

    -- FCMプッシュ通知: Edge Function を呼び出し
    PERFORM net.http_post(
        url := 'https://ljgvqdcailabzuutaeha.supabase.co/functions/v1/notify_trigger',
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'x-notify-secret', '4a5d3df69e9baa4456e120a8b1fc45c924730ded80c03fe7b3872b2693847d73'
        ),
        body := jsonb_build_object(
            'user_id', NEW.followed_id,
            'type', 'follow',
            'actor_name', (SELECT name FROM public.users WHERE id = NEW.follower_id)
        )
    );
    RETURN NEW;
END $function$;

GRANT ALL ON FUNCTION public.notify_follow() TO anon;

GRANT ALL ON FUNCTION public.notify_follow() TO authenticated;

GRANT ALL ON FUNCTION public.notify_follow() TO service_role;

CREATE FUNCTION public.notify_open_chat_message()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
BEGIN
    PERFORM net.http_post(
        url := 'https://ljgvqdcailabzuutaeha.supabase.co/functions/v1/notify_trigger',
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'x-notify-secret', '4a5d3df69e9baa4456e120a8b1fc45c924730ded80c03fe7b3872b2693847d73'
        ),
        body := jsonb_build_object(
            'type', 'open_chat',
            'room_id', NEW.room_id,
            'sender_id', NEW.user_id
        )
    );
    RETURN NEW;
END $function$;

GRANT ALL ON FUNCTION public.notify_open_chat_message() TO anon;

GRANT ALL ON FUNCTION public.notify_open_chat_message() TO authenticated;

GRANT ALL ON FUNCTION public.notify_open_chat_message() TO service_role;

CREATE FUNCTION public.remove_bbs_comment_like_notification()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
BEGIN
    DELETE FROM public.notifications
    WHERE actor_id = OLD.user_id AND type = 'like_comment' AND comment_id = OLD.comment_id;
    RETURN OLD;
END $function$;

GRANT ALL ON FUNCTION public.remove_bbs_comment_like_notification() TO anon;

GRANT ALL ON FUNCTION public.remove_bbs_comment_like_notification() TO authenticated;

GRANT ALL ON FUNCTION public.remove_bbs_comment_like_notification() TO service_role;

CREATE FUNCTION public.remove_bbs_post_like_notification()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
BEGIN
    DELETE FROM public.notifications
    WHERE actor_id = OLD.user_id AND type = 'like_post' AND post_id = OLD.post_id;
    RETURN OLD;
END $function$;

GRANT ALL ON FUNCTION public.remove_bbs_post_like_notification() TO anon;

GRANT ALL ON FUNCTION public.remove_bbs_post_like_notification() TO authenticated;

GRANT ALL ON FUNCTION public.remove_bbs_post_like_notification() TO service_role;

CREATE FUNCTION public.remove_follow_notification()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
BEGIN
    DELETE FROM public.notifications
    WHERE user_id = OLD.followed_id AND actor_id = OLD.follower_id AND type = 'follow';
    RETURN OLD;
END $function$;

GRANT ALL ON FUNCTION public.remove_follow_notification() TO anon;

GRANT ALL ON FUNCTION public.remove_follow_notification() TO authenticated;

GRANT ALL ON FUNCTION public.remove_follow_notification() TO service_role;

CREATE FUNCTION public.update_bbs_comment_likes_count()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  AS $function$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE bbs_comments SET likes_count = likes_count + 1 WHERE id = NEW.comment_id;
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE bbs_comments SET likes_count = GREATEST(likes_count - 1, 0) WHERE id = OLD.comment_id;
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$function$;

GRANT ALL ON FUNCTION public.update_bbs_comment_likes_count() TO anon;

GRANT ALL ON FUNCTION public.update_bbs_comment_likes_count() TO authenticated;

GRANT ALL ON FUNCTION public.update_bbs_comment_likes_count() TO service_role;

CREATE FUNCTION public.update_bbs_post_likes_count()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  AS $function$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE bbs_posts SET likes_count = likes_count + 1 WHERE id = NEW.post_id;
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE bbs_posts SET likes_count = GREATEST(likes_count - 1, 0) WHERE id = OLD.post_id;
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$function$;

GRANT ALL ON FUNCTION public.update_bbs_post_likes_count() TO anon;

GRANT ALL ON FUNCTION public.update_bbs_post_likes_count() TO authenticated;

GRANT ALL ON FUNCTION public.update_bbs_post_likes_count() TO service_role;

CREATE TRIGGER trg_notify_bbs_comment_like
  AFTER INSERT ON public.bbs_comment_likes
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_bbs_comment_like();

CREATE TRIGGER trg_remove_bbs_comment_like_notification
  AFTER DELETE ON public.bbs_comment_likes
  FOR EACH ROW
  EXECUTE FUNCTION public.remove_bbs_comment_like_notification();

CREATE TRIGGER trigger_update_bbs_comment_likes_count
  AFTER INSERT OR DELETE ON public.bbs_comment_likes
  FOR EACH ROW
  EXECUTE FUNCTION public.update_bbs_comment_likes_count();

ALTER TABLE public.bbs_comments
  ADD COLUMN image_url text;

CREATE TRIGGER trg_notify_comment_reply
  AFTER INSERT ON public.bbs_comments
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_comment_reply();

CREATE TRIGGER trg_notify_bbs_post_like
  AFTER INSERT ON public.bbs_likes
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_bbs_post_like();

CREATE TRIGGER trg_remove_bbs_post_like_notification
  AFTER DELETE ON public.bbs_likes
  FOR EACH ROW
  EXECUTE FUNCTION public.remove_bbs_post_like_notification();

CREATE TRIGGER trigger_update_bbs_post_likes_count
  AFTER INSERT OR DELETE ON public.bbs_likes
  FOR EACH ROW
  EXECUTE FUNCTION public.update_bbs_post_likes_count();

ALTER TABLE public.bbs_posts
  ADD COLUMN image_urls text[];

ALTER TABLE public.dm_messages
  ADD COLUMN image_url text;

CREATE INDEX idx_dm_messages_room_unread ON public.dm_messages (room_id)
  WHERE is_read = false;

CREATE INDEX idx_dm_messages_room_created ON public.dm_messages (room_id, created_at DESC);

CREATE TRIGGER trg_notify_dm_message
  AFTER INSERT ON public.dm_messages
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_dm_message();

ALTER TABLE public.dm_room_members
  ADD COLUMN last_read_at timestamp with time zone;

CREATE TABLE public.notification_settings (
  user_id                 uuid                     NOT NULL,
  like_enabled            boolean                  DEFAULT true NOT NULL,
  comment_enabled         boolean                  DEFAULT true NOT NULL,
  follow_enabled          boolean                  DEFAULT true NOT NULL,
  dm_enabled              boolean                  DEFAULT true NOT NULL,
  open_chat_enabled       boolean                  DEFAULT true NOT NULL,
  match_waiting_enabled   boolean                  DEFAULT true NOT NULL,
  updated_at              timestamp with time zone DEFAULT now() NOT NULL,
  is_notification_enabled boolean                  DEFAULT false NOT NULL
);

ALTER TABLE public.notification_settings
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.notification_settings
  ADD CONSTRAINT notification_settings_pkey PRIMARY KEY (user_id);

ALTER TABLE public.notification_settings
  ADD CONSTRAINT notification_settings_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;

GRANT ALL ON public.notification_settings TO anon;

GRANT ALL ON public.notification_settings TO authenticated;

GRANT ALL ON public.notification_settings TO service_role;

CREATE POLICY notification_settings_insert_own ON public.notification_settings
  FOR INSERT
  WITH CHECK ((auth.uid() = user_id));

CREATE POLICY notification_settings_select_own ON public.notification_settings
  FOR SELECT
  USING ((auth.uid() = user_id));

CREATE POLICY notification_settings_update_own ON public.notification_settings
  FOR UPDATE
  USING ((auth.uid() = user_id))
  WITH CHECK ((auth.uid() = user_id));

CREATE TABLE public.notifications (
  id         uuid                     DEFAULT gen_random_uuid() NOT NULL,
  user_id    uuid                     NOT NULL,
  actor_id   uuid                     NOT NULL,
  type       text                     NOT NULL,
  post_id    uuid,
  comment_id uuid,
  is_read    boolean                  DEFAULT false NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  count      integer                  DEFAULT 1 NOT NULL,
  actor_ids  uuid[]                   DEFAULT '{}'::uuid[] NOT NULL
);

ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications, TABLE public.open_chat_messages;

ALTER TABLE public.notifications
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.notifications
  ADD CONSTRAINT notifications_actor_id_fkey FOREIGN KEY (actor_id) REFERENCES public.users(id) ON DELETE CASCADE;

ALTER TABLE public.notifications
  ADD CONSTRAINT notifications_comment_id_fkey FOREIGN KEY (comment_id) REFERENCES public.bbs_comments(id) ON DELETE CASCADE;

ALTER TABLE public.notifications
  ADD CONSTRAINT notifications_pkey PRIMARY KEY (id);

ALTER TABLE public.notifications
  ADD CONSTRAINT notifications_post_id_fkey FOREIGN KEY (post_id) REFERENCES public.bbs_posts(id) ON DELETE CASCADE;

ALTER TABLE public.notifications
  ADD CONSTRAINT notifications_type_check CHECK (type = ANY (ARRAY['like_post'::text, 'like_comment'::text, 'follow'::text, 'reply_comment'::text, 'comment'::text]));

ALTER TABLE public.notifications
  ADD CONSTRAINT notifications_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;

GRANT REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.notifications TO anon;

GRANT REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.notifications TO authenticated;

GRANT ALL ON public.notifications TO service_role;

CREATE INDEX idx_notifications_user_unread ON public.notifications (user_id)
  WHERE is_read = false;

CREATE INDEX idx_notifications_user_created ON public.notifications (user_id, created_at DESC);

CREATE POLICY notifications_select_own ON public.notifications
  FOR SELECT
  USING ((auth.uid() = user_id));

CREATE POLICY notifications_update_own ON public.notifications
  FOR UPDATE
  USING ((auth.uid() = user_id))
  WITH CHECK ((auth.uid() = user_id));

ALTER TABLE public.open_chat_members
  ADD COLUMN last_read_at timestamp with time zone;

ALTER TABLE public.open_chat_messages
  ADD COLUMN image_url text;

CREATE INDEX idx_open_chat_messages_room_created ON public.open_chat_messages (room_id, created_at DESC);

CREATE TRIGGER trg_notify_open_chat_message
  AFTER INSERT ON public.open_chat_messages
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_open_chat_message();

CREATE TABLE public.user_follows (
  follower_id uuid                     NOT NULL,
  followed_id uuid                     NOT NULL,
  created_at  timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE public.user_follows
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.user_follows
  ADD CONSTRAINT user_follows_check CHECK (follower_id <> followed_id);

ALTER TABLE public.user_follows
  ADD CONSTRAINT user_follows_followed_id_fkey FOREIGN KEY (followed_id) REFERENCES public.users(id) ON DELETE CASCADE;

ALTER TABLE public.user_follows
  ADD CONSTRAINT user_follows_follower_id_fkey FOREIGN KEY (follower_id) REFERENCES public.users(id) ON DELETE CASCADE;

ALTER TABLE public.user_follows
  ADD CONSTRAINT user_follows_pkey PRIMARY KEY (follower_id, followed_id);

GRANT ALL ON public.user_follows TO anon;

GRANT ALL ON public.user_follows TO authenticated;

GRANT ALL ON public.user_follows TO service_role;

CREATE TRIGGER trg_notify_follow
  AFTER INSERT ON public.user_follows
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_follow();

CREATE TRIGGER trg_remove_follow_notification
  AFTER DELETE ON public.user_follows
  FOR EACH ROW
  EXECUTE FUNCTION public.remove_follow_notification();

CREATE POLICY user_follows_delete_own ON public.user_follows
  FOR DELETE
  USING ((auth.uid() = follower_id));

CREATE POLICY user_follows_insert_own ON public.user_follows
  FOR INSERT
  WITH CHECK ((auth.uid() = follower_id));

CREATE POLICY user_follows_select_authenticated ON public.user_follows
  FOR SELECT
  USING ((auth.role() = 'authenticated'::text));

ALTER TABLE public.users
  ADD COLUMN header_url text;

CREATE TRIGGER trg_new_notification_settings
  AFTER INSERT ON public.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_notification_settings();