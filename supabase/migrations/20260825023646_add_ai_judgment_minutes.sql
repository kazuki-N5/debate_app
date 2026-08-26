-- =============================================================================
-- add_ai_judgment_minutes
-- rooms_v2 に「AI判定待ち分数」カラムを追加し、バトル種別ごとに判定時間を
-- トリガーが自動決定できるようにする。target_url は本番URL。
-- =============================================================================

-- 1) rooms_v2 に判定分数カラムを追加（additive）-------------------------------
ALTER TABLE public.rooms_v2
  ADD COLUMN ai_judgment_minutes integer NOT NULL DEFAULT 3;

-- 2) handle_room_updates_v2 を再定義 -------------------------------------------
--    - INSERT 時に is_bbs=TRUE なら ai_judgment_minutes := 10（レスバ既定）
--    - QStash 遅延を「ai_judgment_minutes 分」から動的生成する
--    - target_url は本番URL
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
    
    -- 【本番】エッジ関数 gemini_v2 のURL
    target_url text := 'https://ljgvqdcailabzuutaeha.supabase.co/functions/v1/gemini_v2';
    qstash_publish_url text := 'https://qstash-us-east-1.upstash.io/v2/publish/' || target_url;
BEGIN
    IF TG_OP = 'INSERT' THEN
        -- レスバ/BBSバトル(is_bbs=true)は既定10分に自動セット
        IF NEW.is_bbs IS TRUE AND NEW.ai_judgment_minutes <= 3 THEN
            NEW.ai_judgment_minutes := 10;
        END IF;
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
                headers := jsonb_build_object(
                    'Authorization', 'Bearer ' || qstash_token,
                    'Content-Type', 'application/json',
                    'Upstash-Delay', (GREATEST(COALESCE(NEW.ai_judgment_minutes, 3), 1))::text || 'm'
                ),
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

-- 3) join_room_v2_v4：新アプリ用・通常マッチを10分で作成 -----------------------
--     join_room_v2 と同一ロジック。作成時のみ ai_judgment_minutes=10 をセット。
--     参加時は相手の設定を尊重（作成者の値は変更しない）。
CREATE OR REPLACE FUNCTION public.join_room_v2_v4(
    p_user_id uuid,
    p_room_password text,
    p_room_theme text,
    p_room_choice1 text,
    p_room_choice2 text
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  target_room_id UUID; room_data JSONB; v_theme_provided BOOLEAN;
BEGIN
    v_theme_provided := (
        p_room_theme IS NOT NULL AND p_room_theme != ''
        AND p_room_choice1 IS NOT NULL AND p_room_choice1 != ''
        AND p_room_choice2 IS NOT NULL AND p_room_choice2 != ''
    );
    IF p_room_password IS NOT NULL THEN
      SELECT id INTO target_room_id FROM rooms_v2
       WHERE player2_id IS NULL AND password = p_room_password AND player1_id != p_user_id
       LIMIT 1 FOR UPDATE SKIP LOCKED;
    ELSE
      SELECT id INTO target_room_id FROM rooms_v2
       WHERE player2_id IS NULL AND password IS NULL AND player1_id != p_user_id
       LIMIT 1 FOR UPDATE SKIP LOCKED;
    END IF;
    IF target_room_id IS NOT NULL THEN
      UPDATE rooms_v2 SET
          player2_id = p_user_id,
          is_matched = true,
          updated_at = NOW(),
          current_theme = CASE WHEN theme_s = false AND v_theme_provided = true THEN p_room_theme ELSE current_theme END,
          current_choice1 = CASE WHEN theme_s = false AND v_theme_provided = true THEN p_room_choice1 ELSE current_choice1 END,
          current_choice2 = CASE WHEN theme_s = false AND v_theme_provided = true THEN p_room_choice2 ELSE current_choice2 END,
          theme_s = CASE WHEN theme_s = false AND v_theme_provided = true THEN true ELSE theme_s END
      WHERE id = target_room_id;
      SELECT to_jsonb(r) INTO room_data FROM rooms_v2 r WHERE r.id = target_room_id;
      RETURN jsonb_build_object('success', true, 'action', 'joined', 'room', room_data);
    ELSE
      INSERT INTO rooms_v2 (
          player1_id, password, current_theme, current_choice1, current_choice2,
          theme_s, ai_judgment_minutes
      )
      VALUES (
          p_user_id, p_room_password, p_room_theme, p_room_choice1, p_room_choice2,
          v_theme_provided, 10
      )
      RETURNING to_jsonb(rooms_v2.*) INTO room_data;
      RETURN jsonb_build_object('success', true, 'action', 'created', 'room', room_data);
    END IF;
END;
$function$;

-- 4) GRANT（新RPCを Data API から呼べるように）--------------------------------
GRANT ALL ON FUNCTION public.join_room_v2_v4(uuid, text, text, text, text) TO anon;
GRANT ALL ON FUNCTION public.join_room_v2_v4(uuid, text, text, text, text) TO authenticated;
GRANT ALL ON FUNCTION public.join_room_v2_v4(uuid, text, text, text, text) TO service_role;
