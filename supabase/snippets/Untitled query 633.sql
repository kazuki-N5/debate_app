CREATE OR REPLACE FUNCTION create_open_chat_room(
    p_name TEXT,
    p_description TEXT,
    p_icon_url TEXT,
    p_background_url TEXT DEFAULT NULL,
    p_password TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_room_id UUID;
    v_user_id UUID;
BEGIN
    -- 現在のユーザーIDを取得
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', '認証されていません');
    END IF;

    -- ルームの作成
    INSERT INTO open_chat_rooms (name, description, icon_url, background_url, password, owner_id)
    VALUES (p_name, p_description, p_icon_url, p_background_url, p_password, v_user_id)
    RETURNING id INTO v_room_id;

    -- 作成者をメンバーとして追加 (Admin role に修正)
    INSERT INTO open_chat_members (room_id, user_id, role)
    VALUES (v_room_id, v_user_id, 'admin');

    RETURN jsonb_build_object('success', true, 'room_id', v_room_id);
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;