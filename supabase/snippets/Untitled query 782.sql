-- 不要になった先ほどの単独トリガーを削除
DROP TRIGGER IF EXISTS tr_schedule_gemini ON public.rooms;
-- ※もし既存のトリガー名があれば、それもここで DROP して置き換えてください。
-- DROP TRIGGER IF EXISTS 既存のトリガー名 ON public.rooms;

CREATE OR REPLACE FUNCTION public.handle_room_updates_integrated()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
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

        NEW.updated_at = NOW();
    END IF; 

    RETURN NEW;
END;
$$;

-- 統合した関数を BEFORE INSERT, BEFORE UPDATE のトリガーとして設定
CREATE TRIGGER tr_handle_room_updates_integrated
  BEFORE INSERT OR UPDATE ON public.rooms
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_room_updates_integrated();
