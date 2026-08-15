-- rooms_v2 テーブルに scores カラムを追加
ALTER TABLE "public"."rooms_v2" ADD COLUMN IF NOT EXISTS "scores" JSONB;

-- match_record テーブルにも scores カラムを追加（過去ログ・履歴保存用）
ALTER TABLE "public"."match_record" ADD COLUMN IF NOT EXISTS "scores" JSONB;

-- トリガー関数の更新 (v2_process_game_result で match_record に scores も引き渡す)
CREATE OR REPLACE FUNCTION "public"."v2_process_game_result"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$DECLARE
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
END;$$;
