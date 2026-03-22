-- 1. match_record テーブルに個別の増減値、対戦時トロフィー、アンダードッグ判定（フラグ一本）を保存するカラムを追加
ALTER TABLE "public"."match_record" ADD COLUMN IF NOT EXISTS "player1_move_trophy" integer;
ALTER TABLE "public"."match_record" ADD COLUMN IF NOT EXISTS "player2_move_trophy" integer;
ALTER TABLE "public"."match_record" ADD COLUMN IF NOT EXISTS "player1_trophy" integer; -- 対戦相手との比較用
ALTER TABLE "public"."match_record" ADD COLUMN IF NOT EXISTS "player2_trophy" integer;
ALTER TABLE "public"."match_record" ADD COLUMN IF NOT EXISTS "is_underdog" boolean DEFAULT false;

-- 2. ブロスタ式トロフィー計算関数の作成（アンダードッグ補正込み）
CREATE OR REPLACE FUNCTION "public"."calculate_brawl_trophy_change"(
    p_my_trophy integer, 
    p_opponent_trophy integer, 
    p_is_win boolean
) RETURNS integer AS $$
DECLARE
    v_base_change integer;
    v_is_underdog boolean;
    v_underdog_bonus CONSTANT integer := 4;
BEGIN
    -- アンダードッグ判定：相手の方が200以上高い場合
    v_is_underdog := (p_opponent_trophy - p_my_trophy) >= 200;

    IF p_is_win THEN
        -- 勝利時のテーブル (ティアに応じて減少)
        IF p_my_trophy < 500 THEN v_base_change := 8;
        ELSIF p_my_trophy < 600 THEN v_base_change := 7;
        ELSIF p_my_trophy < 700 THEN v_base_change := 6;
        ELSIF p_my_trophy < 800 THEN v_base_change := 5;
        ELSIF p_my_trophy < 900 THEN v_base_change := 4;
        ELSE v_base_change := 3;
        END IF;
        
        RETURN CASE WHEN v_is_underdog THEN v_base_change + v_underdog_bonus ELSE v_base_change END;
    ELSE
        -- 敗北時のテーブル
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

        -- アンダードッグなら敗北ペナルティを軽減（-8 + 4 = -4 など）
        IF v_is_underdog THEN
            RETURN LEAST(0, v_base_change + v_underdog_bonus);
        ELSE
            RETURN v_base_change;
        END IF;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- 3. 判定トリガー関数の再定義
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

    -- アンダードッグ判定 (どちらかのレート差が 200 以上 / 片方が格下で片方が格上)
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
      v_p1_move := 16;
      v_p2_move := 16;
      UPDATE users SET trophy = trophy + 16 WHERE id = NEW.player1_id;
      UPDATE users SET trophy = trophy + 16 WHERE id = NEW.player2_id;
    END IF;
  END IF;

  -- 履歴への挿入
  INSERT INTO match_record (
    roomid, player1_id, player2_id, theme, winner, 
    player1_move_trophy, player2_move_trophy, 
    player1_trophy, player2_trophy,
    is_underdog,
    move_trophy, result
  ) VALUES (
    NEW.id, NEW.player1_id, NEW.player2_id, NEW.current_theme, 
    CASE WHEN NEW.winner = 'A' THEN NEW.player1_id WHEN NEW.winner = 'B' THEN NEW.player2_id ELSE NULL END, 
    v_p1_move, v_p2_move, 
    v_p1_trophy, v_p2_trophy,
    v_is_underdog_match,
    v_p1_move, NEW.reason
  );

  RETURN NEW;
END;
$$;
