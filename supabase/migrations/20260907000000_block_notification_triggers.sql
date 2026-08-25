-- ============================================================
-- Migration: block_notification_triggers
-- ブロックしたユーザーからの通知をサーバー側で止める(非対称ルール)
--  ブロックは「ブロックした人の視界にだけ」影響する:
--   ・受信者(=通知の届く人)が送信者をブロックしている場合のみ、
--     通知レコード作成とプッシュ送信をスキップする
--   ・送信者が受信者をブロックしているだけの場合は影響しない
--     (ブロックしていない相手の履歴・新着はそのまま)
--  1. 通知トリガー(通知レコード作成 + FCMプッシュ)に片方向ブロック判定を追加
--  2. 既存の「受信者→送信者」ブロック由来の通知レコードを削除
-- ※プッシュのみの経路(DM / オプチャ)は受け取り側のブロックで除外するため、
--   Edge Function (functions/notify_trigger) 側で対応する
-- ============================================================

SET check_function_bodies = false;

-- ---------- 1. 投稿へのいいね通知(ブロック対応) ----------
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
        -- ★ 受信者(投稿主)が送信者(いいねした人)をブロックしていたら通知しない
        IF public.is_user_blocked(v_owner, NEW.user_id) THEN
            RETURN NEW;
        END IF;

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

-- ---------- 2. コメントへのいいね通知(ブロック対応) ----------
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
        -- ★ 受信者(コメント主)が送信者(いいねした人)をブロックしていたら通知しない
        IF public.is_user_blocked(v_owner, NEW.user_id) THEN
            RETURN NEW;
        END IF;

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

-- ---------- 3. コメント・返信通知(ブロック対応) ----------
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
            -- ★ 受信者(親コメントの作者)が送信者(返信した人)をブロックしていたら通知しない
            IF public.is_user_blocked(v_target_owner, NEW.user_id) THEN
                RETURN NEW;
            END IF;

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
            -- ★ 受信者(ポストの作者)が送信者(コメントした人)をブロックしていたら通知しない
            IF public.is_user_blocked(v_target_owner, NEW.user_id) THEN
                RETURN NEW;
            END IF;

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

-- ---------- 4. フォロー通知(ブロック対応) ----------
CREATE OR REPLACE FUNCTION public.notify_follow()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
    v_should_push BOOLEAN;
BEGIN
    -- ★ 受信者(フォローされた人)が送信者(フォローした人)をブロックしていたら通知しない
    IF public.is_user_blocked(NEW.followed_id, NEW.follower_id) THEN
        RETURN NEW;
    END IF;

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

-- ---------- 5. DMレスバ招待通知(ブロック対応) ----------
CREATE OR REPLACE FUNCTION public.notify_dm_resba_invite()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_room_id UUID;
  v_target_user_id UUID;
  v_actor_name TEXT;
  v_should_push BOOLEAN;
BEGIN
  -- DMへの添付レスバのみ処理（募集制のまま、DMメンバーから相手を特定）
  IF NEW.attach_type = 'dm' AND NEW.attach_id IS NOT NULL THEN
    -- 添付されたDMメッセージから room_id を取得
    SELECT room_id INTO v_room_id FROM public.dm_messages WHERE id = NEW.attach_id;
    
    IF v_room_id IS NOT NULL THEN
      -- DMルームメンバーから送信者以外の相手ユーザーIDを取得
      SELECT user_id INTO v_target_user_id
      FROM public.dm_room_members
      WHERE room_id = v_room_id AND user_id <> NEW.sender_id
      LIMIT 1;

      IF v_target_user_id IS NOT NULL THEN
        -- ★ 受信者(相手)が送信者をブロックしていたら通知しない
        IF public.is_user_blocked(v_target_user_id, NEW.sender_id) THEN
          RETURN NEW;
        END IF;

        -- アプリ内通知(notifications)テーブルに登録
        INSERT INTO public.notifications (user_id, actor_id, type, count, actor_ids, invite_id)
        VALUES (v_target_user_id, NEW.sender_id, 'resba_invite', 1, ARRAY[NEW.sender_id], NEW.id);

        -- プッシュ通知判定（相手が通知ONかつFCMトークン保持）
        SELECT EXISTS (
          SELECT 1
          FROM public.users u
          LEFT JOIN public.notification_settings ns ON ns.user_id = u.id
          WHERE u.id = v_target_user_id
            AND u.fcm_token IS NOT NULL
            AND trim(u.fcm_token) <> ''
            AND COALESCE(ns.is_notification_enabled, false) = true
            AND (COALESCE(ns.dm_enabled, true) = true OR COALESCE(ns.match_waiting_enabled, true) = true)
        ) INTO v_should_push;

        IF v_should_push THEN
          SELECT name INTO v_actor_name FROM public.users WHERE id = NEW.sender_id;
          PERFORM net.http_post(
            url := 'http://192.168.11.52:54321/functions/v1/notify_trigger',
            headers := jsonb_build_object(
              'Content-Type', 'application/json',
              'x-notify-secret', 'YOUR_NOTIFY_SECRET'
            ),
            body := jsonb_build_object(
              'user_id', v_target_user_id,
              'type', 'resba_invite',
              'actor_name', COALESCE(v_actor_name, '誰か'),
              'invite_id', NEW.id
            )
          );
        END IF;
      END IF;
    END IF;
  END IF;
  RETURN NEW;
END $function$;

-- ---------- 6. 既存の「受信者→送信者」ブロック由来の通知を削除 ----------
-- (ブロックした人の視界からだけ消す: 受信者が送信者をブロックしている通知のみ削除)
DELETE FROM public.notifications n
WHERE EXISTS (
  SELECT 1 FROM public.brock_user b
  WHERE b.user_id = n.user_id AND b.block_user_id = n.actor_id
);