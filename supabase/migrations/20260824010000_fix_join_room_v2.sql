-- ============================================================
-- Migration: fix_join_room_v2
-- 旧BBSフロー削除に伴い、join_room_v2 から存在しない challenger_id の参照を削除
-- ============================================================

CREATE OR REPLACE FUNCTION public.join_room_v2 (
  p_user_id       uuid,
  p_room_password text,
  p_room_theme    text,
  p_room_choice1  text,
  p_room_choice2  text
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  AS $function$
DECLARE 
  target_room_id UUID; 
  room_data JSONB; 
  v_theme_provided BOOLEAN;
BEGIN
    v_theme_provided := (p_room_theme IS NOT NULL AND p_room_theme != '' AND p_room_choice1 IS NOT NULL AND p_room_choice1 != '' AND p_room_choice2 IS NOT NULL AND p_room_choice2 != '');
    
    IF p_room_password IS NOT NULL THEN
      SELECT id INTO target_room_id FROM rooms_v2 WHERE player2_id IS NULL AND password = p_room_password AND player1_id != p_user_id LIMIT 1 FOR UPDATE SKIP LOCKED;
    ELSE
      SELECT id INTO target_room_id FROM rooms_v2 WHERE player2_id IS NULL AND password IS NULL AND player1_id != p_user_id LIMIT 1 FOR UPDATE SKIP LOCKED;
    END IF;
    
    IF target_room_id IS NOT NULL THEN
      UPDATE rooms_v2 SET player2_id = p_user_id, is_matched = true, updated_at = NOW(),
          current_theme = CASE WHEN theme_s = false AND v_theme_provided = true THEN p_room_theme ELSE current_theme END,
          current_choice1 = CASE WHEN theme_s = false AND v_theme_provided = true THEN p_room_choice1 ELSE current_choice1 END,
          current_choice2 = CASE WHEN theme_s = false AND v_theme_provided = true THEN p_room_choice2 ELSE current_choice2 END,
          theme_s = CASE WHEN theme_s = false AND v_theme_provided = true THEN true ELSE theme_s END
      WHERE id = target_room_id;
      SELECT to_jsonb(r) INTO room_data FROM rooms_v2 r WHERE r.id = target_room_id;
      RETURN jsonb_build_object('success', true, 'action', 'joined', 'room', room_data);
    ELSE
      INSERT INTO rooms_v2 (player1_id, password, current_theme, current_choice1, current_choice2, theme_s)
      VALUES (p_user_id, p_room_password, p_room_theme, p_room_choice1, p_room_choice2, v_theme_provided)
      RETURNING to_jsonb(rooms_v2.*) INTO room_data;
      RETURN jsonb_build_object('success', true, 'action', 'created', 'room', room_data);
    END IF;
END; 
$function$;

GRANT ALL ON FUNCTION public.join_room_v2(uuid, text, text, text, text) TO anon;
GRANT ALL ON FUNCTION public.join_room_v2(uuid, text, text, text, text) TO authenticated;
GRANT ALL ON FUNCTION public.join_room_v2(uuid, text, text, text, text) TO service_role;
