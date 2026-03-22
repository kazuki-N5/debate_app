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
                'Upstash-Delay', '3m'
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
