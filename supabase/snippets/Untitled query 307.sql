
-- ============================================================
-- Migration: resba_notification_invite_id
-- レスバ系のアプリ内通知(notifications)から、該当する battle_invites を
-- 引き当てられるようにする
--  ・notifications.invite_id 列を追加
--  ・レスバ3種の通知トリガーで invite_id を記録する
--  ・RPC get_resba_invite: 通知タップ時に対象レスバ1件を取得する
-- ============================================================

-- ---------- 1. notifications に invite_id を追加 ----------
ALTER TABLE public.notifications
  ADD COLUMN IF NOT EXISTS invite_id uuid;

ALTER TABLE public.notifications
  DROP CONSTRAINT IF EXISTS notifications_invite_id_fkey;

ALTER TABLE public.notifications
  ADD CONSTRAINT notifications_invite_id_fkey
  FOREIGN KEY (invite_id) REFERENCES public.battle_invites(id)
  ON DELETE SET NULL;

DROP INDEX IF EXISTS idx_notifications_invite;

CREATE INDEX idx_notifications_invite
  ON public.notifications (invite_id);

-- ---------- 2. レスバ3種の通知トリガーを invite_id 込みで更新 ----------

-- レスバが届いた（指名型）
CREATE OR REPLACE FUNCTION public.notify_resba_invite()
  RETURNS trigger
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_actor_name text;
  v_post_id    uuid;
  v_comment_id uuid;
BEGIN
  IF NEW.target_user_id IS NOT NULL AND NEW.target_user_id <> NEW.sender_id THEN
    IF NEW.attach_type = 'post' THEN
      v_post_id := NEW.attach_id;
    ELSIF NEW.attach_type = 'comment' THEN
      v_comment_id := NEW.attach_id;
    END IF;

    INSERT INTO public.notifications (user_id, actor_id, type, post_id, comment_id, count, actor_ids, invite_id)
    VALUES (NEW.target_user_id, NEW.sender_id, 'resba_invite', v_post_id, v_comment_id, 1, ARRAY[NEW.sender_id], NEW.id);

    SELECT name INTO v_actor_name FROM public.users WHERE id = NEW.sender_id;
    PERFORM net.http_post(
      url := 'http://192.168.11.52:54321/functions/v1/notify_trigger',
      headers := jsonb_build_object('Content-Type', 'application/json', 'x-notify-secret', 'YOUR_NOTIFY_SECRET'),
      body := jsonb_build_object('user_id', NEW.target_user_id, 'type', 'resba_invite', 'actor_name', v_actor_name)
    );
  END IF;
  RETURN NEW;
END;
$function$;

-- 承諾（成立）
CREATE OR REPLACE FUNCTION public.notify_resba_accepted()
  RETURNS trigger
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_actor_name text;
BEGIN
  IF NEW.status = 'accepted' AND OLD.status = 'pending' AND NEW.responder_id IS NOT NULL THEN
    INSERT INTO public.notifications (user_id, actor_id, type, count, actor_ids, invite_id)
    VALUES (NEW.sender_id, NEW.responder_id, 'resba_accepted', 1, ARRAY[NEW.responder_id], NEW.id);

    SELECT name INTO v_actor_name FROM public.users WHERE id = NEW.responder_id;
    PERFORM net.http_post(
      url := 'http://192.168.11.52:54321/functions/v1/notify_trigger',
      headers := jsonb_build_object('Content-Type', 'application/json', 'x-notify-secret', 'YOUR_NOTIFY_SECRET'),
      body := jsonb_build_object('user_id', NEW.sender_id, 'type', 'resba_accepted', 'actor_name', v_actor_name)
    );
  END IF;
  RETURN NEW;
END;
$function$;

-- 拒否
CREATE OR REPLACE FUNCTION public.notify_resba_declined()
  RETURNS trigger
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_actor_id   uuid;
  v_actor_name text;
BEGIN
  IF NEW.status = 'declined' AND OLD.status = 'pending' THEN
    v_actor_id := COALESCE(NEW.responder_id, NEW.target_user_id);
    IF v_actor_id IS NOT NULL AND v_actor_id <> NEW.sender_id THEN
      INSERT INTO public.notifications (user_id, actor_id, type, count, actor_ids, invite_id)
      VALUES (NEW.sender_id, v_actor_id, 'resba_declined', 1, ARRAY[v_actor_id], NEW.id);

      SELECT name INTO v_actor_name FROM public.users WHERE id = v_actor_id;
      PERFORM net.http_post(
        url := 'http://192.168.11.52:54321/functions/v1/notify_trigger',
        headers := jsonb_build_object('Content-Type', 'application/json', 'x-notify-secret', 'YOUR_NOTIFY_SECRET'),
        body := jsonb_build_object('user_id', NEW.sender_id, 'type', 'resba_declined', 'actor_name', v_actor_name)
      );
    END IF;
  END IF;
  RETURN NEW;
END;
$function$;

-- ---------- 3. RPC: レスバ1件を取得（通知タップ時） ----------
-- アクセス: post/comment 添付は全員可、dm 添付は当事者（送信者 or 対象者）のみ
CREATE OR REPLACE FUNCTION public.get_resba_invite(p_invite_id uuid, p_user_id uuid)
  RETURNS json
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_result json;
BEGIN
  SELECT json_build_object(
      'id', b.id,
      'sender_id', b.sender_id,
      'sender_name', u.name,
      'sender_avatar', u.avatar_url,
      'sender_trophy', u.trophy,
      'attach_type', b.attach_type,
      'attach_id', b.attach_id,
      'target_user_id', b.target_user_id,
      'theme', b.theme,
      'choice1', b.choice1,
      'choice2', b.choice2,
      'status', b.status,
      'responder_id', b.responder_id,
      'battle_room_id', b.battle_room_id,
      'created_at', b.created_at,
      'responded_at', b.responded_at,
      'is_sender', (b.sender_id = p_user_id),
      'is_target', (b.target_user_id = p_user_id),
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
      ),
      'application_count', (
        SELECT count(*) FROM battle_invite_applications a
         WHERE a.invite_id = b.id AND a.status = 'pending'
      )
    ) INTO v_result
  FROM battle_invites b
  LEFT JOIN users u ON u.id = b.sender_id
  WHERE b.id = p_invite_id
    AND (b.attach_type IN ('post', 'comment')
         OR p_user_id IN (b.sender_id, b.target_user_id));

  RETURN v_result;
END;
$function$;

GRANT ALL ON FUNCTION public.get_resba_invite(uuid, uuid) TO anon;
GRANT ALL ON FUNCTION public.get_resba_invite(uuid, uuid) TO authenticated;
GRANT ALL ON FUNCTION public.get_resba_invite(uuid, uuid) TO service_role;
