-- rooms_v3 テーブルの作成
create table public.rooms_v3 (
  id uuid not null default gen_random_uuid (),
  player1_id uuid null,
  player2_id uuid null,
  is_matched boolean null default false,
  player1_choice boolean null,
  player2_choice boolean null,
  created_at timestamp with time zone null default now(),
  updated_at timestamp with time zone null default now(),
  current_theme text null,
  current_choice1 text null,
  current_choice2 text null,
  change boolean null default false,
  player1_finish boolean null default false,
  player2_finish boolean null default false,
  player1_time timestamp with time zone null,
  player2_time timestamp with time zone null,
  used_theme_ids integer[] null,
  password character varying(10) null,
  theme_s boolean not null default false,
  player1_go boolean null,
  player2_go boolean null,
  reason text null,
  winner character(1) null,
  constraint rooms_v3_pkey primary key (id)
) TABLESPACE pg_default;

-- handle_room_updates_v3 関数の作成
create or replace function handle_room_updates_v3()
returns trigger as $$
DECLARE
    selected_theme RECORD;
    total_themes INT;
    current_used_ids INTEGER[];
    new_theme_id INT;
    -- v2->v3への変更
    qstash_token text := 'eyJVc2VySUQiOiJhYzQ3YjI2Yi03MTg4LTQ4ZjUtYTIwMS00ZGE2MTQ0ZmEwZDAiLCJQYXNzd29yZCI6IjJlYjA4YzRlZjg2YjRkNjI5YTg4ODhkYjFmNzU2OTczIn0=';
    target_url text := 'https://ljgvqdcailabzuutaeha.supabase.co/functions/v1/gemini_v3';
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
                headers := jsonb_build_object('Authorization', 'Bearer ' || qstash_token, 'Content-Type', 'application/json', 'Upstash-Delay', '3m'),
                body := jsonb_build_object(
                    'room_id', NEW.id, 
                    'theme', NEW.current_theme, 
                    'player1_choice', NEW.current_choice1, 
                    'player2_choice', NEW.current_choice2,
                    'table_name', TG_TABLE_NAME -- rooms_v3
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
END;
$$ language plpgsql;

-- rooms_v3 テーブルにトリガーを適用
create trigger tr_v3_handle_room_updates BEFORE INSERT
or
update on rooms_v3 for EACH row
execute FUNCTION handle_room_updates_v3 ();

-- join_room_v3 関数の作成
create or replace function join_room_v3(
    p_user_id uuid,
    p_room_password character varying default null,
    p_room_theme text default null,
    p_room_choice1 text default null,
    p_room_choice2 text default null
)
returns jsonb as $$
DECLARE target_room_id UUID; room_data JSONB; v_theme_provided BOOLEAN;
BEGIN
    v_theme_provided := (p_room_theme IS NOT NULL AND p_room_theme != '' AND p_room_choice1 IS NOT NULL AND p_room_choice1 != '' AND p_room_choice2 IS NOT NULL AND p_room_choice2 != '');
    IF p_room_password IS NOT NULL THEN
      SELECT id INTO target_room_id FROM rooms_v3 WHERE player2_id IS NULL AND password = p_room_password AND player1_id != p_user_id LIMIT 1 FOR UPDATE SKIP LOCKED;
    ELSE
      SELECT id INTO target_room_id FROM rooms_v3 WHERE player2_id IS NULL AND password IS NULL AND player1_id != p_user_id LIMIT 1 FOR UPDATE SKIP LOCKED;
    END IF;
    IF target_room_id IS NOT NULL THEN
      UPDATE rooms_v3 SET player2_id = p_user_id, is_matched = true, updated_at = NOW(),
          current_theme = CASE WHEN theme_s = false AND v_theme_provided = true THEN p_room_theme ELSE current_theme END,
          current_choice1 = CASE WHEN theme_s = false AND v_theme_provided = true THEN p_room_choice1 ELSE current_choice1 END,
          current_choice2 = CASE WHEN theme_s = false AND v_theme_provided = true THEN p_room_choice2 ELSE current_choice2 END,
          theme_s = CASE WHEN theme_s = false AND v_theme_provided = true THEN true ELSE theme_s END
      WHERE id = target_room_id;
      SELECT to_jsonb(r) INTO room_data FROM rooms_v3 r WHERE r.id = target_room_id;
      RETURN jsonb_build_object('success', true, 'action', 'joined', 'room', room_data);
    ELSE
      INSERT INTO rooms_v3 (player1_id, password, current_theme, current_choice1, current_choice2, theme_s)
      VALUES (p_user_id, p_room_password, p_room_theme, p_room_choice1, p_room_choice2, v_theme_provided)
      RETURNING to_jsonb(rooms_v3.*) INTO room_data;
      RETURN jsonb_build_object('success', true, 'action', 'created', 'room', room_data);
    END IF;
END;
$$ language plpgsql;

-- rooms_v3 の RLS を有効化
ALTER TABLE public.rooms_v3 ENABLE ROW LEVEL SECURITY;

-- 匿名ユーザーを含むすべてのユーザーにすべての操作を許可
CREATE POLICY "Enable all operations for all users"
ON public.rooms_v3
FOR ALL
TO public
USING (true)
WITH CHECK (true);
