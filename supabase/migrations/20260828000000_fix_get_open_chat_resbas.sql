-- ============================================================
-- Migration: fix_get_open_chat_resbas
-- get_open_chat_resbas の json || json エラー修正
--
-- 原因: PostgreSQL には json || json 演算子が存在しない
--   (jsonb || jsonb はあるが json には無い。ERROR 42883)
--   get_dm_resbas と同様に json_agg + json_array_elements を使用して安全に結合する
-- ============================================================

CREATE OR REPLACE FUNCTION public.get_open_chat_resbas(p_room_id uuid, p_user_id uuid)
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
    SELECT json_array_elements(public.get_resba('open_chat', m.id, p_user_id)) AS item
    FROM open_chat_messages m
    WHERE m.room_id = p_room_id
  ) t;
  RETURN v_result;
END;
$function$;

GRANT ALL ON FUNCTION public.get_open_chat_resbas(uuid, uuid) TO anon;
GRANT ALL ON FUNCTION public.get_open_chat_resbas(uuid, uuid) TO authenticated;
GRANT ALL ON FUNCTION public.get_open_chat_resbas(uuid, uuid) TO service_role;
