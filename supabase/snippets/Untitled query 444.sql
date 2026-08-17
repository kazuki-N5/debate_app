-- 1. `member_count` カラムを追加
ALTER TABLE public.open_chat_rooms ADD COLUMN IF NOT EXISTS member_count BIGINT DEFAULT 0;

-- 2. 既存の `member_count` を現在の `open_chat_members` と同期（バックフィル）
UPDATE public.open_chat_rooms r
SET member_count = (SELECT COUNT(*) FROM public.open_chat_members m WHERE m.room_id = r.id);

-- 3. トリガー関数の作成
CREATE OR REPLACE FUNCTION public.update_open_chat_member_count()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE public.open_chat_rooms
    SET member_count = member_count + 1
    WHERE id = NEW.room_id;
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE public.open_chat_rooms
    SET member_count = member_count - 1
    WHERE id = OLD.room_id;
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$;

-- 4. トリガーの適用（既存のトリガーがあれば削除して再作成）
DROP TRIGGER IF EXISTS trg_update_open_chat_member_count ON public.open_chat_members;
CREATE TRIGGER trg_update_open_chat_member_count
AFTER INSERT OR DELETE ON public.open_chat_members
FOR EACH ROW
EXECUTE FUNCTION public.update_open_chat_member_count();

-- 5. RPCの書き換え: COUNT(*) をやめて、member_count を参照するように変更
CREATE OR REPLACE FUNCTION public.get_open_chat_rooms_with_status(
  p_search_query text DEFAULT NULL
)
RETURNS TABLE (
  id uuid,
  name text,
  description text,
  icon_url text,
  owner_id uuid,
  created_at timestamp with time zone,
  member_count bigint,
  is_joined boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id uuid := auth.uid();
BEGIN
  RETURN QUERY
  SELECT 
    r.id,
    r.name,
    r.description,
    r.icon_url,
    r.owner_id,
    r.created_at,
    r.member_count,
    EXISTS (SELECT 1 FROM public.open_chat_members m2 WHERE m2.room_id = r.id AND m2.user_id = v_user_id) AS is_joined
  FROM 
    public.open_chat_rooms r
  WHERE 
    -- 検索クエリが指定されていれば名前か説明文でフィルタリング
    (p_search_query IS NULL OR p_search_query = '' OR r.name ILIKE '%' || p_search_query || '%' OR r.description ILIKE '%' || p_search_query || '%')
  ORDER BY 
    -- 自分が参加しているものを最優先(上に固定)
    EXISTS (SELECT 1 FROM public.open_chat_members m2 WHERE m2.room_id = r.id AND m2.user_id = v_user_id) DESC,
    -- 次に人数が多い順
    r.member_count DESC,
    -- 人数が同じ場合は新しい順
    r.created_at DESC;
END;
$$;
