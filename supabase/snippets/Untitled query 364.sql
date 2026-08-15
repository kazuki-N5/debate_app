-- BBS機能を利用するために必要なカラムを追加します。
-- ※すでにpasswordカラムが存在することを前提としています。
ALTER TABLE rooms_v2 ADD COLUMN IF NOT EXISTS is_bbs BOOLEAN DEFAULT FALSE;
ALTER TABLE rooms_v2 ADD COLUMN IF NOT EXISTS challenger_id UUID NULL;

-- 1. BBSルームの作成 (1人1つまでの制限付き)
CREATE OR REPLACE FUNCTION create_bbs_room(
    p_user_id UUID,
    p_theme TEXT,
    p_choice1 TEXT,
    p_choice2 TEXT,
    p_password TEXT
) RETURNS json AS $$
DECLARE
    existing_room_id UUID;
    new_room_id UUID;
    room_data RECORD;
    v_theme_s BOOLEAN;
BEGIN
    -- 既に募集中の部屋（自分がホストで、まだマッチング成立していない）があるかチェック
    SELECT id INTO existing_room_id FROM rooms_v2
    WHERE player1_id = p_user_id AND is_bbs = TRUE AND player2_id IS NULL;

    IF existing_room_id IS NOT NULL THEN
        RETURN json_build_object('success', false, 'error', 'ALREADY_EXISTS');
    END IF;

    -- p_theme が空でなければ theme_s を TRUE にする
    v_theme_s := (p_theme IS NOT NULL AND p_theme <> '');

    -- INSERTして結果を返す (theme_s を動的に設定することで、空の場合はランダムテーマで上書きさせる)
    INSERT INTO rooms_v2 (player1_id, current_theme, current_choice1, current_choice2, password, is_bbs, theme_s)
    VALUES (p_user_id, p_theme, p_choice1, p_choice2, p_password, TRUE, v_theme_s)
    RETURNING * INTO room_data;

    RETURN json_build_object('success', true, 'room', row_to_json(room_data));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 2. BBSルームの削除 (トランザクションを用いた安全な削除)
CREATE OR REPLACE FUNCTION delete_bbs_room(
    p_room_id UUID,
    p_user_id UUID
) RETURNS json AS $$
BEGIN
    -- 自分が立てた未成立のBBS部屋のみ削除できる
    DELETE FROM rooms_v2 
    WHERE id = p_room_id AND player1_id = p_user_id AND is_bbs = TRUE AND player2_id IS NULL;

    IF FOUND THEN
        RETURN json_build_object('success', true);
    ELSE
        RETURN json_build_object('success', false, 'error', 'NOT_FOUND_OR_UNAUTHORIZED');
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 3. BBSルームへの申し込み
CREATE OR REPLACE FUNCTION apply_bbs_room(
    p_room_id UUID,
    p_user_id UUID,
    p_password TEXT
) RETURNS json AS $$
DECLARE
    target_room RECORD;
BEGIN
    -- 対象の部屋をロックして取得
    SELECT * INTO target_room FROM rooms_v2 WHERE id = p_room_id FOR UPDATE;

    IF NOT FOUND THEN
        RETURN json_build_object('success', false, 'error', 'ROOM_NOT_FOUND');
    END IF;

    -- ★ 二重応募防止: すでに他の部屋に応募中でないかチェック
    IF EXISTS (
        SELECT 1 FROM rooms_v2 
        WHERE challenger_id = p_user_id AND player2_id IS NULL AND is_bbs = TRUE
    ) THEN
        RETURN json_build_object('success', false, 'error', 'ALREADY_APPLYING_BBS');
    END IF;

    IF target_room.player2_id IS NOT NULL THEN
        RETURN json_build_object('success', false, 'error', 'ALREADY_MATCHED');
    END IF;

    IF target_room.challenger_id IS NOT NULL THEN
        RETURN json_build_object('success', false, 'error', 'ALREADY_CHALLENGED');
    END IF;

    -- パスワードが設定されている場合のチェック
    IF target_room.password IS NOT NULL AND target_room.password != '' THEN
        IF p_password IS NULL OR target_room.password != p_password THEN
            RETURN json_build_object('success', false, 'error', 'INVALID_PASSWORD');
        END IF;
    END IF;

    -- 申し込み成功：challenger_id をセット
    UPDATE rooms_v2 SET challenger_id = p_user_id WHERE id = p_room_id;

    RETURN json_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 4. BBSルームの申し込み承認・拒否
CREATE OR REPLACE FUNCTION approve_bbs_room(
    p_room_id UUID,
    p_user_id UUID,
    p_approve BOOLEAN
) RETURNS json AS $$
DECLARE
    target_room RECORD;
BEGIN
    -- 対象の部屋をロックして取得
    SELECT * INTO target_room FROM rooms_v2 WHERE id = p_room_id AND player1_id = p_user_id FOR UPDATE;
    
    IF NOT FOUND THEN
        RETURN json_build_object('success', false, 'error', 'ROOM_NOT_FOUND_OR_UNAUTHORIZED');
    END IF;

    IF target_room.challenger_id IS NULL THEN
        RETURN json_build_object('success', false, 'error', 'NO_CHALLENGER');
    END IF;

    IF p_approve = TRUE THEN
        -- 承認：challenger_id を player2_id に移動
        UPDATE rooms_v2 
        SET player2_id = target_room.challenger_id, challenger_id = NULL 
        WHERE id = p_room_id;
    ELSE
        -- 拒否：challenger_id を空に戻して再募集
        UPDATE rooms_v2 
        SET challenger_id = NULL 
        WHERE id = p_room_id;
    END IF;

    RETURN json_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 5. 募集中のBBSルーム一覧を取得 (パスワード自体はクライアントに返さない)
CREATE OR REPLACE FUNCTION get_bbs_rooms() RETURNS json AS $$
DECLARE
    result json;
BEGIN
    SELECT COALESCE(json_agg(
        json_build_object(
            'id', r.id,
            'player1_id', r.player1_id,
            'theme', r.current_theme,
            'choice1', r.current_choice1,
            'choice2', r.current_choice2,
            'has_password', (r.password IS NOT NULL AND r.password != ''),
            'created_at', r.created_at,
            'user', json_build_object(
                'id', u.id,
                'name', u.name,
                'profile_icon', u.profile_icon,
                'rate', u.rate,
                'wins', u.wins,
                'losses', u.losses,
                'draws', u.draws
            )
        ) ORDER BY r.created_at DESC
    ), '[]'::json) INTO result
    FROM rooms_v2 r
    LEFT JOIN users u ON r.player1_id = u.id
    WHERE r.is_bbs = TRUE AND r.player2_id IS NULL;

    RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 6. BBSルームの申し込みをキャンセルする (ゲスト側)
CREATE OR REPLACE FUNCTION cancel_bbs_application(
    p_user_id UUID
) RETURNS json AS $$
DECLARE
    target_room RECORD;
BEGIN
    -- 自分が応募している部屋をロックして取得
    SELECT * INTO target_room FROM rooms_v2 
    WHERE challenger_id = p_user_id AND player2_id IS NULL AND is_bbs = TRUE 
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN json_build_object('success', false, 'error', 'NO_APPLICATION_FOUND');
    END IF;

    -- 申し込みを解除 (challenger_id を NULL に戻す)
    UPDATE rooms_v2 SET challenger_id = NULL WHERE id = target_room.id;
    RETURN json_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 7. ランダムマッチ/フレンドマッチ用 (join_room_v2) をオーバーライドし、二重応募チェックを追加
CREATE OR REPLACE FUNCTION "public"."join_room_v2"("p_user_id" "uuid", "p_room_password" "text", "p_room_theme" "text", "p_room_choice1" "text", "p_room_choice2" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql"
    AS $$
DECLARE target_room_id UUID; room_data JSONB; v_theme_provided BOOLEAN;
BEGIN
    -- ★ 二重応募防止: すでにBBS部屋に応募中でないかチェック
    IF EXISTS (
        SELECT 1 FROM rooms_v2 
        WHERE challenger_id = p_user_id AND player2_id IS NULL AND is_bbs = TRUE
    ) THEN
        RETURN jsonb_build_object('success', false, 'error', 'ALREADY_APPLYING_BBS');
    END IF;

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
END; $$;

ALTER FUNCTION "public"."join_room_v2"("p_user_id" "uuid", "p_room_password" "text", "p_room_theme" "text", "p_room_choice1" "text", "p_room_choice2" "text") OWNER TO "postgres";