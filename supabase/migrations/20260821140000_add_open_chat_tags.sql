-- 1. open_chat_rooms テーブルに tags 配列カラムを追加
ALTER TABLE public.open_chat_rooms 
ADD COLUMN IF NOT EXISTS tags text[] DEFAULT '{}'::text[];

-- 2. 既存のレコードの tags が null の場合は空配列に初期化
UPDATE public.open_chat_rooms 
SET tags = '{}'::text[] 
WHERE tags IS NULL;

-- 3. タグ検索を高速化する GIN インデックスの作成
CREATE INDEX IF NOT EXISTS idx_open_chat_rooms_tags 
ON public.open_chat_rooms USING gin (tags);

-- 4. create_open_chat_room RPC 関数の更新（p_tags 引数追加）
CREATE OR REPLACE FUNCTION public.create_open_chat_room (
  p_name           text,
  p_description    text,
  p_icon_url       text,
  p_background_url text DEFAULT NULL::text,
  p_password       text DEFAULT NULL::text,
  p_tags           text[] DEFAULT '{}'::text[]
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  AS $function$
DECLARE
    v_room_id UUID;
    v_user_id UUID;
BEGIN
    -- 現在のユーザーIDを取得
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', '認証されていません');
    END IF;

    -- ルームの作成 (tags カラムを含める)
    INSERT INTO open_chat_rooms (name, description, icon_url, background_url, password, owner_id, tags)
    VALUES (p_name, p_description, p_icon_url, p_background_url, p_password, v_user_id, COALESCE(p_tags, '{}'::text[]))
    RETURNING id INTO v_room_id;

    -- 作成者をメンバーとして追加 (Admin role)
    INSERT INTO open_chat_members (room_id, user_id, role)
    VALUES (v_room_id, v_user_id, 'admin');

    RETURN jsonb_build_object('success', true, 'room_id', v_room_id);
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$function$;

-- 5. get_open_chat_rooms_with_status RPC 関数の更新（tags の返却およびタグ検索対応）
-- 戻り値の型が変わるため事前に DROP
DROP FUNCTION IF EXISTS public.get_open_chat_rooms_with_status(text);

CREATE OR REPLACE FUNCTION public.get_open_chat_rooms_with_status(
  p_search_query text DEFAULT NULL
)
RETURNS TABLE (
  id uuid,
  name text,
  description text,
  icon_url text,
  background_url text,
  password text,
  owner_id uuid,
  created_at timestamp with time zone,
  member_count bigint,
  is_joined boolean,
  tags text[]
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_clean_query text := REPLACE(COALESCE(p_search_query, ''), '#', '');
BEGIN
  RETURN QUERY
  SELECT 
    r.id,
    r.name,
    r.description,
    r.icon_url,
    r.background_url,
    r.password,
    r.owner_id,
    r.created_at,
    r.member_count,
    EXISTS (SELECT 1 FROM public.open_chat_members m2 WHERE m2.room_id = r.id AND m2.user_id = v_user_id) AS is_joined,
    COALESCE(r.tags, '{}'::text[]) AS tags
  FROM 
    public.open_chat_rooms r
  WHERE 
    -- 検索クエリが指定されていれば名前、説明文、またはタグでフィルタリング
    (
      p_search_query IS NULL 
      OR p_search_query = '' 
      OR r.name ILIKE '%' || p_search_query || '%' 
      OR r.description ILIKE '%' || p_search_query || '%'
      OR (v_clean_query <> '' AND v_clean_query = ANY(r.tags))
      OR (v_clean_query <> '' AND EXISTS (SELECT 1 FROM unnest(r.tags) t WHERE t ILIKE '%' || v_clean_query || '%'))
    )
  ORDER BY 
    -- 自分が参加しているものを最優先(上に固定)
    EXISTS (SELECT 1 FROM public.open_chat_members m2 WHERE m2.room_id = r.id AND m2.user_id = v_user_id) DESC,
    -- 次に人数が多い順
    r.member_count DESC,
    -- 人数が同じ場合は新しい順
    r.created_at DESC;
END;
$$;
