-- Fix get_dm_inbox uuid casting for PostgreSQL and ensure high-efficiency last_read_at diff logic

CREATE OR REPLACE FUNCTION public.get_dm_inbox(p_user_id UUID)
RETURNS TABLE (
    room_id          UUID,
    other_user_id    UUID,
    other_user_name  TEXT,
    other_avatar_url TEXT,
    last_message     TEXT,
    last_message_at  TIMESTAMPTZ,
    unread_count     BIGINT
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
BEGIN
    IF p_user_id IS DISTINCT FROM auth.uid() THEN
        RAISE EXCEPTION 'Not allowed';
    END IF;

    RETURN QUERY
        SELECT
            m.room_id,
            MAX(CASE WHEN mm.user_id <> p_user_id THEN mm.user_id::text END)::uuid AS other_user_id,
            MAX(CASE WHEN mm.user_id <> p_user_id THEN u.name END) AS other_user_name,
            MAX(CASE WHEN mm.user_id <> p_user_id THEN u.avatar_url END) AS other_avatar_url,
            (SELECT x.content FROM public.dm_messages x
              WHERE x.room_id = m.room_id ORDER BY x.created_at DESC LIMIT 1) AS last_message,
            (SELECT x.created_at FROM public.dm_messages x
              WHERE x.room_id = m.room_id ORDER BY x.created_at DESC LIMIT 1) AS last_message_at,
            (SELECT count(*) FROM public.dm_messages x
              WHERE x.room_id = m.room_id AND x.sender_id <> p_user_id
                AND x.created_at > COALESCE(
                    (SELECT lr.last_read_at FROM public.dm_room_members lr
                     WHERE lr.room_id = m.room_id AND lr.user_id = p_user_id),
                    '-infinity'::timestamptz)) AS unread_count
        FROM public.dm_room_members m
        JOIN public.dm_room_members mm ON mm.room_id = m.room_id AND mm.user_id <> p_user_id
        LEFT JOIN public.users u ON u.id = mm.user_id
        WHERE m.user_id = p_user_id
        GROUP BY m.room_id;
END $function$;

GRANT ALL ON FUNCTION public.get_dm_inbox(uuid) TO anon;
GRANT ALL ON FUNCTION public.get_dm_inbox(uuid) TO authenticated;
GRANT ALL ON FUNCTION public.get_dm_inbox(uuid) TO service_role;
