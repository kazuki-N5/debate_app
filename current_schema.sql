

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


CREATE EXTENSION IF NOT EXISTS "pg_cron" WITH SCHEMA "pg_catalog";






CREATE EXTENSION IF NOT EXISTS "pg_net" WITH SCHEMA "extensions";






COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE EXTENSION IF NOT EXISTS "pg_graphql" WITH SCHEMA "graphql";






CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgjwt" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";






CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";






CREATE OR REPLACE FUNCTION "public"."calculate_elo_rating"("winner_rate" numeric, "loser_rate" numeric) RETURNS integer
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  k CONSTANT integer := 32;
  point numeric;
BEGIN
  point := k / (power(10, (winner_rate - loser_rate) / 400) + 1);
  
  -- clamp関数と同等の処理
  IF point < 2 THEN
    RETURN 2;
  ELSIF point > 32 THEN
    RETURN 32;
  ELSE
    RETURN round(point);
  END IF;
END;
$$;


ALTER FUNCTION "public"."calculate_elo_rating"("winner_rate" numeric, "loser_rate" numeric) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."cancel_data_transfer"("p_sender_id" "uuid") RETURNS "text"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_deleted_count integer;
BEGIN
    -- トランザクション開始

    -- 1. transferテーブルから該当レコードを削除 (まだreceive_idが設定されていないもののみ)
    DELETE FROM public.transfer
    WHERE send_id = p_sender_id AND receive_id IS NULL
    RETURNING 1 INTO v_deleted_count; -- 削除された行があれば1、なければNULL

    -- 2. ユーザーのステータスをtrueに戻す
    -- 必ずしもtransferレコードが存在しなくても、statusがfalseならtrueに戻すロジックも考えられる
    -- ここでは、transferレコードが実際に削除された場合のみstatusを更新する
    IF v_deleted_count IS NOT NULL THEN
        UPDATE public.users
        SET status = true
        WHERE id = p_sender_id AND status = false; -- statusがfalseの場合のみ更新

        IF NOT FOUND THEN
            -- statusが既にtrueだったか、ユーザーが存在しない場合
            -- transferレコードは削除されたが、ユーザーのstatusが更新されなかった場合
            -- この状態は不整合の可能性があるので、エラーにするか、ログを残す
            RAISE WARNING 'Transfer record deleted for user %, but user status was not false or user not found.', p_sender_id;
            -- 状況によっては、ここでエラーを発生させても良い
            -- RAISE EXCEPTION 'Failed to update user status for user % after deleting transfer record.', p_sender_id;
        END IF;
        RETURN 'Data transfer canceled successfully.';
    ELSE
        -- 該当するtransferレコードがなかった場合
        -- statusがfalseのままの可能性があるため、ユーザーのstatusを確認してtrueに戻す
        UPDATE public.users
        SET status = true
        WHERE id = p_sender_id AND status = false;
        IF FOUND THEN
             RETURN 'No active transfer found to cancel, user status (if false) has been reset.';
        ELSE
             RETURN 'No active transfer found to cancel, and user status was not false.';
        END IF;

    END IF;


EXCEPTION
    WHEN OTHERS THEN
        RAISE INFO 'Error in cancel_data_transfer: %', SQLERRM;
        RAISE;
END;
$$;


ALTER FUNCTION "public"."cancel_data_transfer"("p_sender_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."cancel_data_transfer_robust"("p_sender_id" "uuid") RETURNS "text"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_user_updated boolean := false;
    v_transfer_deleted boolean := false;
BEGIN
    -- 1. ユーザーのステータスをtrueに戻す
    -- statusがfalseの場合のみ更新し、更新されたかどうかのフラグを立てる
    UPDATE public.users
    SET status = true
    WHERE id = p_sender_id AND status = false
    RETURNING true INTO v_user_updated;

    -- 2. transferテーブルから該当レコードを削除 (まだreceive_idが設定されていないもののみ)
    DELETE FROM public.transfer
    WHERE send_id = p_sender_id AND receive_id IS NULL
    RETURNING true INTO v_transfer_deleted;

    IF v_user_updated AND v_transfer_deleted THEN
        RETURN 'Data transfer canceled and user status reset.';
    ELSIF v_user_updated THEN
        RETURN 'User status reset. No active transfer found to delete.';
    ELSIF v_transfer_deleted THEN
        -- このケースは通常、status=trueでtransferレコードだけ残っていた場合など。
        RETURN 'Active transfer deleted. User status was already true.';
    ELSE
        RETURN 'No action taken. User status was already true and no active transfer found.';
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        RAISE INFO 'Error in cancel_data_transfer_robust: %', SQLERRM;
        RAISE; -- エラーを再スロー
END;
$$;


ALTER FUNCTION "public"."cancel_data_transfer_robust"("p_sender_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."complete_data_transfer"("p_transfer_id" "text", "p_password" "text", "p_receiver_id" "uuid") RETURNS "text"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$DECLARE
    v_transfer_record public.transfer%ROWTYPE;
    v_sender_user_data public.users%ROWTYPE;
BEGIN
    -- トランザクション開始

    -- 1. transferテーブルから有効なレコードを取得
    SELECT * INTO v_transfer_record
    FROM public.transfer
    WHERE id = p_transfer_id
      AND password = p_password
      AND delete_at > now()
      AND receive_id IS NULL; -- まだ使用されていないことを確認

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Invalid transfer ID, password, expired, or already used.';
    END IF;

    -- 2. receive_idを更新
    UPDATE public.transfer
    SET receive_id = p_receiver_id
    WHERE id = v_transfer_record.id;

    -- 3. 送信者のユーザーデータを取得
    SELECT * INTO v_sender_user_data
    FROM public.users
    WHERE id = v_transfer_record.send_id;

    IF NOT FOUND THEN
        -- このケースは通常ありえない (initiateでstatus変更しているため)
        RAISE EXCEPTION 'Sender user data not found for ID: %', v_transfer_record.send_id;
    END IF;

    -- 4. 受信者のユーザーデータを送信者のデータで上書き
    UPDATE public.users
    SET
        win = v_sender_user_data.win,
        lose = v_sender_user_data.lose,
        trophy = v_sender_user_data.trophy,
        created_at = v_sender_user_data.created_at
        -- avatar_urlなども移行する場合はここに追加
    WHERE id = p_receiver_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Receiver user not found: %', p_receiver_id;
    END IF;

    -- 5. 送信者のユーザーデータを初期化し、ステータスをtrueに戻す
    UPDATE public.users
    SET
        win = 0,
        lose = 0,
        trophy = 0,
        status = true,
         created_at = now()
    WHERE id = v_transfer_record.send_id;

    RETURN 'Data transfer completed successfully.';

EXCEPTION
    WHEN OTHERS THEN
        RAISE INFO 'Error in complete_data_transfer: %', SQLERRM;
        RAISE;
END;$$;


ALTER FUNCTION "public"."complete_data_transfer"("p_transfer_id" "text", "p_password" "text", "p_receiver_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."delete_old_rooms_with_result"() RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  -- result カラムに何かしら値が入っていて (result IS NOT NULL)
  -- かつ updated_at が現在時刻 (now()) から2分前 (INTERVAL '2 minutes') 以前である行を削除
  DELETE FROM public.rooms
  WHERE
    result IS NOT NULL
    AND updated_at <= now() - INTERVAL '2 minutes';
END;
$$;


ALTER FUNCTION "public"."delete_old_rooms_with_result"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."deleteroom"("p_room_id" "uuid", "p_user_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  target_room RECORD;
  -- deleted_count INTEGER; -- FOR UPDATE を使う場合、削除が成功すれば常に1のはずなので不要になる可能性あり
BEGIN
  BEGIN
    -- 削除対象のルームを取得し、行ロックを獲得
    -- このSELECTが完了するまで、他のトランザクションはこの行を更新/削除できない
    SELECT * INTO target_room
    FROM rooms
    WHERE id = p_room_id
    FOR UPDATE; -- ★★★ 行ロックを追加 ★★★

    -- ルームが存在しない場合 (ロックしようとしたが存在しなかった)
    IF NOT FOUND THEN
      RETURN jsonb_build_object(
        'success', false,
        'message', '指定されたルームが見つかりません。'
      );
    END IF;

    -- 削除を実行しようとしているユーザーが作成者ではないかチェック
    IF target_room.player1_id != p_user_id THEN
      RETURN jsonb_build_object(
        'success', false,
        'message', 'ルームの作成者ではないため削除できません。'
      );
    END IF;

    -- player2 が既に参加しているかチェック (ロックしているので最新の状態)
    IF target_room.player2_id IS NOT NULL THEN
      RETURN jsonb_build_object(
        'success', false,
        'message', '既に参加者がいるためルームを削除できません。'
      );
    END IF;

    -- 条件を満たす場合、ルームを削除
    -- ロックしているので、WHERE句の条件はIDだけで十分 (他の条件はSELECT時点で保証済)
    DELETE FROM rooms
    WHERE id = p_room_id;

    -- 削除成功時の処理 (GET DIAGNOSTICS は念のため残してもOK)
    -- GET DIAGNOSTICS deleted_count = ROW_COUNT;
    -- IF deleted_count = 1 THEN
      RETURN jsonb_build_object(
        'success', true,
        'message', 'ルームを削除しました。'
      );
    -- ELSE -- 基本的にこのルートは通らないはず (ロックと事前チェックのため)
    --   RETURN jsonb_build_object(
    --     'success', false,
    --     'message', 'ルームの削除に予期せず失敗しました。'
    --   );
    -- END IF;

  EXCEPTION
    WHEN OTHERS THEN
      RAISE WARNING 'Error in deleteroom function: %', SQLERRM;
      RETURN jsonb_build_object(
        'success', false,
        'message', 'サーバーエラーが発生しました。ルームを削除できませんでした。',
        'error', SQLERRM
      );
  END;
END;
$$;


ALTER FUNCTION "public"."deleteroom"("p_room_id" "uuid", "p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."generate_random_id"("len" integer) RETURNS "text"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    -- 使用する文字集合 (A-Z, a-z, 0-9)
    chars text := 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    -- 結果を格納する変数
    result text := '';
    -- ループカウンター
    i integer;
    -- 文字集合の長さ
    chars_len integer := length(chars);
    -- ランダムなインデックス
    random_index integer;
BEGIN
    -- 長さが0以下の場合、空文字列を返す
    IF len <= 0 THEN
        RETURN '';
    END IF;

    -- 指定された長さだけループする
    FOR i IN 1..len LOOP
        -- random() は 0.0 から 1.0 未満の浮動小数点数を生成する
        -- chars_len を掛けることで、0.0 から chars_len 未満の範囲にする
        -- floor() で小数点以下を切り捨て、0 から chars_len-1 の整数にする
        -- ::int で整数型にキャストする
        -- + 1 をすることで、substr が使用する 1 から chars_len の範囲にする (substr は 1-based index)
        random_index := floor(random() * chars_len)::int + 1;

        -- 文字集合からランダムなインデックス位置の文字を取り出し、結果に連結する
        result := result || substr(chars, random_index, 1);
    END LOOP;

    -- 生成されたランダム文字列を返す
    RETURN result;
END;
$$;


ALTER FUNCTION "public"."generate_random_id"("len" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."generate_random_password"() RETURNS "text"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    -- 使用する文字セット (a-z, A-Z, 0-9) を定義します
    chars TEXT := 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    -- 結果となるパスワードを格納する変数です
    result TEXT := '';
    -- ループ用のカウンター変数です
    i INTEGER;
    -- ランダムに選択された文字のインデックスを格納する変数です
    random_index INTEGER;
    -- パスワードの長さを定数として定義します
    password_length CONSTANT INTEGER := 6;
BEGIN
    -- 指定された長さ分だけループします
    FOR i IN 1..password_length LOOP
        -- chars文字列の長さに基づいて、1から長さまでのランダムな整数を生成します
        -- floor(random() * length(chars)) は 0 から length-1 の範囲になります
        -- + 1 することで 1 から length の範囲になります (substr は 1-based index)
        random_index := floor(random() * length(chars)) + 1;

        -- chars文字列からランダムなインデックス位置の文字を1文字取得し、結果に追加します
        result := result || substr(chars, random_index, 1);
    END LOOP;

    -- 生成されたパスワードを返します
    RETURN result;
END;
$$;


ALTER FUNCTION "public"."generate_random_password"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_nearby_ranking"("p_user_id" "uuid") RETURNS TABLE("id" "uuid", "name" "text", "trophy" integer, "win" integer, "avatar_url" "text", "overall_rank" bigint)
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    user_current_rank bigint;
BEGIN
    -- 1. 現在のユーザーの全体順位を特定
    SELECT rn INTO user_current_rank
    FROM (
        SELECT u.id, ROW_NUMBER() OVER (ORDER BY u.trophy DESC, u.win DESC NULLS LAST, u.id ASC) as rn
        FROM users u
    ) ranked_users_for_rank_finding
    WHERE ranked_users_for_rank_finding.id = p_user_id;

    -- ユーザーが見つからない、またはランクが取得できない場合は空を返す
    IF user_current_rank IS NULL THEN
        RETURN;
    END IF;

    -- 2. 現在のユーザーのランクを基準に上位49人、下位50人の範囲でユーザーを取得
    --    (自分自身も含むため、最大100人)
    RETURN QUERY
    SELECT ru.id, ru.name, ru.trophy, ru.win, ru.avatar_url, ru.rn as overall_rank
    FROM (
        -- 全ユーザーを再度ランク付け（CTE内で完結させるため）
        SELECT u_inner.id, u_inner.name, u_inner.trophy, u_inner.win, u_inner.avatar_url,
               ROW_NUMBER() OVER (ORDER BY u_inner.trophy DESC, u_inner.win DESC NULLS LAST, u_inner.id ASC) as rn
        FROM users u_inner
    ) ru
    WHERE ru.rn >= GREATEST(1, user_current_rank - 49) -- 開始ランク (自分より49位上まで、ただし1位未満にはならない)
      AND ru.rn <= LEAST((SELECT COUNT(*) FROM users), user_current_rank + 50) -- 終了ランク (自分より50位下まで、ただし総ユーザー数を超えない)
    ORDER BY ru.rn ASC
    LIMIT 100; -- 念のため、最大100件に制限
END;
$$;


ALTER FUNCTION "public"."get_nearby_ranking"("p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_recent_match_history"() RETURNS TABLE("roomid" "uuid", "player1_id" "uuid", "player2_id" "uuid", "theme" "text", "player1_choice" "text", "player2_choice" "text", "winner" "uuid", "move_trophy" integer, "result" "text", "created_at" timestamp with time zone)
    LANGUAGE "sql" STABLE
    AS $$
  SELECT
    mr.roomid,
    mr.player1_id,
    mr.player2_id,
    mr.theme,
    mr.player1_choice,
    mr.player2_choice,
    mr.winner,
    mr.move_trophy,
    mr.result, -- 履歴テーブルのresultカラム（ここではそのまま）
    mr.created_at
  FROM public.match_record mr
  WHERE mr.created_at >= (now() - interval '7 days')
  ORDER BY mr.created_at DESC
  LIMIT 30;
$$;


ALTER FUNCTION "public"."get_recent_match_history"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_room_data"("p_room_id" "uuid") RETURNS "jsonb"
    LANGUAGE "sql"
    AS $$
  SELECT to_jsonb(r.*)
  FROM rooms r
  WHERE r.id = p_room_id;
$$;


ALTER FUNCTION "public"."get_room_data"("p_room_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_server_time"() RETURNS timestamp with time zone
    LANGUAGE "sql" STABLE
    AS $$
  select current_timestamp at time zone 'UTC';
$$;


ALTER FUNCTION "public"."get_server_time"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_cancellation"("p_user_id" "uuid", "p_room_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  -- roomsテーブルから取得するプレイヤーIDと勝者IDを格納する変数を宣言します。
  v_player1_id UUID;
  v_player2_id UUID;
  v_winner_id UUID; -- 勝者のIDを格納する変数を追加
BEGIN
  -- ステップ1: roomsテーブルから関連するプレイヤーIDを取得します。
  -- この情報は後でmatch_recordに挿入するために必要です。
  SELECT
    player1_id,
    player2_id
  INTO
    v_player1_id,
    v_player2_id
  FROM
    public.rooms
  WHERE
    id = p_room_id;

  -- ★追加: キャンセルしたプレイヤーの相手を勝者として特定します。
  IF p_user_id = v_player1_id THEN
    v_winner_id := v_player2_id; -- キャンセル者がplayer1なら、勝者はplayer2
  ELSE
    v_winner_id := v_player1_id; -- キャンセル者がplayer2なら、勝者はplayer1
  END IF;

  -- ステップ2: 指定されたユーザーのトロフィーを減らします。
  UPDATE
    public.users
  SET
    trophy = GREATEST(trophy - 3, 0)
  WHERE
    id = p_user_id;

  -- ステップ3: roomsテーブルのgoフラグを更新します。
  -- キャンセルしたプレイヤーに対応するフラグをfalseにします。
  UPDATE
    public.rooms
  SET
    -- p_user_idがplayer1_idと一致すればplayer1_goをfalseに、そうでなければ元の値を維持します。
    player1_go = CASE WHEN player1_id = p_user_id THEN false ELSE player1_go END,
    -- p_user_idがplayer2_idと一致すればplayer2_goをfalseに、そうでなければ元の値を維持します。
    player2_go = CASE WHEN player2_id = p_user_id THEN false ELSE player2_go END
  WHERE
    id = p_room_id;

  -- ステップ4: match_recordテーブルに対戦記録（キャンセル）を挿入します。
  -- ★修正: winnerカラムにも値を挿入するように変更します。
  INSERT INTO public.match_record
    (roomid, player1_id, player2_id, winner, move_trophy, cancel)
  VALUES
    (p_room_id, v_player1_id, v_player2_id, v_winner_id, -3, true);

END;
$$;


ALTER FUNCTION "public"."handle_cancellation"("p_user_id" "uuid", "p_room_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_new_auth_user"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  -- public.users テーブルに新しいレコードを挿入
  -- id は NEW.id (auth.users に挿入された新しい行の id)
  -- name はデフォルトで NULL になる
  -- trophy はテーブル定義の DEFAULT 0 が適用される
  INSERT INTO public.users (id)
  VALUES (NEW.id);
  RETURN NEW; -- AFTER トリガーでは必須だが、戻り値は通常使われない
END;
$$;


ALTER FUNCTION "public"."handle_new_auth_user"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_room_updates_integrated"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$DECLARE
    selected_theme RECORD;
    total_themes INT;
    current_used_ids INTEGER[];
    new_theme_id INT;
    -- QStash用の変数
    qstash_token text := 'eyJVc2VySUQiOiJhYzQ3YjI2Yi03MTg4LTQ4ZjUtYTIwMS00ZGE2MTQ0ZmEwZDAiLCJQYXNzd29yZCI6IjJlYjA4YzRlZjg2YjRkNjI5YTg4ODhkYjFmNzU2OTczIn0=';
    target_url text := 'https://undebilitative-engagedly-salma.ngrok-free.dev/functions/v1/gemini';
    qstash_publish_url text := 'https://qstash-us-east-1.upstash.io/v2/publish/' || target_url;
BEGIN
    -- INSERT時 (ルーム作成時)
    IF TG_OP = 'INSERT' THEN
        IF NEW.theme_s IS TRUE THEN
            NEW.player1_choice := NULL;
            NEW.player2_choice := NULL;
            NEW.change := FALSE;
        ELSE
            SELECT * INTO selected_theme FROM debate_themes ORDER BY random() LIMIT 1;

            NEW.current_theme := selected_theme.theme;
            NEW.current_choice1 := selected_theme.choice1;
            NEW.current_choice2 := selected_theme.choice2;
            NEW.player1_choice := NULL; 
            NEW.player2_choice := NULL; 
            NEW.change := FALSE; 
            NEW.used_theme_ids := ARRAY[selected_theme.id]; 
        END IF;

    -- UPDATE時
    ELSIF TG_OP = 'UPDATE' THEN
        -- パターンA: 両者の選択が完了し、かつ【被った場合（一致した場合）】
        IF NEW.player1_choice IS NOT NULL AND
           NEW.player2_choice IS NOT NULL AND
           NEW.player1_choice = NEW.player2_choice AND
           (OLD.player1_choice IS NULL OR OLD.player2_choice IS NULL OR OLD.player1_choice <> OLD.player2_choice)
        THEN
            IF COALESCE(OLD.theme_s, FALSE) IS FALSE THEN
                current_used_ids := COALESCE(OLD.used_theme_ids, ARRAY[]::INTEGER[]);
                SELECT count(*) INTO total_themes FROM debate_themes;

                IF array_length(current_used_ids, 1) >= total_themes THEN
                    current_used_ids := ARRAY[]::INTEGER[];
                END IF;

                SELECT id INTO new_theme_id FROM debate_themes WHERE id <> ALL(current_used_ids) ORDER BY random() LIMIT 1;

                IF new_theme_id IS NOT NULL THEN
                    SELECT * INTO selected_theme FROM debate_themes WHERE id = new_theme_id;
                    NEW.current_theme := selected_theme.theme;
                    NEW.current_choice1 := selected_theme.choice1;
                    NEW.current_choice2 := selected_theme.choice2;
                    NEW.used_theme_ids := array_append(current_used_ids, new_theme_id); 
                ELSE
                    NEW.used_theme_ids := current_used_ids;
                END IF;
            END IF; 

            -- 選択をリセットして change フラグを反転（これにより Flutter 側の resetTimer() を誘発）
            NEW.player1_choice := NULL;
            NEW.player2_choice := NULL;
            NEW.change := NOT OLD.change; 
            
        -- パターンB: 両者の選択が完了し、かつ【異なる場合（被らなかった場合）】
        ELSIF NEW.player1_choice IS NOT NULL AND
              NEW.player2_choice IS NOT NULL AND
              NEW.player1_choice != NEW.player2_choice AND
              (OLD.player1_choice IS NULL OR OLD.player2_choice IS NULL OR OLD.player1_choice = OLD.player2_choice)
        THEN
            -- ここで Gemini にスケジュール投下！
            PERFORM net.http_post(
              url := qstash_publish_url,
              headers := jsonb_build_object(
                'Authorization', 'Bearer ' || qstash_token,
                'Content-Type', 'application/json',
                'Upstash-Delay', '15s'
              ),
              body := jsonb_build_object(
                'room_id', NEW.id,
                'theme', NEW.current_theme,
                'player1_choice', NEW.current_choice1,
                'player2_choice', NEW.current_choice2
              )
            );
            RAISE NOTICE 'QStash timer scheduled for room_id: %', NEW.id;
        END IF; 

        -- 【新規機能】両プレーヤーが finish を選択した時の直接 Gemini トリガーと状態固定
        -- 両方 true の状態が完成した瞬間に作動（前回から変わった時のみ）
        IF NEW.player1_finish IS TRUE AND NEW.player2_finish IS TRUE AND
           (OLD.player1_finish IS DISTINCT FROM TRUE OR OLD.player2_finish IS DISTINCT FROM TRUE)
        THEN
            -- QStashを使わずに直接Gemini(Edge Function)を叩く処理
            PERFORM net.http_post(
              url := target_url,
              headers := jsonb_build_object(
                'Content-Type', 'application/json'
              ),
              body := jsonb_build_object(
                'room_id', NEW.id,
                'theme', NEW.current_theme,
                'player1_choice', NEW.current_choice1,
                'player2_choice', NEW.current_choice2
              )
            );
            RAISE NOTICE 'Direct Gemini judging called for room_id: %', NEW.id;
        END IF;

        -- 一度両者が true になったら、それ以降変動させずに固定する
        IF OLD.player1_finish IS TRUE AND OLD.player2_finish IS TRUE THEN
            NEW.player1_finish := TRUE;
            NEW.player2_finish := TRUE;
        END IF;

        NEW.updated_at = NOW();
    END IF; 

    RETURN NEW;
END;$$;


ALTER FUNCTION "public"."handle_room_updates_integrated"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."initiate_data_transfer"("p_sender_id" "uuid") RETURNS TABLE("transfer_id" "text", "transfer_password" "text")
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_transfer_id text;
    v_transfer_password text;
    v_delete_at timestamp with time zone;
BEGIN
    -- 既存の未完了かつ有効期限内の移行要求があれば削除
    -- send_idが一致し、まだ受け取られておらず (receive_id IS NULL)、
    -- かつ有効期限内 (delete_at > now()) のものを削除
    DELETE FROM public.transfer
    WHERE send_id = p_sender_id
      AND receive_id IS NULL;

    -- 新しい移行IDとパスワードを生成
    -- generate_random_id は別途定義されている必要があります。
    -- 例: substr(md5(random()::text || clock_timestamp()::text), 1, length)
    -- ここでは与えられた通り generate_random_id を使用します。
    v_transfer_id := generate_random_id(6);
    v_transfer_password := generate_random_id(6);
    v_delete_at := now() + interval '1 hour';

    -- トランザクション開始 (PL/pgSQLではBEGIN/ENDブロック全体が1つのトランザクション)

    -- ユーザーのステータスをfalseに設定 (例: 移行処理中は操作不可とするなど)
    UPDATE public.users
    SET status = false
    WHERE id = p_sender_id;

    -- usersテーブルの更新が成功したか確認 (更新対象が見つからない場合 FOUND は false)
    IF NOT FOUND THEN
        RAISE EXCEPTION 'User not found or status could not be updated for user_id: %', p_sender_id;
    END IF;

    -- transferテーブルに新しいレコードを挿入
    INSERT INTO public.transfer (id, send_id, password, delete_at)
    VALUES (v_transfer_id, p_sender_id, v_transfer_password, v_delete_at);

    -- 生成されたIDとパスワードを返す
    RETURN QUERY SELECT v_transfer_id, v_transfer_password;

EXCEPTION
    WHEN OTHERS THEN
        -- 何らかのエラーが発生した場合、トランザクションは自動的にロールバックされる
        RAISE INFO 'Error in initiate_data_transfer for sender_id %: %', p_sender_id, SQLERRM;
        RAISE; -- エラーを再スローしてクライアントに通知
END;
$$;


ALTER FUNCTION "public"."initiate_data_transfer"("p_sender_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."join_room"("p_user_id" "uuid", "p_room_password" "text", "p_room_theme" "text", "p_room_choice1" "text", "p_room_choice2" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  target_room_id UUID;
  room_data JSONB;
  v_theme_provided BOOLEAN; -- 関数呼び出し時に提供されたテーマ・選択肢が有効かどうかのフラグ
BEGIN
  -- トランザクション開始 (PL/pgSQLのBEGIN/ENDブロック内で自動的に処理される)
  BEGIN
    -- 提供されたテーマ・選択肢が有効かどうかのフラグを事前に計算
    -- すべてが NULL でなく、かつ空文字列でもない場合に TRUE
    v_theme_provided := (
        p_room_theme IS NOT NULL AND p_room_theme != '' AND
        p_room_choice1 IS NOT NULL AND p_room_choice1 != '' AND
        p_room_choice2 IS NOT NULL AND p_room_choice2 != ''
    );

    -- パスワード指定有りの場合
    IF p_room_password IS NOT NULL THEN
      -- FOR UPDATE を使用して行ロックを取得
      SELECT id INTO target_room_id
      FROM rooms
      WHERE rooms.player2_id IS NULL       -- player2がまだいない
        AND rooms.password = p_room_password -- 指定されたパスワードと一致
        AND rooms.player1_id != p_user_id  -- 自分が作ったルームではない
      LIMIT 1
      FOR UPDATE SKIP LOCKED; -- ロックされている行はスキップ
    ELSE
      -- パスワード無しの一般マッチング
      SELECT id INTO target_room_id
      FROM rooms
      WHERE rooms.player2_id IS NULL       -- player2がまだいない
        AND rooms.password IS NULL         -- パスワードが設定されていない
        AND rooms.player1_id != p_user_id  -- 自分が作ったルームではない
      LIMIT 1
      FOR UPDATE SKIP LOCKED; -- ロックされている行はスキップ
    END IF;

    -- 適切な部屋が見つかった場合 (既存の部屋に参加)
    IF target_room_id IS NOT NULL THEN
      -- 部屋を更新
      UPDATE rooms
      SET
          player2_id = p_user_id, -- 参加ユーザーを player2 に設定
          is_matched = true,      -- マッチング成立フラグを立てる
          updated_at = NOW(),
          -- テーマと選択肢を条件付きで更新:
          --   既存の theme_s が false であり、
          --   かつ、今回参加するプレイヤーが有効なテーマ/選択肢を提供した場合 (v_theme_provided = true) のみ更新する。
          --   それ以外の場合は、既存の値を維持する。
          current_theme = CASE
                            WHEN rooms.theme_s = false AND v_theme_provided = true THEN p_room_theme
                            ELSE rooms.current_theme
                          END,
          current_choice1 = CASE
                              WHEN rooms.theme_s = false AND v_theme_provided = true THEN p_room_choice1
                              ELSE rooms.current_choice1
                            END,
          current_choice2 = CASE
                              WHEN rooms.theme_s = false AND v_theme_provided = true THEN p_room_choice2
                              ELSE rooms.current_choice2
                            END,
          -- theme_s を条件付きで更新:
          --   既存の theme_s が false であり、
          --   かつ、今回参加するプレイヤーが有効なテーマ/選択肢を提供した場合 (v_theme_provided = true) のみ true に更新する。
          --   既存の theme_s が true の場合、または参加者が有効なテーマを提供しなかった場合は、既存の値 (true または false) を維持する。
          theme_s = CASE
                      WHEN rooms.theme_s = false AND v_theme_provided = true THEN true
                      ELSE rooms.theme_s
                    END
      WHERE id = target_room_id;

      -- 更新された部屋のデータを取得
      SELECT to_jsonb(r) INTO room_data
      FROM rooms r
      WHERE r.id = target_room_id;

      -- 結果を返す
      RETURN jsonb_build_object(
        'success', true,
        'action', 'joined', -- '参加した'ことを示す
        'room', room_data
      );
    ELSE
      -- 適切な部屋が見つからなかった場合 (新しい部屋を作成)
      -- 参加しようとしたユーザーを player1_id に設定し、
      -- 提供されたテーマと選択肢、および theme_s フラグを設定して新しい部屋を作成
      INSERT INTO rooms (
        player1_id,
        password,
        current_theme,
        current_choice1,
        current_choice2,
        theme_s -- theme_s カラム: 作成者が有効なテーマ/選択肢を提供したかどうか
      )
      VALUES (
        p_user_id,          -- ユーザーを player1 に
        p_room_password,    -- 指定パスワードを設定 (NULLの場合もある)
        p_room_theme,       -- テーマを設定 (NULLの場合もある)
        p_room_choice1,     -- 選択肢1を設定 (NULLの場合もある)
        p_room_choice2,     -- 選択肢2を設定 (NULLの場合もある)
        v_theme_provided    -- 計算済みのフラグ (作成者が有効なテーマ/選択肢を提供したか) を使用
      )
      RETURNING to_jsonb(rooms.*) INTO room_data; -- 作成された部屋のデータを取得

      -- 結果を返す
      RETURN jsonb_build_object(
        'success', true,
        'action', 'created', -- '作成した'ことを示す
        'room', room_data
      );

    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      -- 何らかのエラーが発生した場合
      -- エラーハンドリング: 失敗を示すJSONを返す
      RETURN jsonb_build_object(
        'success', false,
        'error', SQLERRM -- エラーメッセージを含める
      );
  END;
END;
$$;


ALTER FUNCTION "public"."join_room"("p_user_id" "uuid", "p_room_password" "text", "p_room_theme" "text", "p_room_choice1" "text", "p_room_choice2" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."manage_room_theme"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$DECLARE
    selected_theme RECORD;
    total_themes INT;
    current_used_ids INTEGER[];
    new_theme_id INT;
BEGIN
    -- INSERT時 (ルーム作成時)
    IF TG_OP = 'INSERT' THEN
        -- theme_s が TRUE かどうかで分岐
        IF NEW.theme_s IS TRUE THEN
            -- theme_sがTRUEの場合: テーマ関連フィールドは変更せず、
            --                     playerの選択肢とchangeフラグのみ初期化する。
            -- 注意: この場合、current_theme, current_choice1, current_choice2, used_theme_ids は
            --       INSERT文で適切に設定されるか、列のデフォルト値が適用されることを想定しています。
            NEW.player1_choice := NULL; -- 初期化
            NEW.player2_choice := NULL; -- 初期化
            NEW.change := FALSE; -- 初期状態はFALSE
            -- NEW.current_theme, NEW.current_choice1, NEW.current_choice2, NEW.used_theme_ids は変更しない

        ELSE
            -- theme_sがFALSEまたはNULLの場合: ランダムテーマ選択ロジックを実行
            -- debate_themesからランダムに1件選択
            SELECT * INTO selected_theme
            FROM debate_themes
            ORDER BY random()
            LIMIT 1;

            -- 新しいレコードにテーマ情報を設定
            NEW.current_theme := selected_theme.theme;
            NEW.current_choice1 := selected_theme.choice1;
            NEW.current_choice2 := selected_theme.choice2;
            NEW.player1_choice := NULL; -- 初期化
            NEW.player2_choice := NULL; -- 初期化
            NEW.change := FALSE; -- 初期状態はFALSE
            NEW.used_theme_ids := ARRAY[selected_theme.id]; -- 最初のテーマを使用済みリストに追加
        END IF;

    -- UPDATE時
    ELSIF TG_OP = 'UPDATE' THEN
        -- player1_choice と player2_choice が両方ともNULLでなく、かつ一致した場合に処理を実行
        IF NEW.player1_choice IS NOT NULL AND
           NEW.player2_choice IS NOT NULL AND
           NEW.player1_choice = NEW.player2_choice AND
           -- 無限ループ防止: 前回の状態では一致していなかったか、どちらかがNULLだった場合
           (OLD.player1_choice IS NULL OR OLD.player2_choice IS NULL OR OLD.player1_choice <> OLD.player2_choice)
        THEN
            -- theme_s が FALSE (または NULL) の場合のみテーマ更新ロジックを実行
            -- OLD.theme_s を参照して、トリガー起動前の状態に基づいて判断する
            IF COALESCE(OLD.theme_s, FALSE) IS FALSE THEN

                -- 現在の使用済みテーマIDリストを取得 (NULLなら空配列)
                current_used_ids := COALESCE(OLD.used_theme_ids, ARRAY[]::INTEGER[]);

                -- 総テーマ数を取得
                SELECT count(*) INTO total_themes FROM debate_themes;

                -- もし使用済みリストが総テーマ数以上ならリセット
                IF array_length(current_used_ids, 1) >= total_themes THEN
                    current_used_ids := ARRAY[]::INTEGER[];
                END IF;

                -- 使用済みリストに含まれないテーマIDをランダムに1件選択
                SELECT id INTO new_theme_id
                FROM debate_themes
                WHERE id <> ALL(current_used_ids) -- NOT IN (unnest(current_used_ids)) でも可
                ORDER BY random()
                LIMIT 1;

                -- 新しいテーマが見つかった場合のみテーマ情報を更新
                IF new_theme_id IS NOT NULL THEN
                    -- 新しいテーマ情報を取得
                    SELECT * INTO selected_theme
                    FROM debate_themes
                    WHERE id = new_theme_id;

                    -- 新しいレコードに新しいテーマ情報を設定
                    NEW.current_theme := selected_theme.theme;
                    NEW.current_choice1 := selected_theme.choice1;
                    NEW.current_choice2 := selected_theme.choice2;
                    NEW.used_theme_ids := array_append(current_used_ids, new_theme_id); -- 新しいテーマIDを使用済みリストに追加
                ELSE
                    -- 新しいテーマが見つからない場合（全テーマ使用済みなど）
                    -- 使用済みリストはリセットされた状態かもしれないので反映
                    NEW.used_theme_ids := current_used_ids;
                    -- テーマ自体は変更しない
                END IF;

            -- ELSE (theme_s が TRUE の場合) はテーマ更新ロジックを実行しない
            END IF; -- End of theme update logic (only if theme_s is FALSE)

            -- 共通処理: プレイヤーの選択をリセットし、changeフラグを反転
            -- この処理は theme_s の値に関わらず、プレイヤーの選択が一致した場合に実行される
            NEW.player1_choice := NULL;
            NEW.player2_choice := NULL;
            NEW.change := NOT OLD.change; 
            NEW.updated_at = NOW();

        END IF; -- End of player choice check
        
            NEW.updated_at = NOW();
    END IF; -- End of TG_OP check

    -- 変更された新しい行を返す (BEFOREトリガーに必須)
    RETURN NEW;
END;$$;


ALTER FUNCTION "public"."manage_room_theme"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."prevent_result_update"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  -- すでに判定(winner)がセットされている場合、更新を禁止する
  IF OLD.winner IS NOT NULL AND NEW.winner IS DISTINCT FROM OLD.winner THEN
    RAISE EXCEPTION 'Judgment results cannot be updated once set.';
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."prevent_result_update"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."process_game_result"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  v_winner_id uuid := NULL;
  v_loser_id uuid := NULL;
  v_winner_trophy integer;
  v_loser_trophy integer;
  v_points_change integer := 0;
  v_is_ranked_match BOOLEAN;
BEGIN
  -- ランクマッチ（パスワードなし）判定
  v_is_ranked_match := (NEW.password IS NULL OR NEW.password = '');
  NEW.updated_at = now();

  -- winner カラムを直接判定
  IF NEW.winner = 'A' THEN
    v_winner_id := NEW.player1_id;
    v_loser_id := NEW.player2_id;
  ELSIF NEW.winner = 'B' THEN
    v_winner_id := NEW.player2_id;
    v_loser_id := NEW.player1_id;
  END IF;

  -- 勝者が確定している場合のみレーティング計算
  IF v_winner_id IS NOT NULL THEN
    IF v_is_ranked_match THEN
      SELECT trophy INTO v_winner_trophy FROM users WHERE id = v_winner_id;
      SELECT trophy INTO v_loser_trophy FROM users WHERE id = v_loser_id;
      v_points_change := calculate_elo_rating(v_winner_trophy, v_loser_trophy);

      UPDATE users SET win = win + 1, trophy = trophy + v_points_change WHERE id = v_winner_id;
      UPDATE users SET lose = lose + 1, trophy = GREATEST(0, trophy - v_points_change) WHERE id = v_loser_id;
    END IF;
  ELSE
    -- A/B以外（エラー'C'など）の救済措置
    IF v_is_ranked_match THEN
      UPDATE users SET win = win + 1, trophy = trophy + 16 WHERE id = NEW.player1_id;
      UPDATE users SET win = win + 1, trophy = trophy + 16 WHERE id = NEW.player2_id;
      v_points_change := 16;
    END IF;
  END IF;

  -- 履歴への挿入
  INSERT INTO match_record (
    roomid, player1_id, player2_id, theme, winner, move_trophy, result
  ) VALUES (
    NEW.id, NEW.player1_id, NEW.player2_id, NEW.current_theme, v_winner_id, v_points_change, NEW.reason
  );

  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."process_game_result"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."schedule_gemini_with_qstash"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  qstash_token text := 'eyJVc2VySUQiOiJhYzQ3YjI2Yi03MTg4LTQ4ZjUtYTIwMS00ZGE2MTQ0ZmEwZDAiLCJQYXNzd29yZCI6IjJlYjA4YzRlZjg2YjRkNjI5YTg4ODhkYjFmNzU2OTczIn0=';
  target_url text := 'https://undebilitative-engagedly-salma.ngrok-free.dev/functions/v1/gemini';
  qstash_publish_url text := 'https://qstash-us-east-1.upstash.io/v2/publish/' || target_url;
BEGIN
  -- 変更点: お互いの選択が完了（NULLではない）し、かつ被らなかった（選択が異なる）場合
  IF (NEW.player1_choice IS NOT NULL AND NEW.player2_choice IS NOT NULL AND NEW.player1_choice != NEW.player2_choice) 
     -- 以前の状態は「どちらかがNULLだった」か「被っていた」場合（重複して発火するのを防ぐため）
     AND (OLD.player1_choice IS NULL OR OLD.player2_choice IS NULL OR OLD.player1_choice = OLD.player2_choice) THEN
    PERFORM net.http_post(
      url := qstash_publish_url,
      headers := jsonb_build_object(
        'Authorization', 'Bearer ' || qstash_token,
        'Content-Type', 'application/json',
        -- 変更点: 10秒後に設定
        'Upstash-Delay', '10s'
      ),
      body := jsonb_build_object(
        'room_id', NEW.id,
        'theme', NEW.current_theme,
        'player1_choice', NEW.current_choice1,
        'player2_choice', NEW.current_choice2
      )::text
    );
    RAISE NOTICE 'QStash timer scheduled for room_id: %', NEW.id;
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."schedule_gemini_with_qstash"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_updated_at_column"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_updated_at_column"() OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."app_config" (
    "id" bigint NOT NULL,
    "min_supported_version_android" "text" NOT NULL,
    "min_supported_version_ios" "text" NOT NULL,
    "latest_version_android" "text" NOT NULL,
    "latest_version_ios" "text" NOT NULL,
    "changelog" "text",
    "maintenance_message" "text",
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "is_maintenance" boolean DEFAULT false
);


ALTER TABLE "public"."app_config" OWNER TO "postgres";


ALTER TABLE "public"."app_config" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."app_config_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."brock_user" (
    "id" bigint NOT NULL,
    "user_id" "uuid" NOT NULL,
    "block_user_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."brock_user" OWNER TO "postgres";


ALTER TABLE "public"."brock_user" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."brock_user_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."bugs" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "user_id" "uuid",
    "device_info" "text" NOT NULL,
    "bug_description" "text" NOT NULL
);


ALTER TABLE "public"."bugs" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."debate_themes" (
    "id" integer NOT NULL,
    "theme" "text" NOT NULL,
    "choice1" "text" NOT NULL,
    "choice2" "text" NOT NULL
);


ALTER TABLE "public"."debate_themes" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."debate_themes_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE "public"."debate_themes_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."debate_themes_id_seq" OWNED BY "public"."debate_themes"."id";



CREATE TABLE IF NOT EXISTS "public"."debate_themes_request" (
    "theme" "text" NOT NULL,
    "choice1" "text" NOT NULL,
    "choice2" "text" NOT NULL,
    "sender_id" "uuid" DEFAULT "auth"."uid"() NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."debate_themes_request" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."match_record" (
    "roomid" "uuid" NOT NULL,
    "player1_id" "uuid",
    "player2_id" "uuid",
    "theme" "text",
    "player1_choice" "text",
    "player2_choice" "text",
    "winner" "uuid",
    "move_trophy" integer,
    "result" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "cancel" boolean
);


ALTER TABLE "public"."match_record" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."messages" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "room_id" "uuid",
    "sender_id" "uuid",
    "content" "text",
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL
);


ALTER TABLE "public"."messages" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."prohibited" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "room_id" "uuid",
    "user_id" "uuid",
    "chat_id" "uuid"
);


ALTER TABLE "public"."prohibited" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."rooms" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "player1_id" "uuid",
    "player2_id" "uuid",
    "is_matched" boolean DEFAULT false,
    "player1_choice" boolean,
    "player2_choice" boolean,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "current_theme" "text",
    "current_choice1" "text",
    "current_choice2" "text",
    "change" boolean DEFAULT false,
    "player1_finish" boolean DEFAULT false,
    "player2_finish" boolean DEFAULT false,
    "player1_time" timestamp with time zone,
    "player2_time" timestamp with time zone,
    "used_theme_ids" integer[],
    "password" character varying(10),
    "theme_s" boolean DEFAULT false NOT NULL,
    "player1_go" boolean,
    "player2_go" boolean,
    "reason" "text",
    "winner" character(1)
);


ALTER TABLE "public"."rooms" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."transfer" (
    "id" "text" NOT NULL,
    "send_id" "uuid",
    "receive_id" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "delete_at" timestamp with time zone,
    "password" "text"
);


ALTER TABLE "public"."transfer" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."users" (
    "id" "uuid" NOT NULL,
    "name" "text",
    "trophy" integer DEFAULT 0 NOT NULL,
    "win" integer DEFAULT 0,
    "lose" integer DEFAULT 0,
    "avatar_url" "text",
    "status" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."users" OWNER TO "postgres";


ALTER TABLE ONLY "public"."debate_themes" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."debate_themes_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."app_config"
    ADD CONSTRAINT "app_config_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."brock_user"
    ADD CONSTRAINT "brock_user_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."bugs"
    ADD CONSTRAINT "bugs_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."debate_themes"
    ADD CONSTRAINT "debate_themes_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."debate_themes_request"
    ADD CONSTRAINT "debate_themes_request_pkey" PRIMARY KEY ("theme");



ALTER TABLE ONLY "public"."match_record"
    ADD CONSTRAINT "match_record_pkey" PRIMARY KEY ("roomid");



ALTER TABLE ONLY "public"."messages"
    ADD CONSTRAINT "messages_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."prohibited"
    ADD CONSTRAINT "prohibited_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."rooms"
    ADD CONSTRAINT "rooms_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."transfer"
    ADD CONSTRAINT "transfer_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "users_pkey" PRIMARY KEY ("id");



CREATE OR REPLACE TRIGGER "prevent_result_update_trigger" BEFORE UPDATE ON "public"."rooms" FOR EACH ROW EXECUTE FUNCTION "public"."prevent_result_update"();



CREATE OR REPLACE TRIGGER "process_game_result" BEFORE UPDATE OF "reason" ON "public"."rooms" FOR EACH ROW WHEN ((("old"."reason" IS NULL) AND ("new"."reason" IS NOT NULL))) EXECUTE FUNCTION "public"."process_game_result"();



CREATE OR REPLACE TRIGGER "tr_handle_room_updates_integrated" BEFORE INSERT OR UPDATE ON "public"."rooms" FOR EACH ROW EXECUTE FUNCTION "public"."handle_room_updates_integrated"();



CREATE OR REPLACE TRIGGER "trigger_rooms_update_player2_id" BEFORE UPDATE OF "player2_id" ON "public"."rooms" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



ALTER TABLE ONLY "public"."debate_themes_request"
    ADD CONSTRAINT "debate_themes_request_sender_id_fkey" FOREIGN KEY ("sender_id") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."match_record"
    ADD CONSTRAINT "fk_match_record_player1_user" FOREIGN KEY ("player1_id") REFERENCES "public"."users"("id");



ALTER TABLE ONLY "public"."match_record"
    ADD CONSTRAINT "fk_match_record_player2_user" FOREIGN KEY ("player2_id") REFERENCES "public"."users"("id");



ALTER TABLE ONLY "public"."messages"
    ADD CONSTRAINT "messages_user_id_fkey" FOREIGN KEY ("sender_id") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "users_id_fkey" FOREIGN KEY ("id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



CREATE POLICY "Allow all access for anon and authenticated" ON "public"."users" TO "authenticated", "anon" USING (true) WITH CHECK (true);



CREATE POLICY "Allow all access for authenticated and anon users" ON "public"."transfer" TO "authenticated", "anon" USING (true) WITH CHECK (true);



CREATE POLICY "Allow all for anonymous users" ON "public"."messages" TO "anon" USING (true) WITH CHECK (true);



CREATE POLICY "Allow all for anonymous users" ON "public"."rooms" TO "anon" USING (true) WITH CHECK (true);



CREATE POLICY "Allow all for authenticated users" ON "public"."messages" TO "authenticated" USING (true) WITH CHECK (true);



CREATE POLICY "Allow all for authenticated users" ON "public"."rooms" TO "authenticated" USING (true) WITH CHECK (true);



CREATE POLICY "Allow all inserts" ON "public"."prohibited" FOR INSERT WITH CHECK (true);



CREATE POLICY "Allow all operations for all users" ON "public"."match_record" USING (true) WITH CHECK (true);



CREATE POLICY "Allow authenticated and anonymous users to insert their bug rep" ON "public"."bugs" FOR INSERT WITH CHECK (((("auth"."uid"() IS NOT NULL) AND ("user_id" = "auth"."uid"())) OR (("auth"."uid"() IS NULL) AND ("user_id" IS NULL))));



CREATE POLICY "Allow insert for anon and authenticated users" ON "public"."debate_themes_request" FOR INSERT TO "authenticated", "anon" WITH CHECK (true);



CREATE POLICY "Allow public insert access" ON "public"."brock_user" FOR INSERT WITH CHECK (true);



CREATE POLICY "Allow read access to everyone" ON "public"."app_config" FOR SELECT USING (true);



ALTER TABLE "public"."app_config" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."brock_user" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."bugs" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."debate_themes" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "debate_themes_insert_policy" ON "public"."debate_themes" FOR INSERT TO "authenticated" WITH CHECK (true);



ALTER TABLE "public"."debate_themes_request" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "debate_themes_select_policy" ON "public"."debate_themes" FOR SELECT USING (true);



ALTER TABLE "public"."match_record" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."messages" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."prohibited" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."rooms" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."transfer" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."users" ENABLE ROW LEVEL SECURITY;




ALTER PUBLICATION "supabase_realtime" OWNER TO "postgres";






ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."messages";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."rooms";









GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";






































































































































































































GRANT ALL ON FUNCTION "public"."calculate_elo_rating"("winner_rate" numeric, "loser_rate" numeric) TO "anon";
GRANT ALL ON FUNCTION "public"."calculate_elo_rating"("winner_rate" numeric, "loser_rate" numeric) TO "authenticated";
GRANT ALL ON FUNCTION "public"."calculate_elo_rating"("winner_rate" numeric, "loser_rate" numeric) TO "service_role";



GRANT ALL ON FUNCTION "public"."cancel_data_transfer"("p_sender_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."cancel_data_transfer"("p_sender_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."cancel_data_transfer"("p_sender_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."cancel_data_transfer_robust"("p_sender_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."cancel_data_transfer_robust"("p_sender_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."cancel_data_transfer_robust"("p_sender_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."complete_data_transfer"("p_transfer_id" "text", "p_password" "text", "p_receiver_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."complete_data_transfer"("p_transfer_id" "text", "p_password" "text", "p_receiver_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."complete_data_transfer"("p_transfer_id" "text", "p_password" "text", "p_receiver_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."delete_old_rooms_with_result"() TO "anon";
GRANT ALL ON FUNCTION "public"."delete_old_rooms_with_result"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."delete_old_rooms_with_result"() TO "service_role";



GRANT ALL ON FUNCTION "public"."deleteroom"("p_room_id" "uuid", "p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."deleteroom"("p_room_id" "uuid", "p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."deleteroom"("p_room_id" "uuid", "p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."generate_random_id"("len" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."generate_random_id"("len" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."generate_random_id"("len" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."generate_random_password"() TO "anon";
GRANT ALL ON FUNCTION "public"."generate_random_password"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."generate_random_password"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_nearby_ranking"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_nearby_ranking"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_nearby_ranking"("p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_recent_match_history"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_recent_match_history"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_recent_match_history"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_room_data"("p_room_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_room_data"("p_room_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_room_data"("p_room_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_server_time"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_server_time"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_server_time"() TO "service_role";



GRANT ALL ON FUNCTION "public"."handle_cancellation"("p_user_id" "uuid", "p_room_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."handle_cancellation"("p_user_id" "uuid", "p_room_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_cancellation"("p_user_id" "uuid", "p_room_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."handle_new_auth_user"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_new_auth_user"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_new_auth_user"() TO "service_role";



GRANT ALL ON FUNCTION "public"."handle_room_updates_integrated"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_room_updates_integrated"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_room_updates_integrated"() TO "service_role";



GRANT ALL ON FUNCTION "public"."initiate_data_transfer"("p_sender_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."initiate_data_transfer"("p_sender_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."initiate_data_transfer"("p_sender_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."join_room"("p_user_id" "uuid", "p_room_password" "text", "p_room_theme" "text", "p_room_choice1" "text", "p_room_choice2" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."join_room"("p_user_id" "uuid", "p_room_password" "text", "p_room_theme" "text", "p_room_choice1" "text", "p_room_choice2" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."join_room"("p_user_id" "uuid", "p_room_password" "text", "p_room_theme" "text", "p_room_choice1" "text", "p_room_choice2" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."manage_room_theme"() TO "anon";
GRANT ALL ON FUNCTION "public"."manage_room_theme"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."manage_room_theme"() TO "service_role";



GRANT ALL ON FUNCTION "public"."prevent_result_update"() TO "anon";
GRANT ALL ON FUNCTION "public"."prevent_result_update"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."prevent_result_update"() TO "service_role";



GRANT ALL ON FUNCTION "public"."process_game_result"() TO "anon";
GRANT ALL ON FUNCTION "public"."process_game_result"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."process_game_result"() TO "service_role";



GRANT ALL ON FUNCTION "public"."schedule_gemini_with_qstash"() TO "anon";
GRANT ALL ON FUNCTION "public"."schedule_gemini_with_qstash"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."schedule_gemini_with_qstash"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "service_role";
























GRANT ALL ON TABLE "public"."app_config" TO "anon";
GRANT ALL ON TABLE "public"."app_config" TO "authenticated";
GRANT ALL ON TABLE "public"."app_config" TO "service_role";



GRANT ALL ON SEQUENCE "public"."app_config_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."app_config_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."app_config_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."brock_user" TO "anon";
GRANT ALL ON TABLE "public"."brock_user" TO "authenticated";
GRANT ALL ON TABLE "public"."brock_user" TO "service_role";



GRANT ALL ON SEQUENCE "public"."brock_user_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."brock_user_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."brock_user_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."bugs" TO "anon";
GRANT ALL ON TABLE "public"."bugs" TO "authenticated";
GRANT ALL ON TABLE "public"."bugs" TO "service_role";



GRANT ALL ON TABLE "public"."debate_themes" TO "anon";
GRANT ALL ON TABLE "public"."debate_themes" TO "authenticated";
GRANT ALL ON TABLE "public"."debate_themes" TO "service_role";



GRANT ALL ON SEQUENCE "public"."debate_themes_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."debate_themes_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."debate_themes_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."debate_themes_request" TO "anon";
GRANT ALL ON TABLE "public"."debate_themes_request" TO "authenticated";
GRANT ALL ON TABLE "public"."debate_themes_request" TO "service_role";



GRANT ALL ON TABLE "public"."match_record" TO "anon";
GRANT ALL ON TABLE "public"."match_record" TO "authenticated";
GRANT ALL ON TABLE "public"."match_record" TO "service_role";



GRANT ALL ON TABLE "public"."messages" TO "anon";
GRANT ALL ON TABLE "public"."messages" TO "authenticated";
GRANT ALL ON TABLE "public"."messages" TO "service_role";



GRANT ALL ON TABLE "public"."prohibited" TO "anon";
GRANT ALL ON TABLE "public"."prohibited" TO "authenticated";
GRANT ALL ON TABLE "public"."prohibited" TO "service_role";



GRANT ALL ON TABLE "public"."rooms" TO "anon";
GRANT ALL ON TABLE "public"."rooms" TO "authenticated";
GRANT ALL ON TABLE "public"."rooms" TO "service_role";



GRANT ALL ON TABLE "public"."transfer" TO "anon";
GRANT ALL ON TABLE "public"."transfer" TO "authenticated";
GRANT ALL ON TABLE "public"."transfer" TO "service_role";



GRANT ALL ON TABLE "public"."users" TO "anon";
GRANT ALL ON TABLE "public"."users" TO "authenticated";
GRANT ALL ON TABLE "public"."users" TO "service_role";









ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "service_role";






























