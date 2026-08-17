-- ユーザーごとの参加状態とメンバー数を含めたオープンチャット一覧を取得する関数
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
    (SELECT COUNT(*) FROM public.open_chat_members m WHERE m.room_id = r.id) AS member_count,
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
    (SELECT COUNT(*) FROM public.open_chat_members m WHERE m.room_id = r.id) DESC,
    -- 人数が同じ場合は新しい順
    r.created_at DESC;
END;
$$;
