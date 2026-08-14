-- ==============================================================================
-- 【ローカル検証用 / 本番復帰用】handle_room_updates_v2 の target_url 切り替えSQL
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. ローカルテスト用（ngrok経由でローカルの gemini_v2 を実行する場合）
-- ------------------------------------------------------------------------------
-- ※ ngrok を起動し直してサブドメインが変わった場合は、下記URLのサブドメイン部分を書き換えて実行してください。
CREATE OR REPLACE FUNCTION public.handle_room_updates_v2() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$DECLARE
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
END;$$;


-- ------------------------------------------------------------------------------
-- 2. 本番復帰用（本番環境のEdge Function宛てに戻す場合）
-- ------------------------------------------------------------------------------
-- ※ 本番環境またはローカルDBを本番向けに戻す際に実行してください。
CREATE OR REPLACE FUNCTION public.handle_room_updates_v2() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$DECLARE
    selected_theme RECORD;
    total_themes INT;
    current_used_ids INTEGER[];
    new_theme_id INT;
    qstash_token text := 'eyJVc2VySUQiOiJhYzQ3YjI2Yi03MTg4LTQ4ZjUtYTIwMS00ZGE2MTQ0ZmEwZDAiLCJQYXNzd29yZCI6IjJlYjA4YzRlZjg2YjRkNjI5YTg4ODhkYjFmNzU2OTczIn0=';
    
    -- 【本番用】本番環境のEdge Function URL
    target_url text := 'https://ljgvqdcailabzuutaeha.supabase.co/functions/v1/gemini_v2';
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
END;$$;
