-- ============================================================
-- Migration: moderation_block_report
-- 審査対応: ユーザーブロック / 通報の強化
--  1. brock_user(ブロック)の堅牢化: 複合PK・インデックス・本人のみ操作できるRLS
--  2. prohibited(通報)の拡張: 通報者・理由・内容スナップショット・ステータス
--  3. ブロック判定ヘルパー関数 is_user_blocked
--  4. ブロック時はサーバー側で拒否(DMルーム作成 / DM送信 / レスバ応募・送信 / 対戦募集ルーム応募)
--  5. ランダムマッチングはブロック対象外(従来通り)
-- ============================================================

-- ---------- 1. brock_user の堅牢化 ----------
-- 重複(同一 user_id × block_user_id)を先に削除してから複合PKを張る
DELETE FROM public.brock_user a
USING public.brock_user b
WHERE a.id < b.id
  AND a.user_id = b.user_id
  AND a.block_user_id = b.block_user_id;

ALTER TABLE public.brock_user
  DROP CONSTRAINT IF EXISTS brock_user_pkey,
  ADD PRIMARY KEY (user_id, block_user_id);

-- 「自分がブロックされたか」の検索用インデックス(プロフィールのバン表示用)
CREATE INDEX IF NOT EXISTS idx_brock_user_blocked ON public.brock_user (block_user_id);

-- 既存の無制限RLS("Allow public insert access")を置き換え
DROP POLICY IF EXISTS "Allow public insert access" ON public.brock_user;
CREATE POLICY "自分のブロックのみ登録" ON public.brock_user
  FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "ブロック関係の当事者のみ参照" ON public.brock_user
  FOR SELECT USING (auth.uid() = user_id OR auth.uid() = block_user_id);
CREATE POLICY "ブロックした本人のみ解除" ON public.brock_user
  FOR DELETE USING (auth.uid() = user_id);

-- ---------- 2. prohibited(通報)の拡張 ----------
ALTER TABLE public.prohibited
  ADD COLUMN IF NOT EXISTS reporter_id uuid,
  ADD COLUMN IF NOT EXISTS reason text,
  ADD COLUMN IF NOT EXISTS content_type text,
  ADD COLUMN IF NOT EXISTS content_id uuid,
  ADD COLUMN IF NOT EXISTS content_snapshot text,
  ADD COLUMN IF NOT EXISTS status text NOT NULL DEFAULT 'pending';

-- 既存の無制限RLS("Allow all inserts")を置き換え(通報者は本人のみ・本人のみ参照可能)
DROP POLICY IF EXISTS "Allow all inserts" ON public.prohibited;
CREATE POLICY "通報は本人のみ登録" ON public.prohibited
  FOR INSERT WITH CHECK (auth.uid() = reporter_id);
CREATE POLICY "通報した本人のみ参照" ON public.prohibited
  FOR SELECT USING (auth.uid() = reporter_id);

-- ---------- 3. ブロック判定ヘルパー ----------
-- p_target が p_by をブロックしているか
CREATE OR REPLACE FUNCTION public.is_user_blocked(
  p_target uuid,
  p_by     uuid
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.brock_user
    WHERE user_id = p_target AND block_user_id = p_by
  );
$$;

GRANT EXECUTE ON FUNCTION public.is_user_blocked(uuid, uuid) TO anon;
GRANT EXECUTE ON FUNCTION public.is_user_blocked(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_user_blocked(uuid, uuid) TO service_role;

-- ---------- 4. DM: ブロック時はルーム作成を拒否 ----------
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

    -- ★ ブロック判定: どちらかがブロックしていたら拒否
    IF public.is_user_blocked(v_my_id, other_user_id)
       OR public.is_user_blocked(other_user_id, v_my_id) THEN
        RAISE EXCEPTION 'BLOCKED';
    END IF;

    -- 既に1対1のルームが存在するか確認 (双方のIDがメンバーとして属しているルーム)
    SELECT r.id INTO v_room_id
    FROM dm_rooms r
    JOIN dm_room_members m1 ON r.id = m1.room_id AND m1.user_id = v_my_id
    JOIN dm_room_members m2 ON r.id = m2.room_id AND m2.user_id = other_user_id
    LIMIT 1;

    -- 存在しなければ作成
    IF v_room_id IS NULL THEN
        -- ルーム作成
        INSERT INTO dm_rooms DEFAULT VALUES RETURNING id INTO v_room_id;

        -- 自分をメンバー追加
        INSERT INTO dm_room_members (room_id, user_id) VALUES (v_room_id, v_my_id);

        -- 相手をメンバー追加
        IF v_my_id != other_user_id THEN
            INSERT INTO dm_room_members (room_id, user_id) VALUES (v_room_id, other_user_id);
        END IF;
    END IF;

    RETURN v_room_id;
END;
$$;

-- ---------- 5. DM: ブロック中はメッセージ送信を拒否(RLS) ----------
-- RLS再帰を避けるためSECURITY DEFINER関数で判定する
CREATE OR REPLACE FUNCTION public.is_dm_room_blocked(p_room_id UUID)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.dm_room_members m
    WHERE m.room_id = p_room_id
      AND m.user_id <> auth.uid()
      AND (
        public.is_user_blocked(m.user_id, auth.uid())    -- 相手が自分をブロック
        OR public.is_user_blocked(auth.uid(), m.user_id) -- 自分が相手をブロック
      )
  );
$$;

GRANT EXECUTE ON FUNCTION public.is_dm_room_blocked(uuid) TO anon;
GRANT EXECUTE ON FUNCTION public.is_dm_room_blocked(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_dm_room_blocked(uuid) TO service_role;

DROP POLICY IF EXISTS "Users can insert messages in their rooms" ON public.dm_messages;
CREATE POLICY "Users can insert messages in their rooms" ON public.dm_messages
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.dm_room_members
            WHERE room_id = dm_messages.room_id AND user_id = auth.uid()
        )
        AND sender_id = auth.uid()
        AND NOT public.is_dm_room_blocked(dm_messages.room_id)
    );

-- ---------- 6. レスバ: ブロック時は応募・送信を拒否 ----------
-- apply_post_resba(ポスト/コメント型レスバへの応募)
CREATE OR REPLACE FUNCTION public.apply_post_resba(
  p_invite_id uuid,
  p_user_id   uuid
)
  RETURNS json
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_invite battle_invites%ROWTYPE;
BEGIN
  SELECT * INTO v_invite FROM battle_invites WHERE id = p_invite_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'INVITE_NOT_FOUND');
  END IF;
  IF v_invite.attach_type NOT IN ('post', 'comment') THEN
    RETURN json_build_object('success', false, 'error', 'NOT_POST_TYPE');
  END IF;
  IF v_invite.status <> 'pending' THEN
    RETURN json_build_object('success', false, 'error', 'INVITE_CLOSED');
  END IF;
  IF v_invite.sender_id = p_user_id THEN
    RETURN json_build_object('success', false, 'error', 'SELF_APPLY');
  END IF;
  -- ★ ブロック判定: どちらかがブロックしていたら拒否
  IF public.is_user_blocked(v_invite.sender_id, p_user_id)
     OR public.is_user_blocked(p_user_id, v_invite.sender_id) THEN
    RETURN json_build_object('success', false, 'error', 'BLOCKED');
  END IF;
  IF public.is_user_in_battle(p_user_id) THEN
    RETURN json_build_object('success', false, 'error', 'IN_BATTLE');
  END IF;
  IF EXISTS (SELECT 1 FROM battle_invite_applications WHERE applicant_id = p_user_id AND status = 'pending') THEN
    RETURN json_build_object('success', false, 'error', 'ALREADY_APPLYING');
  END IF;

  INSERT INTO battle_invite_applications (invite_id, applicant_id)
  VALUES (p_invite_id, p_user_id);

  RETURN json_build_object('success', true);
END;
$function$;

-- send_dm_resba(DM内レスバ送信)
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
  v_room   uuid;
  v_target uuid;
  v_invite json;
BEGIN
  IF public.is_user_in_battle(p_sender_id) THEN
    RETURN json_build_object('success', false, 'error', 'IN_BATTLE');
  END IF;

  SELECT room_id INTO v_room FROM dm_messages WHERE id = p_message_id;
  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'MESSAGE_NOT_FOUND');
  END IF;

  SELECT user_id INTO v_target
    FROM dm_room_members
   WHERE room_id = v_room AND user_id <> p_sender_id
   LIMIT 1;
  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'TARGET_NOT_FOUND');
  END IF;

  -- ★ ブロック判定: どちらかがブロックしていたら拒否
  IF public.is_user_blocked(p_sender_id, v_target)
     OR public.is_user_blocked(v_target, p_sender_id) THEN
    RETURN json_build_object('success', false, 'error', 'BLOCKED');
  END IF;

  INSERT INTO battle_invites (sender_id, attach_type, attach_id, target_user_id, theme, choice1, choice2)
  VALUES (
    p_sender_id, 'dm', p_message_id, v_target,
    COALESCE(NULLIF(p_theme, ''), 'レスバ対戦'),
    NULLIF(p_choice1, ''), NULLIF(p_choice2, '')
  )
  RETURNING to_jsonb(battle_invites.*)::text::json INTO v_invite;

  RETURN json_build_object('success', true, 'invite', v_invite);
END;
$function$;

-- ---------- 7. 対戦募集ルーム: ブロック時は応募を拒否 ----------
CREATE OR REPLACE FUNCTION public.apply_bbs_room (
  p_room_id  uuid,
  p_user_id  uuid,
  p_password text
)
  RETURNS json
  LANGUAGE plpgsql
  SECURITY DEFINER
  AS $function$
DECLARE
    target_room RECORD;
BEGIN
    -- 対象の部屋をロックして取得
    SELECT * INTO target_room FROM rooms_v2 WHERE id = p_room_id FOR UPDATE;

    IF NOT FOUND THEN
        RETURN json_build_object('success', false, 'error', 'ROOM_NOT_FOUND');
    END IF;

    -- ★ ブロック判定: ホストと応募者がどちらかブロックしていたら拒否
    IF public.is_user_blocked(target_room.player1_id, p_user_id)
       OR public.is_user_blocked(p_user_id, target_room.player1_id) THEN
        RETURN json_build_object('success', false, 'error', 'BLOCKED');
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
$function$;

-- ---------- 8. ランダムマッチングはブロック対象外(変更なし) ----------
-- 明示的に触れない。join_room_v2 / join_room_v3 等にはブロックチェックを入れない。
