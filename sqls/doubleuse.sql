-- doubleuse.sql
-- 旧アプリ(roomsを使用)と新アプリ(rooms_v2を使用)を共存させるスクリプト
-- このスクリプトを Supabase の SQL Editor で実行してください。

-- 1. 必要な拡張機能の有効化
CREATE EXTENSION IF NOT EXISTS "pg_net" WITH SCHEMA "extensions";

-- 2. 既存テーブルの拡張 (users と match_record は新旧アプリで共有します)
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS "fcm_token" text;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS "is_notification_enabled" boolean DEFAULT false;

ALTER TABLE public.match_record ADD COLUMN IF NOT EXISTS "player1_move_trophy" integer;
ALTER TABLE public.match_record ADD COLUMN IF NOT EXISTS "player2_move_trophy" integer;
ALTER TABLE public.match_record ADD COLUMN IF NOT EXISTS "is_underdog" boolean DEFAULT false;

-- user 用の通知ログテーブル (存在しない場合)
CREATE TABLE IF NOT EXISTS "public"."notification_logs" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "notification_logs_pkey" PRIMARY KEY ("id")
);

-- 3. rooms_v2 テーブルの新設 (新アプリ専用)
CREATE TABLE IF NOT EXISTS "public"."rooms_v2" (
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
    "winner" character(1),
    CONSTRAINT "rooms_v2_pkey" PRIMARY KEY ("id")
);

-- RLS設定 (rooms_v2)
ALTER TABLE "public"."rooms_v2" ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all access rooms_v2" ON "public"."rooms_v2";
CREATE POLICY "Allow all access rooms_v2" ON "public"."rooms_v2" FOR ALL USING (true) WITH CHECK (true);

-- 4. V2用ロジック関数の定義

-- トロフィー計算関数 (Brawl Stars風ロジック)
CREATE OR REPLACE FUNCTION "public"."calculate_brawl_trophy_change"("p_my_trophy" integer, "p_opponent_trophy" integer, "p_is_win" boolean) RETURNS integer
    LANGUAGE "plpgsql" AS $$
DECLARE
    v_base_change integer;
    v_is_underdog boolean;
BEGIN
    v_is_underdog := (p_opponent_trophy - p_my_trophy) >= 200;
    IF p_is_win THEN
        IF p_my_trophy < 500 THEN v_base_change := 8;
        ELSIF p_my_trophy < 600 THEN v_base_change := 7;
        ELSIF p_my_trophy < 700 THEN v_base_change := 6;
        ELSIF p_my_trophy < 800 THEN v_base_change := 5;
        ELSIF p_my_trophy < 900 THEN v_base_change := 4;
        ELSE v_base_change := 3;
        END IF;
        RETURN CASE WHEN v_is_underdog THEN v_base_change + 4 ELSE v_base_change END;
    ELSE
        IF p_my_trophy < 50 THEN v_base_change := 0;
        ELSIF p_my_trophy < 100 THEN v_base_change := -1;
        ELSIF p_my_trophy < 200 THEN v_base_change := -2;
        ELSIF p_my_trophy < 300 THEN v_base_change := -3;
        ELSIF p_my_trophy < 400 THEN v_base_change := -4;
        ELSIF p_my_trophy < 500 THEN v_base_change := -5;
        ELSIF p_my_trophy < 600 THEN v_base_change := -6;
        ELSIF p_my_trophy < 700 THEN v_base_change := -7;
        ELSIF p_my_trophy < 800 THEN v_base_change := -8;
        ELSIF p_my_trophy < 900 THEN v_base_change := -9;
        ELSIF p_my_trophy < 1000 THEN v_base_change := -10;
        ELSIF p_my_trophy < 1100 THEN v_base_change := -11;
        ELSE v_base_change := -12;
        END IF;
        RETURN CASE WHEN v_is_underdog THEN LEAST(0, v_base_change + 4) ELSE v_base_change END;
    END IF;
END; $$;

-- 判定後処理 (v2_process_game_result)
CREATE OR REPLACE FUNCTION "public"."v2_process_game_result"() RETURNS "trigger"
    LANGUAGE "plpgsql" AS $$
DECLARE
  v_p1_trophy integer; v_p2_trophy integer;
  v_p1_move integer := 0; v_p2_move integer := 0;
  v_is_underdog_match boolean := false;
BEGIN
  IF (NEW.password IS NULL OR NEW.password = '') THEN
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
  
  -- match_record に記録 (歴史的一貫性のため result カラムに理由を入れる)
  INSERT INTO match_record (
    roomid, player1_id, player2_id, theme, winner, 
    player1_move_trophy, player2_move_trophy, is_underdog, 
    move_trophy, result
  ) VALUES (
    NEW.id, NEW.player1_id, NEW.player2_id, NEW.current_theme, 
    CASE WHEN NEW.winner = 'A' THEN NEW.player1_id WHEN NEW.winner = 'B' THEN NEW.player2_id ELSE NULL END, 
    v_p1_move, v_p2_move, v_is_underdog_match, 
    v_p1_move, NEW.reason
  );
  RETURN NEW;
END; $$;

-- 5. ルーム更新・Gemini呼び出しの統合
CREATE OR REPLACE FUNCTION "public"."handle_room_updates_v2"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    selected_theme RECORD;
    total_themes INT;
    current_used_ids INTEGER[];
    new_theme_id INT;
    qstash_token text := 'eyJVc2VySUQiOiJhYzQ3YjI2Yi03MTg4LTQ4ZjUtYTIwMS00ZGE2MTQ0ZmEwZDAiLCJQYXNzd29yZCI6IjJlYjA4YzRlZjg2YjRkNjI5YTg4ODhkYjFmNzU2OTczIn0=';
    target_url text := 'https://undebilitative-engagedly-salma.ngrok-free.dev/functions/v1/gemini';
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
        IF NEW.player1_choice IS NOT NULL AND NEW.player2_choice IS NOT NULL AND NEW.player1_choice = NEW.player2_choice AND
           (OLD.player1_choice IS NULL OR OLD.player1_choice != NEW.player1_choice)
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
              (OLD.player1_choice IS NULL OR OLD.player1_choice = NEW.player1_choice)
        THEN
            PERFORM net.http_post(
                url := qstash_publish_url,
                headers := jsonb_build_object('Authorization', 'Bearer ' || qstash_token, 'Content-Type', 'application/json', 'Upstash-Delay', '1m30s'),
                body := jsonb_build_object(
                    'room_id', NEW.id, 
                    'theme', NEW.current_theme, 
                    'player1_choice', NEW.current_choice1, 
                    'player2_choice', NEW.current_choice2,
                    'table_name', TG_TABLE_NAME -- rooms_v2 または rooms
                )
            );
        END IF;
        -- 直接判定 (finishボタン)
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
END; $$;

-- 6. V2用マッチングRPC
CREATE OR REPLACE FUNCTION "public"."join_room_v2"("p_user_id" "uuid", "p_room_password" "text", "p_room_theme" "text", "p_room_choice1" "text", "p_room_choice2" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql" AS $$
DECLARE target_room_id UUID; room_data JSONB; v_theme_provided BOOLEAN;
BEGIN
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

-- 7. トリガー設定 (rooms_v2 用)
DROP TRIGGER IF EXISTS "tr_v2_process_game_result" ON "public"."rooms";
DROP TRIGGER IF EXISTS "tr_v2_process_game_result" ON "public"."rooms_v2";
CREATE TRIGGER "tr_v2_process_game_result" BEFORE UPDATE OF "reason" ON "public"."rooms_v2" FOR EACH ROW WHEN ((OLD.reason IS NULL AND NEW.reason IS NOT NULL)) EXECUTE FUNCTION "public"."v2_process_game_result"();

DROP TRIGGER IF EXISTS "tr_v2_handle_room_updates" ON "public"."rooms_v2";
CREATE TRIGGER "tr_v2_handle_room_updates" BEFORE INSERT OR UPDATE ON "public"."rooms_v2" FOR EACH ROW EXECUTE FUNCTION "public"."handle_room_updates_v2"();

-- 既存の rooms テーブルはそのまま維持します。
