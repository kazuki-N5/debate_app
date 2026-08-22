-- ============================================================
-- Migration: resba_notification_flag
-- 返信通知に「⚔️ レスバ付き」を表示するためのフラグ
--  ・notifications に has_resba 列を追加
--  ・battle_invites に comment 型のレスバが入ったら、
--    そのコメントの既存の返信通知（reply_comment / comment）を
--    has_resba = true に更新するトリガー
-- ※ 別途 resba_invite 通知は作らない（返信通知に統合）
-- ============================================================

ALTER TABLE public.notifications
  ADD COLUMN IF NOT EXISTS has_resba boolean DEFAULT false NOT NULL;

-- ---------- レスバ添付時に該当コメントの通知へフラグを付ける ----------
CREATE FUNCTION public.mark_resba_on_comment_notification()
  RETURNS trigger
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
BEGIN
  IF NEW.attach_type = 'comment' THEN
    UPDATE public.notifications
       SET has_resba = true
     WHERE comment_id = NEW.attach_id
       AND type IN ('reply_comment', 'comment');
  END IF;
  RETURN NEW;
END;
$function$;

CREATE TRIGGER trg_mark_resba_on_comment_notification
  AFTER INSERT ON public.battle_invites
  FOR EACH ROW EXECUTE FUNCTION public.mark_resba_on_comment_notification();
