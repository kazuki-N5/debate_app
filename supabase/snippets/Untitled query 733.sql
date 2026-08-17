-- 返信のいいね数を増やす
CREATE OR REPLACE FUNCTION public.increment_comment_likes_count (p_comment_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
BEGIN
  UPDATE bbs_comments SET likes_count = COALESCE(likes_count, 0) + 1 WHERE id = p_comment_id;
END;
$function$;

-- 返信のいいね数を減らす
CREATE OR REPLACE FUNCTION public.decrement_comment_likes_count (p_comment_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
BEGIN
  UPDATE bbs_comments SET likes_count = GREATEST(COALESCE(likes_count, 0) - 1, 0) WHERE id = p_comment_id;
END;
$function$;

-- ポストのいいね数を増やす
CREATE OR REPLACE FUNCTION public.increment_likes_count (post_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
BEGIN
  UPDATE bbs_posts SET likes_count = COALESCE(likes_count, 0) + 1 WHERE id = post_id;
END;
$function$;

-- ポストのいいね数を減らす
CREATE OR REPLACE FUNCTION public.decrement_likes_count (post_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
BEGIN
  UPDATE bbs_posts SET likes_count = GREATEST(COALESCE(likes_count, 0) - 1, 0) WHERE id = post_id;
END;
$function$;

-- ポストの返信数を増やす
CREATE OR REPLACE FUNCTION public.increment_replies_count (p_post_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
BEGIN
  UPDATE bbs_posts SET replies_count = COALESCE(replies_count, 0) + 1 WHERE id = p_post_id;
END;
$function$;1