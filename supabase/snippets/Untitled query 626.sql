-- 投稿のいいねカウント更新トリガー関数を SECURITY DEFINER に変更
CREATE OR REPLACE FUNCTION public.update_bbs_post_likes_count()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
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

-- コメントのいいねカウント更新トリガー関数を SECURITY DEFINER に変更
CREATE OR REPLACE FUNCTION public.update_bbs_comment_likes_count()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
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