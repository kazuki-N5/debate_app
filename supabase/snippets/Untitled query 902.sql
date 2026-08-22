-- ============================================================
-- Migration: fix_resba_list_functions
-- get_dm_resbas / get_post_resbas の json || json エラー修正
--
-- 原因: PostgreSQL には json || json 演算子が存在しない
--   (jsonb || jsonb はあるが json には無い。ERROR 42883)
--   旧実装はループ内で json 配列を || で結合しており、
--   「結合が発生する場面」（DMメッセージやコメントが1件以上ある）で
--   必ずエラーになり、レスバ一覧が取得できなかった。
--
-- 修正: json_agg + json_array_elements による安全な結合に置き換え
-- ============================================================

CREATE OR REPLACE FUNCTION public.get_dm_resbas(p_room_id uuid, p_user_id uuid)
  RETURNS json
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_result json;
BEGIN
  SELECT COALESCE(json_agg(t.item), '[]'::json) INTO v_result
  FROM (
    SELECT json_array_elements(public.get_resba('dm', m.id, p_user_id)) AS item
    FROM dm_messages m
    WHERE m.room_id = p_room_id
  ) t;
  RETURN v_result;
END;
$function$;

GRANT ALL ON FUNCTION public.get_dm_resbas(uuid, uuid) TO anon;
GRANT ALL ON FUNCTION public.get_dm_resbas(uuid, uuid) TO authenticated;
GRANT ALL ON FUNCTION public.get_dm_resbas(uuid, uuid) TO service_role;

CREATE OR REPLACE FUNCTION public.get_post_resbas(p_post_id uuid, p_user_id uuid)
  RETURNS json
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_result json;
BEGIN
  SELECT COALESCE(json_agg(t.item), '[]'::json) INTO v_result
  FROM (
    -- ポスト本体のレスバ
    SELECT json_array_elements(public.get_resba('post', p_post_id, p_user_id)) AS item
    UNION ALL
    -- コメント（返信）のレスバ
    SELECT json_array_elements(public.get_resba('comment', c.id, p_user_id))
    FROM bbs_comments c
    WHERE c.post_id = p_post_id
  ) t;
  RETURN v_result;
END;
$function$;

GRANT ALL ON FUNCTION public.get_post_resbas(uuid, uuid) TO anon;
GRANT ALL ON FUNCTION public.get_post_resbas(uuid, uuid) TO authenticated;
GRANT ALL ON FUNCTION public.get_post_resbas(uuid, uuid) TO service_role;
