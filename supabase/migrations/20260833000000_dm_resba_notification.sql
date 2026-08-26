-- ============================================================
-- Migration: dm_resba_notification
-- 1. 古い不要なレスバ通知トリガー（指名型用）を削除・停止
-- 2. DMレスバ（attach_type = 'dm'）送信時に相手へ通知する専用トリガーを新設
-- ============================================================

-- ---------- 1. 古いトリガー・関数の削除 ----------
DROP TRIGGER IF EXISTS trg_notify_resba_invite ON public.battle_invites;
DROP TRIGGER IF EXISTS trg_notify_resba_accepted ON public.battle_invites;
DROP TRIGGER IF EXISTS trg_notify_resba_declined ON public.battle_invites;
DROP FUNCTION IF EXISTS public.notify_resba_invite();
DROP FUNCTION IF EXISTS public.notify_resba_accepted();
DROP FUNCTION IF EXISTS public.notify_resba_declined();

-- ---------- 2. DMレスバ通知トリガー関数 ----------
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
            url := 'https://ljgvqdcailabzuutaeha.supabase.co/functions/v1/notify_trigger',
            headers := jsonb_build_object(
              'Content-Type', 'application/json',
              'x-notify-secret', '4a5d3df69e9baa4456e120a8b1fc45c924730ded80c03fe7b3872b2693847d73'
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

-- ---------- 3. 新トリガーの登録 ----------
CREATE TRIGGER trg_notify_dm_resba_invite
  AFTER INSERT ON public.battle_invites
  FOR EACH ROW EXECUTE FUNCTION public.notify_dm_resba_invite();
