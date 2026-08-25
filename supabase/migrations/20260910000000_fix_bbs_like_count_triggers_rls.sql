-- ==============================================================================
-- Migration: fix_bbs_like_count_triggers_rls
--
-- ★ 不具合 ▼
--   投稿/コメントに「いいね」を押すと赤いマーク(is_liked_by_me)は付くのに、
--   リロードすると like 数が 0 になる。
--
-- ★ 原因 ▼
--   bbs_posts.likes_count / bbs_comments.likes_count はトリガー
--   (update_bbs_post_likes_count / update_bbs_comment_likes_count)で自動加算される。
--   しかし、この 2 つのトリガー関数は **SECURITY DEFINER ではない**ため、
--   `authenticated` ロールの権限で実行される。
--
--   bbs_posts / bbs_comments には「自分の投稿・コメントのみ UPDATE 可能」という
--   RLS ポリシー(auth.uid() = user_id)があるため、
--   他ユーザーの投稿/コメントにいいねを押した瞬間の
--   `UPDATE bbs_posts SET likes_count = likes_count + 1 ...`
--   が RLS にブロックされ、0 行しか更新されない。
--
--   つまり:
--     - bbs_likes の INSERT は成功する（→ red mark = is_liked_by_me は残る）
--     - bbs_posts.likes_count は増えない（→ リロードで 0）
--
-- ★ 対応 ▼
--   1. カウンター用トリガー関数を SECURITY DEFINER にする（RLS をバイパス）
--   2. 既にズレた likes_count を実テーブルの行数で再同期する
-- ==============================================================================

-- ---------- 1. 投稿いいねカウンタートリガーを SECURITY DEFINER 化 ----------
CREATE OR REPLACE FUNCTION public.update_bbs_post_likes_count()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = 'public'
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


-- ---------- 2. コメントいいねカウンタートリガーを SECURITY DEFINER 化 ----------
CREATE OR REPLACE FUNCTION public.update_bbs_comment_likes_count()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = 'public'
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


-- ---------- 3. 既にズレた likes_count を再同期 ----------
-- (RLS で加算されなかった分を実テーブルの行数へ合わせる)
UPDATE public.bbs_posts p
   SET likes_count = (
     SELECT count(*) FROM public.bbs_likes l WHERE l.post_id = p.id
   );

UPDATE public.bbs_comments c
   SET likes_count = (
     SELECT count(*) FROM public.bbs_comment_likes cl WHERE cl.comment_id = c.id
   );
