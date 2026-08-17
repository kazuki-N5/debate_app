-- Migration unit 1: schema_changes
-- Transaction mode: transactional
-- Boundary reason: default

SET check_function_bodies = false;

CREATE FUNCTION public.apply_bbs_room (
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

GRANT ALL ON FUNCTION public.apply_bbs_room(uuid, uuid, text) TO anon;

GRANT ALL ON FUNCTION public.apply_bbs_room(uuid, uuid, text) TO authenticated;

GRANT ALL ON FUNCTION public.apply_bbs_room(uuid, uuid, text) TO service_role;

CREATE FUNCTION public.approve_bbs_room (
  p_room_id uuid,
  p_user_id uuid,
  p_approve boolean
)
  RETURNS json
  LANGUAGE plpgsql
  SECURITY DEFINER
  AS $function$
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
$function$;

GRANT ALL ON FUNCTION public.approve_bbs_room(uuid, uuid, boolean) TO anon;

GRANT ALL ON FUNCTION public.approve_bbs_room(uuid, uuid, boolean) TO authenticated;

GRANT ALL ON FUNCTION public.approve_bbs_room(uuid, uuid, boolean) TO service_role;

CREATE FUNCTION public.cancel_bbs_application (
  p_user_id uuid
)
  RETURNS json
  LANGUAGE plpgsql
  SECURITY DEFINER
  AS $function$
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
$function$;

GRANT ALL ON FUNCTION public.cancel_bbs_application(uuid) TO anon;

GRANT ALL ON FUNCTION public.cancel_bbs_application(uuid) TO authenticated;

GRANT ALL ON FUNCTION public.cancel_bbs_application(uuid) TO service_role;

CREATE FUNCTION public.create_bbs_room (
  p_user_id  uuid,
  p_theme    text,
  p_choice1  text,
  p_choice2  text,
  p_password text
)
  RETURNS json
  LANGUAGE plpgsql
  SECURITY DEFINER
  AS $function$
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
$function$;

GRANT ALL ON FUNCTION public.create_bbs_room(uuid, text, text, text, text) TO anon;

GRANT ALL ON FUNCTION public.create_bbs_room(uuid, text, text, text, text) TO authenticated;

GRANT ALL ON FUNCTION public.create_bbs_room(uuid, text, text, text, text) TO service_role;

CREATE FUNCTION public.decrement_comment_likes_count (
  p_comment_id uuid
)
  RETURNS void
  LANGUAGE plpgsql
  AS $function$
BEGIN
  UPDATE bbs_comments SET likes_count = GREATEST(likes_count - 1, 0) WHERE id = p_comment_id;
END;
$function$;

GRANT ALL ON FUNCTION public.decrement_comment_likes_count(uuid) TO anon;

GRANT ALL ON FUNCTION public.decrement_comment_likes_count(uuid) TO authenticated;

GRANT ALL ON FUNCTION public.decrement_comment_likes_count(uuid) TO service_role;

CREATE FUNCTION public.decrement_likes_count (
  post_id uuid
)
  RETURNS void
  LANGUAGE plpgsql
  AS $function$
BEGIN
  UPDATE bbs_posts SET likes_count = GREATEST(likes_count - 1, 0) WHERE id = post_id;
END;
$function$;

GRANT ALL ON FUNCTION public.decrement_likes_count(uuid) TO anon;

GRANT ALL ON FUNCTION public.decrement_likes_count(uuid) TO authenticated;

GRANT ALL ON FUNCTION public.decrement_likes_count(uuid) TO service_role;

CREATE FUNCTION public.delete_bbs_room (
  p_room_id uuid,
  p_user_id uuid
)
  RETURNS json
  LANGUAGE plpgsql
  SECURITY DEFINER
  AS $function$
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
$function$;

GRANT ALL ON FUNCTION public.delete_bbs_room(uuid, uuid) TO anon;

GRANT ALL ON FUNCTION public.delete_bbs_room(uuid, uuid) TO authenticated;

GRANT ALL ON FUNCTION public.delete_bbs_room(uuid, uuid) TO service_role;

CREATE FUNCTION public.get_bbs_rooms()
  RETURNS json
  LANGUAGE plpgsql
  SECURITY DEFINER
  AS $function$
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
                'avatar_url', u.avatar_url,
                'trophy', u.trophy,
                'win', u.win,
                'lose', u.lose
            )
        ) ORDER BY r.created_at DESC
    ), '[]'::json) INTO result
    FROM rooms_v2 r
    LEFT JOIN users u ON r.player1_id = u.id
    WHERE r.is_bbs = TRUE AND r.player2_id IS NULL;

    RETURN result;
END;
$function$;

GRANT ALL ON FUNCTION public.get_bbs_rooms() TO anon;

GRANT ALL ON FUNCTION public.get_bbs_rooms() TO authenticated;

GRANT ALL ON FUNCTION public.get_bbs_rooms() TO service_role;

CREATE OR REPLACE FUNCTION public.handle_room_updates_v2()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  AS $function$DECLARE
    selected_theme RECORD;
    total_themes INT;
    current_used_ids INTEGER[];
    new_theme_id INT;
    qstash_token text := 'eyJVc2VySUQiOiJhYzQ3YjI2Yi03MTg4LTQ4ZjUtYTIwMS00ZGE2MTQ0ZmEwZDAiLCJQYXNzd29yZCI6IjJlYjA4YzRlZjg2YjRkNjI5YTg4ODhkYjFmNzU2OTczIn0=';
    
    -- 【ローカル検証用】ngrok のURL
    target_url text := 'https://undebilitative-engagedly-salma.ngrok-free.dev/functions/v1/gemini_v2';
    qstash_publish_url text := 'https://qstash-us-east-1.upstash.io/v2/publish/' || target_url;
BEGIN
    IF TG_OP = 'INSERT' THEN
        IF NEW.theme_s IS FALSE THEN
            SELECT * INTO selected_theme FROM debate_themes ORDER BY random() LIMIT 1;
            NEW.current_theme := selected_theme.theme; NEW.current_choice1 := selected_theme.choice1;
            NEW.current_choice2 := selected_theme.choice2; NEW.used_theme_ids := ARRAY[selected_theme.id];
        END IF;
    ELSIF TG_OP = 'UPDATE' THEN
        -- テーマ更新ロジック
          IF NEW.player1_choice IS NOT NULL AND NEW.player2_choice IS NOT NULL AND NEW.player2_choice = NEW.player1_choice AND
           ((OLD.player1_choice IS NULL OR OLD.player1_choice != NEW.player1_choice) OR
            (OLD.player2_choice IS NULL OR OLD.player2_choice != NEW.player2_choice))
        THEN
            IF COALESCE(OLD.theme_s, FALSE) IS FALSE THEN
                current_used_ids := COALESCE(OLD.used_theme_ids, ARRAY[]::INTEGER[]);
                SELECT count(*) INTO total_themes FROM debate_themes;
                IF array_length(current_used_ids, 1) >= total_themes THEN current_used_ids := ARRAY[]::INTEGER[]; END IF;
                SELECT id INTO new_theme_id FROM debate_themes WHERE id <> ALL(current_used_ids) ORDER BY random() LIMIT 1;
                IF new_theme_id IS NOT NULL THEN
                    SELECT * INTO selected_theme FROM debate_themes WHERE id = new_theme_id;
                    NEW.current_theme := selected_theme.theme; NEW.current_choice1 := selected_theme.choice1;
                    NEW.current_choice2 := selected_theme.choice2; NEW.used_theme_ids := array_append(current_used_ids, new_theme_id);
                END IF;
            END IF;
            NEW.player1_choice := NULL; NEW.player2_choice := NULL; NEW.change := NOT OLD.change;
        -- Gemini 呼び出し (意見が分かれた時または終了時)
        ELSIF NEW.player1_choice IS NOT NULL AND NEW.player2_choice IS NOT NULL AND NEW.player1_choice != NEW.player2_choice AND
               ((OLD.player1_choice IS NULL OR OLD.player1_choice != NEW.player1_choice) OR
                (OLD.player2_choice IS NULL OR OLD.player2_choice != NEW.player2_choice))
        THEN
            PERFORM net.http_post(
                url := qstash_publish_url,
                headers := jsonb_build_object('Authorization', 'Bearer ' || qstash_token, 'Content-Type', 'application/json', 'Upstash-Delay', '10m'),
                body := jsonb_build_object(
                    'room_id', NEW.id, 
                    'theme', NEW.current_theme, 
                    'player1_choice', NEW.current_choice1, 
                    'player2_choice', NEW.current_choice2,
                    'table_name', TG_TABLE_NAME
                )
            );
        END IF;
        -- 直接判定 (両者finishボタン押下時)
        IF NEW.player1_finish IS TRUE AND NEW.player2_finish IS TRUE AND (OLD.player1_finish IS FALSE OR OLD.player2_finish IS FALSE) THEN
            PERFORM net.http_post(
                url := target_url, 
                headers := jsonb_build_object('Content-Type', 'application/json'), 
                body := jsonb_build_object(
                    'room_id', NEW.id, 
                    'theme', NEW.current_theme, 
                    'player1_choice', NEW.current_choice1, 
                    'player2_choice', NEW.current_choice2,
                    'table_name', TG_TABLE_NAME
                )
            );
        END IF;
    END IF;
    NEW.updated_at = NOW();
    RETURN NEW;
EXCEPTION WHEN OTHERS THEN
    RAISE LOG 'Error in trigger on table %: %, SQLSTATE: %', TG_TABLE_NAME, SQLERRM, SQLSTATE;
    RAISE EXCEPTION 'トリガー実行中にエラーが発生しました (テーブル: %): % (SQLSTATE: %)', TG_TABLE_NAME, SQLERRM, SQLSTATE;
END;$function$;

CREATE FUNCTION public.increment_comment_likes_count (
  p_comment_id uuid
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  AS $function$
BEGIN
  UPDATE bbs_comments SET likes_count = COALESCE(likes_count, 0) + 1 WHERE id = p_comment_id;
END;
$function$;

GRANT ALL ON FUNCTION public.increment_comment_likes_count(uuid) TO anon;
GRANT ALL ON FUNCTION public.increment_comment_likes_count(uuid) TO authenticated;
GRANT ALL ON FUNCTION public.increment_comment_likes_count(uuid) TO service_role;

CREATE FUNCTION public.increment_likes_count (
  post_id uuid
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  AS $function$
BEGIN
  UPDATE bbs_posts SET likes_count = COALESCE(likes_count, 0) + 1 WHERE id = post_id;
END;
$function$;

GRANT ALL ON FUNCTION public.increment_likes_count(uuid) TO anon;
GRANT ALL ON FUNCTION public.increment_likes_count(uuid) TO authenticated;
GRANT ALL ON FUNCTION public.increment_likes_count(uuid) TO service_role;

CREATE FUNCTION public.increment_replies_count (
  p_post_id uuid
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  AS $function$
BEGIN
  UPDATE bbs_posts SET replies_count = replies_count + 1 WHERE id = p_post_id;
END;
$function$;

GRANT ALL ON FUNCTION public.increment_replies_count(uuid) TO anon;

GRANT ALL ON FUNCTION public.increment_replies_count(uuid) TO authenticated;

GRANT ALL ON FUNCTION public.increment_replies_count(uuid) TO service_role;

CREATE OR REPLACE FUNCTION public.join_room_v2 (
  p_user_id       uuid,
  p_room_password text,
  p_room_theme    text,
  p_room_choice1  text,
  p_room_choice2  text
)
  RETURNS jsonb
  LANGUAGE plpgsql
  AS $function$
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
END; $function$;

CREATE OR REPLACE FUNCTION public.v2_process_game_result()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  AS $function$DECLARE
  v_p1_trophy integer; v_p2_trophy integer;
  v_p1_move integer := 0; v_p2_move integer := 0;
  v_is_underdog_match boolean := false;
BEGIN
  IF (NEW.password IS NULL OR NEW.password = '') AND (NEW.is_bbs IS NOT TRUE) THEN
    SELECT trophy INTO v_p1_trophy FROM users WHERE id = NEW.player1_id;
    SELECT trophy INTO v_p2_trophy FROM users WHERE id = NEW.player2_id;
    v_is_underdog_match := ABS(v_p1_trophy - v_p2_trophy) >= 200;
    
    IF NEW.winner = 'A' THEN
      v_p1_move := calculate_brawl_trophy_change(v_p1_trophy, v_p2_trophy, true);
      v_p2_move := calculate_brawl_trophy_change(v_p2_trophy, v_p1_trophy, false);
      UPDATE users SET win = win + 1, trophy = GREATEST(0, trophy + v_p1_move) WHERE id = NEW.player1_id;
      UPDATE users SET lose = lose + 1, trophy = GREATEST(0, trophy + v_p2_move) WHERE id = NEW.player2_id;
    ELSIF NEW.winner = 'B' THEN
      v_p1_move := calculate_brawl_trophy_change(v_p1_trophy, v_p2_trophy, false);
      v_p2_move := calculate_brawl_trophy_change(v_p2_trophy, v_p1_trophy, true);
      UPDATE users SET lose = lose + 1, trophy = GREATEST(0, trophy + v_p1_move) WHERE id = NEW.player1_id;
      UPDATE users SET win = win + 1, trophy = GREATEST(0, trophy + v_p2_move) WHERE id = NEW.player2_id;
    ELSE -- 引き分け時
      v_p1_move := 0; v_p2_move := 0;
      UPDATE users SET trophy = GREATEST(0, trophy + v_p1_move) WHERE id = NEW.player1_id;
      UPDATE users SET trophy = GREATEST(0, trophy + v_p2_move) WHERE id = NEW.player2_id;
    END IF;
  END IF;
  
  -- match_record に記録
  INSERT INTO match_record (
    roomid, player1_id, player2_id, theme, winner, 
    player1_move_trophy, player2_move_trophy, is_underdog, 
    move_trophy, result,
    player1_choice, player2_choice,
    scores
  ) VALUES (
    NEW.id, NEW.player1_id, NEW.player2_id, NEW.current_theme, 
    CASE WHEN NEW.winner = 'A' THEN NEW.player1_id WHEN NEW.winner = 'B' THEN NEW.player2_id ELSE NULL END, 
    v_p1_move, v_p2_move, v_is_underdog_match, 
    v_p1_move, NEW.reason,
    CASE WHEN NEW.player1_choice IS TRUE THEN NEW.current_choice1 WHEN NEW.player1_choice IS FALSE THEN NEW.current_choice2 ELSE NULL END,
    CASE WHEN NEW.player2_choice IS TRUE THEN NEW.current_choice1 WHEN NEW.player2_choice IS FALSE THEN NEW.current_choice2 ELSE NULL END,
    NEW.scores
  );
  RETURN NEW;
END;$function$;

CREATE TABLE public.bbs_comment_likes (
  id         uuid                     DEFAULT gen_random_uuid() NOT NULL,
  comment_id uuid,
  user_id    uuid,
  created_at timestamp with time zone DEFAULT now()
);

ALTER TABLE public.bbs_comment_likes
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.bbs_comment_likes
  ADD CONSTRAINT bbs_comment_likes_comment_id_user_id_key UNIQUE (comment_id, user_id);

ALTER TABLE public.bbs_comment_likes
  ADD CONSTRAINT bbs_comment_likes_pkey PRIMARY KEY (id);

ALTER TABLE public.bbs_comment_likes
  ADD CONSTRAINT bbs_comment_likes_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;

GRANT ALL ON public.bbs_comment_likes TO anon;

GRANT ALL ON public.bbs_comment_likes TO authenticated;

GRANT ALL ON public.bbs_comment_likes TO service_role;

CREATE POLICY "自分のコメントのいいねのみ削除可能" ON public.bbs_comment_likes
  FOR DELETE
  USING ((auth.uid() = user_id));

CREATE POLICY "認証済みユーザーはコメントのいいねを作成可" ON public.bbs_comment_likes
  FOR INSERT
  WITH CHECK ((auth.role() = 'authenticated'::text));

CREATE POLICY "誰でもコメントのいいねを閲覧可能" ON public.bbs_comment_likes
  FOR SELECT
  USING (true);

CREATE TABLE public.bbs_comments (
  id                uuid                     DEFAULT gen_random_uuid() NOT NULL,
  post_id           uuid,
  user_id           uuid,
  parent_comment_id uuid,
  content           text                     NOT NULL,
  created_at        timestamp with time zone DEFAULT now(),
  likes_count       integer                  DEFAULT 0
);

ALTER TABLE public.bbs_comments
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.bbs_comments
  ADD CONSTRAINT bbs_comments_pkey PRIMARY KEY (id);

ALTER TABLE public.bbs_comment_likes
  ADD CONSTRAINT bbs_comment_likes_comment_id_fkey FOREIGN KEY (comment_id) REFERENCES public.bbs_comments(id) ON DELETE CASCADE;

ALTER TABLE public.bbs_comments
  ADD CONSTRAINT bbs_comments_parent_comment_id_fkey FOREIGN KEY (parent_comment_id) REFERENCES public.bbs_comments(id) ON DELETE CASCADE;

ALTER TABLE public.bbs_comments
  ADD CONSTRAINT bbs_comments_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;

GRANT ALL ON public.bbs_comments TO anon;

GRANT ALL ON public.bbs_comments TO authenticated;

GRANT ALL ON public.bbs_comments TO service_role;

CREATE POLICY "自分のコメントのみ削除可能" ON public.bbs_comments
  FOR DELETE
  USING ((auth.uid() = user_id));

CREATE POLICY "自分のコメントのみ更新可能" ON public.bbs_comments
  FOR UPDATE
  USING ((auth.uid() = user_id));

CREATE POLICY "認証済みユーザーはコメントを作成可能" ON public.bbs_comments
  FOR INSERT
  WITH CHECK ((auth.role() = 'authenticated'::text));

CREATE POLICY "誰でもコメントを閲覧可能" ON public.bbs_comments
  FOR SELECT
  USING (true);

CREATE TABLE public.bbs_likes (
  id         uuid                     DEFAULT gen_random_uuid() NOT NULL,
  post_id    uuid,
  user_id    uuid,
  created_at timestamp with time zone DEFAULT now()
);

ALTER TABLE public.bbs_likes
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.bbs_likes
  ADD CONSTRAINT bbs_likes_pkey PRIMARY KEY (id);

ALTER TABLE public.bbs_likes
  ADD CONSTRAINT bbs_likes_post_id_user_id_key UNIQUE (post_id, user_id);

ALTER TABLE public.bbs_likes
  ADD CONSTRAINT bbs_likes_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;

GRANT ALL ON public.bbs_likes TO anon;

GRANT ALL ON public.bbs_likes TO authenticated;

GRANT ALL ON public.bbs_likes TO service_role;

CREATE POLICY "自分のいいねのみ削除可能" ON public.bbs_likes
  FOR DELETE
  USING ((auth.uid() = user_id));

CREATE POLICY "認証済みユーザーはいいねを作成可能" ON public.bbs_likes
  FOR INSERT
  WITH CHECK ((auth.role() = 'authenticated'::text));

CREATE POLICY "誰でもいいねを閲覧可能" ON public.bbs_likes
  FOR SELECT
  USING (true);

CREATE TABLE public.bbs_posts (
  id            uuid                     DEFAULT gen_random_uuid() NOT NULL,
  user_id       uuid,
  content       text                     NOT NULL,
  created_at    timestamp with time zone DEFAULT now(),
  likes_count   integer                  DEFAULT 0,
  replies_count integer                  DEFAULT 0
);

ALTER TABLE public.bbs_posts
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.bbs_posts
  ADD CONSTRAINT bbs_posts_pkey PRIMARY KEY (id);

ALTER TABLE public.bbs_comments
  ADD CONSTRAINT bbs_comments_post_id_fkey FOREIGN KEY (post_id) REFERENCES public.bbs_posts(id) ON DELETE CASCADE;

ALTER TABLE public.bbs_likes
  ADD CONSTRAINT bbs_likes_post_id_fkey FOREIGN KEY (post_id) REFERENCES public.bbs_posts(id) ON DELETE CASCADE;

ALTER TABLE public.bbs_posts
  ADD CONSTRAINT bbs_posts_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;

GRANT ALL ON public.bbs_posts TO anon;

GRANT ALL ON public.bbs_posts TO authenticated;

GRANT ALL ON public.bbs_posts TO service_role;

CREATE POLICY "自分の投稿のみ削除可能" ON public.bbs_posts
  FOR DELETE
  USING ((auth.uid() = user_id));

CREATE POLICY "自分の投稿のみ更新可能" ON public.bbs_posts
  FOR UPDATE
  USING ((auth.uid() = user_id));

CREATE POLICY "認証済みユーザーは投稿を作成可能" ON public.bbs_posts
  FOR INSERT
  WITH CHECK ((auth.role() = 'authenticated'::text));

CREATE POLICY "誰でも投稿を閲覧可能" ON public.bbs_posts
  FOR SELECT
  USING (true);

ALTER TABLE public.match_record
  ADD COLUMN scores jsonb;

ALTER TABLE public.rooms_v2
  ADD COLUMN scores jsonb;

ALTER TABLE public.rooms_v2
  ADD COLUMN is_bbs boolean DEFAULT false;

ALTER TABLE public.rooms_v2
  ADD COLUMN challenger_id uuid;