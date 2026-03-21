-- 1. 古いインデックスの削除（resultカラムが存在しないためエラーの原因になります）
DROP INDEX IF EXISTS "public"."idx_rooms_result_updated_at";

-- 2. 重複判定防止トリガーの修正
-- 古いトリガーを削除
DROP TRIGGER IF EXISTS "prevent_result_update_trigger" ON "public"."rooms";

-- 関数を新しいwinner/reasonカラム用に更新
CREATE OR REPLACE FUNCTION "public"."prevent_result_update"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  -- すでに判定(winner)がセットされている場合、更新を禁止する
  IF OLD.winner IS NOT NULL AND NEW.winner IS DISTINCT FROM OLD.winner THEN
    RAISE EXCEPTION 'Judgment results cannot be updated once set.';
  END IF;
  RETURN NEW;
END;
$$;

-- 新しいトリガーを登録
CREATE TRIGGER "prevent_result_update_trigger"
    BEFORE UPDATE ON "public"."rooms"
    FOR EACH ROW
    EXECUTE FUNCTION "public"."prevent_result_update"();

-- 3. (念のため) 既存の履歴取得関数の修正
-- もし古い形式の関数が残っている場合、エラーを防ぐために再定義します
CREATE OR REPLACE FUNCTION "public"."get_recent_match_history"() RETURNS TABLE("roomid" "uuid", "player1_id" "uuid", "player2_id" "uuid", "theme" "text", "player1_choice" "text", "player2_choice" "text", "winner" "uuid", "move_trophy" integer, "result" "text", "created_at" timestamp with time zone)
    LANGUAGE "sql" STABLE
    AS $$
  SELECT
    mr.roomid,
    mr.player1_id,
    mr.player2_id,
    mr.theme,
    mr.player1_choice,
    mr.player2_choice,
    mr.winner,
    mr.move_trophy,
    mr.result, -- 履歴テーブルのresultカラム（ここではそのまま）
    mr.created_at
  FROM public.match_record mr
  WHERE mr.created_at >= (now() - interval '7 days')
  ORDER BY mr.created_at DESC
  LIMIT 30;
$$;
