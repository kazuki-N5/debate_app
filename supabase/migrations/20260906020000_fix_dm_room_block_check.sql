-- ============================================================
-- Migration: fix_dm_room_block_check
-- get_or_create_dm_room のブロック判定を「新規作成のみ」に変更
--
-- 背景:
--   旧仕様はブロック判定を先に行うため、既に1対1のルームが
--   存在する場合でも BLOCKED エラーを返し、ブロック中に
--   過去チャットを開けなかった。
--
-- 変更後:
--   1) 既存ルームが見つかった場合はブロック中でもルームIDを返す
--      （チャットの閲覧は可能。送信は dm_messages の INSERT RLS
--      （is_dm_room_blocked）で引き続き拒否される）
--   2) ブロック判定は「新規ルーム作成」の直前でのみ行う
--      （一度もやり取りしていない相手との新規DM開始は従来通り拒否）
-- ============================================================

CREATE OR REPLACE FUNCTION public.get_or_create_dm_room(other_user_id UUID)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
    v_my_id UUID;
    v_room_id UUID;
BEGIN
    -- 自分のユーザーIDを取得
    v_my_id := auth.uid();

    IF v_my_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    IF v_my_id = other_user_id THEN
        RAISE EXCEPTION 'BLOCKED';
    END IF;

    -- 既に1対1のルームが存在するか確認 (双方のIDがメンバーとして属しているルーム)
    SELECT r.id INTO v_room_id
    FROM dm_rooms r
    JOIN dm_room_members m1 ON r.id = m1.room_id AND m1.user_id = v_my_id
    JOIN dm_room_members m2 ON r.id = m2.room_id AND m2.user_id = other_user_id
    LIMIT 1;

    -- 既存ルームがある場合はブロック中でもルームIDを返す
    -- （dm_messages の SELECT RLS はメンバーなら読める / INSERT RLS は
    --   is_dm_room_blocked でブロック中の送信を拒否するため、閲覧のみ可能）
    IF v_room_id IS NOT NULL THEN
        RETURN v_room_id;
    END IF;

    -- ★ ブロック判定: どちらかがブロックしていたら「新規作成」を拒否
    IF public.is_user_blocked(v_my_id, other_user_id)
       OR public.is_user_blocked(other_user_id, v_my_id) THEN
        RAISE EXCEPTION 'BLOCKED';
    END IF;

    -- 存在しなければ作成
    INSERT INTO dm_rooms DEFAULT VALUES RETURNING id INTO v_room_id;
    INSERT INTO dm_room_members (room_id, user_id) VALUES (v_room_id, v_my_id);
    IF v_my_id != other_user_id THEN
        INSERT INTO dm_room_members (room_id, user_id) VALUES (v_room_id, other_user_id);
    END IF;

    RETURN v_room_id;
END;
$$;