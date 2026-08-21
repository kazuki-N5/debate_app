-- send_dm_resba のタイポ（user_id -> sender_id）を修正
CREATE OR REPLACE FUNCTION public.send_dm_resba(
  p_sender_id  uuid,
  p_message_id uuid,
  p_theme      text,
  p_choice1    text,
  p_choice2    text
)
  RETURNS json
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_msg_user uuid;
  v_invite   json;
BEGIN
  IF public.is_user_in_battle(p_sender_id) THEN
    RETURN json_build_object('success', false, 'error', 'IN_BATTLE');
  END IF;

  SELECT sender_id INTO v_msg_user FROM dm_messages WHERE id = p_message_id;
  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'MESSAGE_NOT_FOUND');
  END IF;
  IF v_msg_user <> p_sender_id THEN
    RETURN json_build_object('success', false, 'error', 'NOT_MESSAGE_OWNER');
  END IF;

  INSERT INTO battle_invites (sender_id, attach_type, attach_id, target_user_id, theme, choice1, choice2)
  VALUES (
    p_sender_id, 'dm', p_message_id, NULL,
    COALESCE(NULLIF(p_theme, ''), 'レスバ対戦'),
    NULLIF(p_choice1, ''), NULLIF(p_choice2, '')
  )
  RETURNING to_jsonb(battle_invites.*)::text::json INTO v_invite;

  RETURN json_build_object('success', true, 'invite', v_invite);
END;
$function$;
