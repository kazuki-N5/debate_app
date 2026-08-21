-- Migration: Optimize notification triggers by checking FCM token & settings before net.http_post
-- 相手が通知ONかつFCMトークンを保持している場合のみ Edge Function を呼び出すように最適化

SET check_function_bodies = false;

-- 1. 投稿へのいいね通知
CREATE OR REPLACE FUNCTION public.notify_bbs_post_like()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
    v_owner UUID;
    v_batch_id UUID;
    v_actors UUID[];
    v_is_new BOOLEAN;
    v_should_push BOOLEAN;
BEGIN
    SELECT user_id INTO v_owner FROM public.bbs_posts WHERE id = NEW.post_id;
    IF v_owner IS NOT NULL AND v_owner <> NEW.user_id THEN
        -- 最新の「未読」バッチを探す
        SELECT id, actor_ids INTO v_batch_id, v_actors
        FROM public.notifications
        WHERE user_id = v_owner AND type = 'like_post' AND post_id = NEW.post_id
          AND is_read = false
        ORDER BY created_at DESC LIMIT 1;

        IF v_batch_id IS NULL THEN
            INSERT INTO public.notifications (user_id, actor_id, type, post_id, count, actor_ids)
            VALUES (v_owner, NEW.user_id, 'like_post', NEW.post_id, 1, ARRAY[NEW.user_id]);
            v_is_new := true;
        ELSIF NOT (NEW.user_id = ANY(v_actors)) THEN
            UPDATE public.notifications
            SET count = count + 1,
                actor_ids = actor_ids || NEW.user_id,
                actor_id = NEW.user_id,
                created_at = now()
            WHERE id = v_batch_id;
            v_is_new := true;
        ELSE
            v_is_new := false;
        END IF;

        -- FCMプッシュ通知: 新規いいね かつ 相手が通知ON&トークン保持の場合のみ Edge Function を呼ぶ
        IF v_is_new THEN
            SELECT EXISTS (
                SELECT 1
                FROM public.users u
                LEFT JOIN public.notification_settings ns ON ns.user_id = u.id
                WHERE u.id = v_owner
                  AND u.fcm_token IS NOT NULL
                  AND trim(u.fcm_token) <> ''
                  AND COALESCE(ns.is_notification_enabled, false) = true
                  AND COALESCE(ns.like_enabled, true) = true
            ) INTO v_should_push;

            IF v_should_push THEN
                PERFORM net.http_post(
                    url := 'http://192.168.11.52:54321/functions/v1/notify_trigger',
                    headers := jsonb_build_object(
                        'Content-Type', 'application/json',
                        'x-notify-secret', 'YOUR_NOTIFY_SECRET'
                    ),
                    body := jsonb_build_object(
                        'user_id', v_owner,
                        'type', 'like_post',
                        'actor_name', (SELECT name FROM public.users WHERE id = NEW.user_id)
                    )
                );
            END IF;
        END IF;
    END IF;
    RETURN NEW;
END $function$;

-- 2. コメントへのいいね通知
CREATE OR REPLACE FUNCTION public.notify_bbs_comment_like()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
    v_owner UUID;
    v_post_id UUID;
    v_batch_id UUID;
    v_actors UUID[];
    v_is_new BOOLEAN;
    v_should_push BOOLEAN;
BEGIN
    SELECT user_id, post_id INTO v_owner, v_post_id FROM public.bbs_comments WHERE id = NEW.comment_id;
    IF v_owner IS NOT NULL AND v_owner <> NEW.user_id THEN
        SELECT id, actor_ids INTO v_batch_id, v_actors
        FROM public.notifications
        WHERE user_id = v_owner AND type = 'like_comment' AND comment_id = NEW.comment_id
          AND is_read = false
        ORDER BY created_at DESC LIMIT 1;

        IF v_batch_id IS NULL THEN
            INSERT INTO public.notifications (user_id, actor_id, type, post_id, comment_id, count, actor_ids)
            VALUES (v_owner, NEW.user_id, 'like_comment', v_post_id, NEW.comment_id, 1, ARRAY[NEW.user_id]);
            v_is_new := true;
        ELSIF NOT (NEW.user_id = ANY(v_actors)) THEN
            UPDATE public.notifications
            SET count = count + 1,
                actor_ids = actor_ids || NEW.user_id,
                actor_id = NEW.user_id,
                created_at = now()
            WHERE id = v_batch_id;
            v_is_new := true;
        ELSE
            v_is_new := false;
        END IF;

        IF v_is_new THEN
            SELECT EXISTS (
                SELECT 1
                FROM public.users u
                LEFT JOIN public.notification_settings ns ON ns.user_id = u.id
                WHERE u.id = v_owner
                  AND u.fcm_token IS NOT NULL
                  AND trim(u.fcm_token) <> ''
                  AND COALESCE(ns.is_notification_enabled, false) = true
                  AND COALESCE(ns.like_enabled, true) = true
            ) INTO v_should_push;

            IF v_should_push THEN
                PERFORM net.http_post(
                    url := 'http://192.168.11.52:54321/functions/v1/notify_trigger',
                    headers := jsonb_build_object(
                        'Content-Type', 'application/json',
                        'x-notify-secret', 'YOUR_NOTIFY_SECRET'
                    ),
                    body := jsonb_build_object(
                        'user_id', v_owner,
                        'type', 'like_comment',
                        'actor_name', (SELECT name FROM public.users WHERE id = NEW.user_id)
                    )
                );
            END IF;
        END IF;
    END IF;
    RETURN NEW;
END $function$;

-- 3. コメント・返信通知
CREATE OR REPLACE FUNCTION public.notify_comment_reply()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
    v_target_owner UUID;
    v_post_id UUID;
    v_should_push BOOLEAN;
BEGIN
    IF NEW.parent_comment_id IS NOT NULL THEN
        -- 返信: 親コメントの作者に通知
        SELECT user_id, post_id INTO v_target_owner, v_post_id
        FROM public.bbs_comments WHERE id = NEW.parent_comment_id;
        IF v_target_owner IS NOT NULL AND v_target_owner <> NEW.user_id THEN
            INSERT INTO public.notifications (user_id, actor_id, type, post_id, comment_id)
            VALUES (v_target_owner, NEW.user_id, 'reply_comment', v_post_id, NEW.id);

            SELECT EXISTS (
                SELECT 1
                FROM public.users u
                LEFT JOIN public.notification_settings ns ON ns.user_id = u.id
                WHERE u.id = v_target_owner
                  AND u.fcm_token IS NOT NULL
                  AND trim(u.fcm_token) <> ''
                  AND COALESCE(ns.is_notification_enabled, false) = true
                  AND COALESCE(ns.comment_enabled, true) = true
            ) INTO v_should_push;

            IF v_should_push THEN
                PERFORM net.http_post(
                    url := 'http://192.168.11.52:54321/functions/v1/notify_trigger',
                    headers := jsonb_build_object(
                        'Content-Type', 'application/json',
                        'x-notify-secret', 'YOUR_NOTIFY_SECRET'
                    ),
                    body := jsonb_build_object(
                        'user_id', v_target_owner,
                        'type', 'reply_comment',
                        'actor_name', (SELECT name FROM public.users WHERE id = NEW.user_id)
                    )
                );
            END IF;
        END IF;
    ELSE
        -- トップレベルコメント: ポストの作者に通知
        SELECT user_id INTO v_target_owner FROM public.bbs_posts WHERE id = NEW.post_id;
        IF v_target_owner IS NOT NULL AND v_target_owner <> NEW.user_id THEN
            INSERT INTO public.notifications (user_id, actor_id, type, post_id, comment_id)
            VALUES (v_target_owner, NEW.user_id, 'comment', NEW.post_id, NEW.id);

            SELECT EXISTS (
                SELECT 1
                FROM public.users u
                LEFT JOIN public.notification_settings ns ON ns.user_id = u.id
                WHERE u.id = v_target_owner
                  AND u.fcm_token IS NOT NULL
                  AND trim(u.fcm_token) <> ''
                  AND COALESCE(ns.is_notification_enabled, false) = true
                  AND COALESCE(ns.comment_enabled, true) = true
            ) INTO v_should_push;

            IF v_should_push THEN
                PERFORM net.http_post(
                    url := 'http://192.168.11.52:54321/functions/v1/notify_trigger',
                    headers := jsonb_build_object(
                        'Content-Type', 'application/json',
                        'x-notify-secret', 'YOUR_NOTIFY_SECRET'
                    ),
                    body := jsonb_build_object(
                        'user_id', v_target_owner,
                        'type', 'comment',
                        'actor_name', (SELECT name FROM public.users WHERE id = NEW.user_id)
                    )
                );
            END IF;
        END IF;
    END IF;
    RETURN NEW;
END $function$;

-- 4. フォロー通知
CREATE OR REPLACE FUNCTION public.notify_follow()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
    v_should_push BOOLEAN;
BEGIN
    INSERT INTO public.notifications (user_id, actor_id, type)
    VALUES (NEW.followed_id, NEW.follower_id, 'follow');

    SELECT EXISTS (
        SELECT 1
        FROM public.users u
        LEFT JOIN public.notification_settings ns ON ns.user_id = u.id
        WHERE u.id = NEW.followed_id
          AND u.fcm_token IS NOT NULL
          AND trim(u.fcm_token) <> ''
          AND COALESCE(ns.is_notification_enabled, false) = true
          AND COALESCE(ns.follow_enabled, true) = true
    ) INTO v_should_push;

    IF v_should_push THEN
        PERFORM net.http_post(
            url := 'http://192.168.11.52:54321/functions/v1/notify_trigger',
            headers := jsonb_build_object(
                'Content-Type', 'application/json',
                'x-notify-secret', 'YOUR_NOTIFY_SECRET'
            ),
            body := jsonb_build_object(
                'user_id', NEW.followed_id,
                'type', 'follow',
                'actor_name', (SELECT name FROM public.users WHERE id = NEW.follower_id)
            )
        );
    END IF;
    RETURN NEW;
END $function$;

-- 5. DM通知
CREATE OR REPLACE FUNCTION public.notify_dm_message()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
    v_should_push BOOLEAN;
BEGIN
    SELECT EXISTS (
        SELECT 1
        FROM public.dm_room_members m
        JOIN public.users u ON u.id = m.user_id
        LEFT JOIN public.notification_settings ns ON ns.user_id = u.id
        WHERE m.room_id = NEW.room_id
          AND m.user_id <> NEW.sender_id
          AND u.fcm_token IS NOT NULL
          AND trim(u.fcm_token) <> ''
          AND COALESCE(ns.is_notification_enabled, false) = true
          AND COALESCE(ns.dm_enabled, true) = true
    ) INTO v_should_push;

    IF v_should_push THEN
        PERFORM net.http_post(
            url := 'http://192.168.11.52:54321/functions/v1/notify_trigger',
            headers := jsonb_build_object(
                'Content-Type', 'application/json',
                'x-notify-secret', 'YOUR_NOTIFY_SECRET'
            ),
            body := jsonb_build_object(
                'type', 'dm',
                'room_id', NEW.room_id,
                'sender_id', NEW.sender_id
            )
        );
    END IF;
    RETURN NEW;
END $function$;

-- 6. オープンチャット通知
CREATE OR REPLACE FUNCTION public.notify_open_chat_message()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
    v_should_push BOOLEAN;
BEGIN
    SELECT EXISTS (
        SELECT 1
        FROM public.open_chat_members m
        JOIN public.users u ON u.id = m.user_id
        LEFT JOIN public.notification_settings ns ON ns.user_id = u.id
        WHERE m.room_id = NEW.room_id
          AND m.user_id <> NEW.user_id
          AND u.fcm_token IS NOT NULL
          AND trim(u.fcm_token) <> ''
          AND COALESCE(ns.is_notification_enabled, false) = true
          AND COALESCE(ns.open_chat_enabled, true) = true
    ) INTO v_should_push;

    IF v_should_push THEN
        PERFORM net.http_post(
            url := 'http://192.168.11.52:54321/functions/v1/notify_trigger',
            headers := jsonb_build_object(
                'Content-Type', 'application/json',
                'x-notify-secret', 'YOUR_NOTIFY_SECRET'
            ),
            body := jsonb_build_object(
                'type', 'open_chat',
                'room_id', NEW.room_id,
                'sender_id', NEW.user_id
            )
        );
    END IF;
    RETURN NEW;
END $function$;

-- 7. レスバ招待通知
CREATE OR REPLACE FUNCTION public.notify_resba_invite()
  RETURNS trigger
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_post_id    uuid;
  v_comment_id uuid;
  v_actor_name text;
  v_should_push BOOLEAN;
BEGIN
  IF NEW.target_user_id IS NOT NULL AND NEW.target_user_id <> NEW.sender_id THEN
    IF NEW.attach_type = 'post' THEN
      v_post_id := NEW.attach_id;
    ELSIF NEW.attach_type = 'comment' THEN
      v_comment_id := NEW.attach_id;
    END IF;

    INSERT INTO public.notifications (user_id, actor_id, type, post_id, comment_id, count, actor_ids, invite_id)
    VALUES (NEW.target_user_id, NEW.sender_id, 'resba_invite', v_post_id, v_comment_id, 1, ARRAY[NEW.sender_id], NEW.id);

    SELECT EXISTS (
        SELECT 1
        FROM public.users u
        LEFT JOIN public.notification_settings ns ON ns.user_id = u.id
        WHERE u.id = NEW.target_user_id
          AND u.fcm_token IS NOT NULL
          AND trim(u.fcm_token) <> ''
          AND COALESCE(ns.is_notification_enabled, false) = true
          AND COALESCE(ns.match_waiting_enabled, true) = true
    ) INTO v_should_push;

    IF v_should_push THEN
        SELECT name INTO v_actor_name FROM public.users WHERE id = NEW.sender_id;
        PERFORM net.http_post(
          url := 'http://192.168.11.52:54321/functions/v1/notify_trigger',
          headers := jsonb_build_object('Content-Type', 'application/json', 'x-notify-secret', 'YOUR_NOTIFY_SECRET'),
          body := jsonb_build_object('user_id', NEW.target_user_id, 'type', 'resba_invite', 'actor_name', v_actor_name)
        );
    END IF;
  END IF;
  RETURN NEW;
END;
$function$;

-- 8. レスバ承諾通知
CREATE OR REPLACE FUNCTION public.notify_resba_accepted()
  RETURNS trigger
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_actor_name text;
  v_should_push BOOLEAN;
BEGIN
  IF NEW.status = 'accepted' AND OLD.status = 'pending' AND NEW.responder_id IS NOT NULL THEN
    INSERT INTO public.notifications (user_id, actor_id, type, count, actor_ids, invite_id)
    VALUES (NEW.sender_id, NEW.responder_id, 'resba_accepted', 1, ARRAY[NEW.responder_id], NEW.id);

    SELECT EXISTS (
        SELECT 1
        FROM public.users u
        LEFT JOIN public.notification_settings ns ON ns.user_id = u.id
        WHERE u.id = NEW.sender_id
          AND u.fcm_token IS NOT NULL
          AND trim(u.fcm_token) <> ''
          AND COALESCE(ns.is_notification_enabled, false) = true
          AND COALESCE(ns.match_waiting_enabled, true) = true
    ) INTO v_should_push;

    IF v_should_push THEN
        SELECT name INTO v_actor_name FROM public.users WHERE id = NEW.responder_id;
        PERFORM net.http_post(
          url := 'http://192.168.11.52:54321/functions/v1/notify_trigger',
          headers := jsonb_build_object('Content-Type', 'application/json', 'x-notify-secret', 'YOUR_NOTIFY_SECRET'),
          body := jsonb_build_object('user_id', NEW.sender_id, 'type', 'resba_accepted', 'actor_name', v_actor_name)
        );
    END IF;
  END IF;
  RETURN NEW;
END;
$function$;

-- 9. レスバ辞退通知
CREATE OR REPLACE FUNCTION public.notify_resba_declined()
  RETURNS trigger
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_actor_id   uuid;
  v_actor_name text;
  v_should_push BOOLEAN;
BEGIN
  IF NEW.status = 'declined' AND OLD.status = 'pending' THEN
    v_actor_id := COALESCE(NEW.responder_id, NEW.target_user_id);
    IF v_actor_id IS NOT NULL AND v_actor_id <> NEW.sender_id THEN
      INSERT INTO public.notifications (user_id, actor_id, type, count, actor_ids, invite_id)
      VALUES (NEW.sender_id, v_actor_id, 'resba_declined', 1, ARRAY[v_actor_id], NEW.id);

      SELECT EXISTS (
          SELECT 1
          FROM public.users u
          LEFT JOIN public.notification_settings ns ON ns.user_id = u.id
          WHERE u.id = NEW.sender_id
            AND u.fcm_token IS NOT NULL
            AND trim(u.fcm_token) <> ''
            AND COALESCE(ns.is_notification_enabled, false) = true
            AND COALESCE(ns.match_waiting_enabled, true) = true
      ) INTO v_should_push;

      IF v_should_push THEN
          SELECT name INTO v_actor_name FROM public.users WHERE id = v_actor_id;
          PERFORM net.http_post(
            url := 'http://192.168.11.52:54321/functions/v1/notify_trigger',
            headers := jsonb_build_object('Content-Type', 'application/json', 'x-notify-secret', 'YOUR_NOTIFY_SECRET'),
            body := jsonb_build_object('user_id', NEW.sender_id, 'type', 'resba_declined', 'actor_name', v_actor_name)
          );
      END IF;
    END IF;
  END IF;
  RETURN NEW;
END;
$function$;
