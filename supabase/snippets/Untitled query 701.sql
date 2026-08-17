-- 1. Storageバケットの作成（オープンチャットの画像用）
INSERT INTO storage.buckets (id, name, public) 
VALUES ('open_chat_images', 'open_chat_images', true)
ON CONFLICT (id) DO NOTHING;

-- StorageのRLSポリシー（認証ユーザーが画像をアップロードでき、誰でも閲覧できるようにする）
CREATE POLICY "Public Access" ON storage.objects FOR SELECT USING ( bucket_id = 'open_chat_images' );
CREATE POLICY "Auth Users Insert" ON storage.objects FOR INSERT WITH CHECK ( bucket_id = 'open_chat_images' AND auth.role() = 'authenticated' );
CREATE POLICY "Auth Users Update" ON storage.objects FOR UPDATE USING ( bucket_id = 'open_chat_images' AND auth.role() = 'authenticated' );

-- 2. カラムの追加
ALTER TABLE open_chat_rooms ADD COLUMN IF NOT EXISTS background_url TEXT;
ALTER TABLE open_chat_rooms ADD COLUMN IF NOT EXISTS password TEXT;

-- 3. 既存のルーム作成関数の置き換え
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

    -- 作成者をメンバーとして追加 (Owner role)
    INSERT INTO open_chat_members (room_id, user_id, role)
    VALUES (v_room_id, v_user_id, 'owner');

    RETURN jsonb_build_object('success', true, 'room_id', v_room_id);
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;