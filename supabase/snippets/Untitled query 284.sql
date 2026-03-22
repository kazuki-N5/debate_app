-- Alter match_record to remove legacy trophy columns
ALTER TABLE "public"."match_record" DROP COLUMN IF EXISTS "player1_trophy";
ALTER TABLE "public"."match_record" DROP COLUMN IF EXISTS "player2_trophy";

-- Update process_game_result function to stop inserting these values
CREATE OR REPLACE FUNCTION "public"."process_game_result"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  v_p1_trophy integer;
  v_p2_trophy integer;
  v_p1_move integer := 0;
  v_p2_move integer := 0;
  v_is_underdog_match boolean := false;
  v_is_ranked_match BOOLEAN;
BEGIN
  v_is_ranked_match := (NEW.password IS NULL OR NEW.password = '');
  NEW.updated_at = now();

  IF v_is_ranked_match THEN
    SELECT trophy INTO v_p1_trophy FROM users WHERE id = NEW.player1_id;
    SELECT trophy INTO v_p2_trophy FROM users WHERE id = NEW.player2_id;

    -- アンダードッグ判定 (レート差が 200 以上)
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
    ELSE
      -- 引き分け等の特殊処理
      v_p1_move := 16;
      v_p2_move := 16;
      UPDATE users SET trophy = trophy + 16 WHERE id = NEW.player1_id;
      UPDATE users SET trophy = trophy + 16 WHERE id = NEW.player2_id;
    END IF;
  END IF;

  -- 履歴への挿入 (player1_trophy, player2_trophy を除外)
  INSERT INTO match_record (
    roomid, player1_id, player2_id, theme, winner, 
    player1_move_trophy, player2_move_trophy, 
    is_underdog,
    move_trophy, result
  ) VALUES (
    NEW.id, NEW.player1_id, NEW.player2_id, NEW.current_theme, 
    CASE WHEN NEW.winner = 'A' THEN NEW.player1_id WHEN NEW.winner = 'B' THEN NEW.player2_id ELSE NULL END, 
    v_p1_move, v_p2_move, 
    v_is_underdog_match,
    v_p1_move, NEW.reason
  );

  RETURN NEW;
END;
$$;
