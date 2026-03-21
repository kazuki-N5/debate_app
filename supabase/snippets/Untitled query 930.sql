-- 1. カラムの入れ替え
ALTER TABLE "public"."rooms" ADD COLUMN IF NOT EXISTS "winner" char(1);
ALTER TABLE "public"."rooms" ADD COLUMN IF NOT EXISTS "reason" text;
ALTER TABLE "public"."rooms" DROP COLUMN IF EXISTS "result"; -- ここで削除されます

-- 2. 判定関数の刷新
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

-- 3. トリガーの再登録
-- reason カラムが書き込まれたら発動するようにします
DROP TRIGGER IF EXISTS "process_game_result" ON "public"."rooms";
CREATE TRIGGER "process_game_result"
    BEFORE UPDATE OF "reason" ON "public"."rooms"
    FOR EACH ROW
    WHEN (OLD.reason IS NULL AND NEW.reason IS NOT NULL)
    EXECUTE FUNCTION "public"."process_game_result"();
