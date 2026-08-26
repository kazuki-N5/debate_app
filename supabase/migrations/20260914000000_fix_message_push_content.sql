-- ============================================================
-- Migration: fix_message_push_content
-- 画像+テキスト同時送信（アプリは2通に分割してINSERT）で
-- プッシュ通知が「テキスト2回」になる問題を修正する
--
-- 原因: notify_trigger が通知時に「最新メッセージ」をDBから再取得して本文を組み立てるため、
--       net.http_post が非同期で2回呼ばれると、どちらの呼び出しも最新(=テキスト)を
--       読んでしまい、テキストが2回通知される
-- 修正: トリガーから content / image_url を渡し、
--       Edge Function は渡された値で本文を組み立てる（再取得のレースを排除）
--       → 画像1回 + テキスト1回の通知になる
-- ============================================================

SET check_function_bodies = false;

-- 念のため image_url カラムを保証（既存DBで未適用の場合も動くように）
ALTER TABLE public.dm_messages ADD COLUMN IF NOT EXISTS image_url text;
ALTER TABLE public.open_chat_messages ADD COLUMN IF NOT EXISTS image_url text;

-- ---------- DM通知: content / image_url を渡す ----------
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
            url := 'https://ljgvqdcailabzuutaeha.supabase.co/functions/v1/notify_trigger',
            headers := jsonb_build_object(
                'Content-Type', 'application/json',
                'x-notify-secret', '4a5d3df69e9baa4456e120a8b1fc45c924730ded80c03fe7b3872b2693847d73'
            ),
            body := jsonb_build_object(
                'type', 'dm',
                'room_id', NEW.room_id,
                'sender_id', NEW.sender_id,
                'content', COALESCE(NEW.content, ''),
                'image_url', COALESCE(NEW.image_url, '')
            )
        );
    END IF;
    RETURN NEW;
END $function$;

-- ---------- オープンチャット通知: content / image_url を渡す ----------
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
            url := 'https://ljgvqdcailabzuutaeha.supabase.co/functions/v1/notify_trigger',
            headers := jsonb_build_object(
                'Content-Type', 'application/json',
                'x-notify-secret', '4a5d3df69e9baa4456e120a8b1fc45c924730ded80c03fe7b3872b2693847d73'
            ),
            body := jsonb_build_object(
                'type', 'open_chat',
                'room_id', NEW.room_id,
                'sender_id', NEW.user_id,
                'content', COALESCE(NEW.content, ''),
                'image_url', COALESCE(NEW.image_url, '')
            )
        );
    END IF;
    RETURN NEW;
END $function$;
