-- ============================================================
-- Migration: notification_resba_spec
-- 通知仕様の最終版を実装する
--  1. notification_settings に resba_apply_enabled 列を追加（レスバ応募カテゴリ）
--  2. notifications.type チェックに resba_apply を追加
--  3. レスバ応募通知: battle_invite_applications に INSERT されたら
--     ホストへ「あなたのレスバに応募しました」(resba_apply) のアプリ内通知+プッシュ
--     （オプチャ・DM・返信コメント・対戦募集、添付種類に関係なく全ての応募で通知）
--  4. コメント添付レスバ通知: attach_type='comment' の battle_invites が作られたら
--     返信先（親コメント作者 / なければポスト作者）へ
--     「レスバが届きました」(resba_invite) のアプリ内通知+プッシュ
--     ※プッシュは既存の「コメント・返信」設定に従う
--  5. DM/オプチャ添付レスバ: 通知タブには表示せず（メッセージタブで表示）
--     プッシュのみ送信（DM → 名前 + 「レスバが届きました」/ オプチャ → グループ名 + 「レスバが届きました」）
--     ※プッシュは既存の「DM」「クラブ」設定に従う
-- 旧指名型 resba_invite / resba_accepted / resba_declined は廃止（トリガーなし）
-- ============================================================

SET check_function_bodies = false;

-- ---------- 1. notification_settings に resba_apply_enabled 列 ----------
ALTER TABLE public.notification_settings
  ADD COLUMN IF NOT EXISTS resba_apply_enabled boolean DEFAULT true;

-- ---------- 2. notifications.type チェックに resba_apply を追加 ----------
ALTER TABLE public.notifications
  DROP CONSTRAINT IF EXISTS notifications_type_check;

ALTER TABLE public.notifications
  ADD CONSTRAINT notifications_type_check CHECK (
    type = ANY (ARRAY[
      'like_post'::text, 'like_comment'::text, 'follow'::text,
      'reply_comment'::text, 'comment'::text,
      'resba_invite'::text, 'resba_accepted'::text, 'resba_declined'::text,
      'resba_apply'::text
    ])
  );

-- ---------- 3. レスバ応募通知（ホストへ） ----------
CREATE OR REPLACE FUNCTION public.notify_resba_apply()
  RETURNS trigger
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_host_id    uuid;
  v_theme      text;
  v_actor_name text;
  v_should_push boolean;
BEGIN
  IF NEW.applicant_id IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT sender_id, theme INTO v_host_id, v_theme
  FROM public.battle_invites
  WHERE id = NEW.invite_id;

  -- ホスト不在 or 自分自身の応募（通常は起きない）は通知しない
  IF v_host_id IS NULL OR v_host_id = NEW.applicant_id THEN
    RETURN NEW;
  END IF;

  -- ★ 受信者(ホスト)が応募者をブロックしていたら通知しない
  IF public.is_user_blocked(v_host_id, NEW.applicant_id) THEN
    RETURN NEW;
  END IF;

  -- アプリ内通知(notifications)に登録
  INSERT INTO public.notifications (user_id, actor_id, type, count, actor_ids, invite_id)
  VALUES (v_host_id, NEW.applicant_id, 'resba_apply', 1, ARRAY[NEW.applicant_id], NEW.invite_id);

  -- プッシュ通知判定（ホストが通知ON・FCMトークン保持・レスバ応募ON）
  SELECT EXISTS (
    SELECT 1
    FROM public.users u
    LEFT JOIN public.notification_settings ns ON ns.user_id = u.id
    WHERE u.id = v_host_id
      AND u.fcm_token IS NOT NULL
      AND trim(u.fcm_token) <> ''
      AND COALESCE(ns.is_notification_enabled, false) = true
      AND COALESCE(ns.resba_apply_enabled, true) = true
  ) INTO v_should_push;

  IF v_should_push THEN
    SELECT name INTO v_actor_name FROM public.users WHERE id = NEW.applicant_id;
    PERFORM net.http_post(
      url := 'http://192.168.11.52:54321/functions/v1/notify_trigger',
      headers := jsonb_build_object('Content-Type', 'application/json', 'x-notify-secret', 'YOUR_NOTIFY_SECRET'),
      body := jsonb_build_object(
        'user_id', v_host_id,
        'type', 'resba_apply',
        'actor_name', COALESCE(v_actor_name, '誰か'),
        'invite_id', NEW.invite_id,
        'theme', COALESCE(v_theme, '')
      )
    );
  END IF;
  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_notify_resba_apply ON public.battle_invite_applications;
CREATE TRIGGER trg_notify_resba_apply
  AFTER INSERT ON public.battle_invite_applications
  FOR EACH ROW EXECUTE FUNCTION public.notify_resba_apply();

-- ---------- 4. コメント添付レスバ通知（返信先の相手へ） ----------
CREATE OR REPLACE FUNCTION public.notify_resba_comment_attach()
  RETURNS trigger
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_comment_user uuid;
  v_parent       uuid;
  v_post_id      uuid;
  v_recipient    uuid;
  v_actor_name   text;
  v_should_push  boolean;
BEGIN
  -- コメント添付のレスバのみ（募集型）
  IF NEW.attach_type <> 'comment' OR NEW.attach_id IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT user_id, parent_comment_id, post_id
    INTO v_comment_user, v_parent, v_post_id
    FROM public.bbs_comments
    WHERE id = NEW.attach_id;
  IF NOT FOUND THEN
    RETURN NEW;
  END IF;

  -- 返信先（親コメントの作者）がいればそこ、いなければポスト作者
  IF v_parent IS NOT NULL THEN
    SELECT user_id INTO v_recipient FROM public.bbs_comments WHERE id = v_parent;
  ELSE
    SELECT user_id INTO v_recipient FROM public.bbs_posts WHERE id = v_post_id;
  END IF;

  IF v_recipient IS NULL OR v_recipient = NEW.sender_id THEN
    RETURN NEW;
  END IF;

  -- ★ 受信者が送信者をブロックしていたら通知しない
  IF public.is_user_blocked(v_recipient, NEW.sender_id) THEN
    RETURN NEW;
  END IF;

  -- アプリ内通知(notifications)に登録
  INSERT INTO public.notifications (user_id, actor_id, type, post_id, comment_id, count, actor_ids, invite_id)
  VALUES (v_recipient, NEW.sender_id, 'resba_invite', v_post_id, NEW.attach_id, 1, ARRAY[NEW.sender_id], NEW.id);

  -- プッシュ通知判定（「コメント・返信」設定に従う）
  SELECT EXISTS (
    SELECT 1
    FROM public.users u
    LEFT JOIN public.notification_settings ns ON ns.user_id = u.id
    WHERE u.id = v_recipient
      AND u.fcm_token IS NOT NULL
      AND trim(u.fcm_token) <> ''
      AND COALESCE(ns.is_notification_enabled, false) = true
      AND COALESCE(ns.comment_enabled, true) = true
  ) INTO v_should_push;

  IF v_should_push THEN
    SELECT name INTO v_actor_name FROM public.users WHERE id = NEW.sender_id;
    PERFORM net.http_post(
      url := 'http://192.168.11.52:54321/functions/v1/notify_trigger',
      headers := jsonb_build_object('Content-Type', 'application/json', 'x-notify-secret', 'YOUR_NOTIFY_SECRET'),
      body := jsonb_build_object(
        'user_id', v_recipient,
        'type', 'resba_invite',
        'actor_name', COALESCE(v_actor_name, '誰か'),
        'invite_id', NEW.id,
        'attach_type', NEW.attach_type,
        'theme', COALESCE(NEW.theme, '')
      )
    );
  END IF;
  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_notify_resba_comment_attach ON public.battle_invites;
CREATE TRIGGER trg_notify_resba_comment_attach
  AFTER INSERT ON public.battle_invites
  FOR EACH ROW EXECUTE FUNCTION public.notify_resba_comment_attach();

-- ---------- 5. DM/オプチャ添付レスバ: プッシュのみ（通知タブには行かない） ----------
-- 旧 notify_dm_resba_invite（DM のアプリ内通知+プッシュ）を置き換え
CREATE OR REPLACE FUNCTION public.notify_resba_message_attach()
  RETURNS trigger
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_room_id     uuid;
  v_actor_name  text;
  v_should_push boolean;
BEGIN
  -- ---------- DM 添付 ----------
  IF NEW.attach_type = 'dm' AND NEW.attach_id IS NOT NULL THEN
    SELECT room_id INTO v_room_id FROM public.dm_messages WHERE id = NEW.attach_id;
    IF v_room_id IS NULL THEN
      RETURN NEW;
    END IF;

    -- 相手（送信者以外のルームメンバー）が通知ONか確認
    SELECT EXISTS (
      SELECT 1
      FROM public.dm_room_members m
      JOIN public.users u ON u.id = m.user_id
      LEFT JOIN public.notification_settings ns ON ns.user_id = u.id
      WHERE m.room_id = v_room_id AND m.user_id <> NEW.sender_id
        AND u.fcm_token IS NOT NULL AND trim(u.fcm_token) <> ''
        AND COALESCE(ns.is_notification_enabled, false) = true
        AND COALESCE(ns.dm_enabled, true) = true
    ) INTO v_should_push;

    IF v_should_push THEN
      SELECT name INTO v_actor_name FROM public.users WHERE id = NEW.sender_id;
      PERFORM net.http_post(
        url := 'http://192.168.11.52:54321/functions/v1/notify_trigger',
        headers := jsonb_build_object('Content-Type', 'application/json', 'x-notify-secret', 'YOUR_NOTIFY_SECRET'),
        body := jsonb_build_object(
          'type', 'dm_resba',
          'room_id', v_room_id,
          'sender_id', NEW.sender_id,
          'actor_name', COALESCE(v_actor_name, '誰か'),
          'invite_id', NEW.id
        )
      );
    END IF;
    RETURN NEW;
  END IF;

  -- ---------- オプチャ 添付 ----------
  IF NEW.attach_type = 'open_chat' AND NEW.attach_id IS NOT NULL THEN
    SELECT room_id INTO v_room_id FROM public.open_chat_messages WHERE id = NEW.attach_id;
    IF v_room_id IS NULL THEN
      RETURN NEW;
    END IF;

    -- 送信者以外で通知ONのメンバーがいるときだけ Edge Function を呼ぶ（送信はそちらでファンアウト）
    SELECT EXISTS (
      SELECT 1
      FROM public.open_chat_members m
      JOIN public.users u ON u.id = m.user_id
      LEFT JOIN public.notification_settings ns ON ns.user_id = u.id
      WHERE m.room_id = v_room_id AND m.user_id <> NEW.sender_id
        AND COALESCE(m.is_muted, false) = false
        AND u.fcm_token IS NOT NULL AND trim(u.fcm_token) <> ''
        AND COALESCE(ns.is_notification_enabled, false) = true
        AND COALESCE(ns.open_chat_enabled, true) = true
    ) INTO v_should_push;

    IF v_should_push THEN
      SELECT name INTO v_actor_name FROM public.users WHERE id = NEW.sender_id;
      PERFORM net.http_post(
        url := 'http://192.168.11.52:54321/functions/v1/notify_trigger',
        headers := jsonb_build_object('Content-Type', 'application/json', 'x-notify-secret', 'YOUR_NOTIFY_SECRET'),
        body := jsonb_build_object(
          'type', 'open_chat_resba',
          'room_id', v_room_id,
          'sender_id', NEW.sender_id,
          'actor_name', COALESCE(v_actor_name, '誰か'),
          'invite_id', NEW.id
        )
      );
    END IF;
    RETURN NEW;
  END IF;

  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_notify_dm_resba_invite ON public.battle_invites;
CREATE TRIGGER trg_notify_resba_message_attach
  AFTER INSERT ON public.battle_invites
  FOR EACH ROW EXECUTE FUNCTION public.notify_resba_message_attach();

-- ---------- 6. コメント・返信プッシュに本文を渡す ----------
-- 返信類のプッシュ文言を「◯◯から返信/コメント」+ 本文（返信内容/コメント内容）にする
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
                        'actor_name', (SELECT name FROM public.users WHERE id = NEW.user_id),
                        'content', COALESCE(NEW.content, '')
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
                        'actor_name', (SELECT name FROM public.users WHERE id = NEW.user_id),
                        'content', COALESCE(NEW.content, '')
                    )
                );
            END IF;
        END IF;
    END IF;
    RETURN NEW;
END $function$;
