CREATE OR REPLACE FUNCTION public.leave_open_chat_room(
  p_room_id uuid
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id uuid := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'UNAUTHORIZED');
  END IF;

  DELETE FROM public.open_chat_members 
  WHERE room_id = p_room_id AND user_id = v_user_id;

  IF FOUND THEN
    RETURN json_build_object('success', true);
  ELSE
    RETURN json_build_object('success', false, 'error', 'NOT_FOUND_OR_ALREADY_LEFT');
  END IF;
END;
$$;
