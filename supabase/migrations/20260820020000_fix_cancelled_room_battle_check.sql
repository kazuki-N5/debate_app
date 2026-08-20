-- ============================================================
-- Migration: fix_cancelled_room_battle_check
-- キャンセル済みルーム（player1_go / player2_go = false）を
-- 「対戦中」判定から除外し、解決時に match_record の主キー重複で
-- 例外が発生する問題を修正する
--
-- 背景:
--   handle_cancellation_v2（キャンセル）は部屋を削除せず winner も入れない
--   （相手側アプリ保護・キャンセルは勝利ではない、という設計）。
--   そのため rooms_v2 は winner NULL のまま残り、
--   match_record にはキャンセル記録（cancel=true）が既に存在する。
--   解決型 is_user_in_battle がこの部屋を再解決しようとすると
--   v2_process_game_result が match_record を再INSERTし、
--   主キー重複（duplicate key）で例外 → レスバ作成RPCが全て失敗していた。
--
-- 対処:
--   1. キャンセル済みの判別は player1_go / player2_go = false を使う
--      （false を書くのは handle_cancellation_v2 のみ・クライアントも
--       Matching.dart で同じ規約でキャンセル検知している）
--   2. is_user_in_battle / 放置ルーム終了 の対象からキャンセル済みを除外
--   3. v2_process_game_result の match_record INSERT を冪等化（ON CONFLICT）
-- ============================================================

-- ---------- 1. is_user_in_battle: キャンセル済みルームを対戦中・解決対象から除外 ----------
CREATE OR REPLACE FUNCTION public.is_user_in_battle(p_user_id uuid)
  RETURNS boolean
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
BEGIN
  -- 自分の進行中ルーム（player2確定・winner未確定・キャンセル済みでない）を
  -- すべて「負け（相手の勝ち）」として確定
  UPDATE rooms_v2
     SET winner = CASE WHEN player1_id = p_user_id THEN 'B' ELSE 'A' END,
         reason = '前の試合を放棄して新規参加',
         updated_at = now()
   WHERE (player1_id = p_user_id OR player2_id = p_user_id)
     AND player2_id IS NOT NULL
     AND winner IS NULL
     AND player1_go IS DISTINCT FROM false -- キャンセル済みは対象外
     AND player2_go IS DISTINCT FROM false; -- キャンセル済みは対象外

  -- 解決したのでブロックしない（常に許可）
  RETURN false;
END;
$function$;

-- ---------- 2. 放置ルームの自動終了（cron）: キャンセル済みは引き分けにしない ----------
CREATE OR REPLACE FUNCTION public.finalize_stale_rooms()
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  AS $function$
BEGIN
  -- 進行中（player2確定・winner未確定・キャンセル済みでない）で
  -- 3分以上更新が無いルームを引き分け終了
  UPDATE rooms_v2
     SET winner = 'C', reason = '未選択・放置のため終了', updated_at = now()
   WHERE winner IS NULL AND player2_id IS NOT NULL
     AND player1_go IS DISTINCT FROM false
     AND player2_go IS DISTINCT FROM false
     AND updated_at <= now() - INTERVAL '3 minutes';
END;
$function$;

SELECT cron.schedule(
  'finalize-stale-rooms',
  '*/5 * * * *',
  $$SELECT public.finalize_stale_rooms()$$
);

-- ---------- 3. 起動時即終了: キャンセル済みは対象外 ----------
CREATE OR REPLACE FUNCTION public.finalize_user_stale_room(p_user_id uuid)
  RETURNS json
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_room_id uuid;
BEGIN
  UPDATE rooms_v2
     SET winner = 'C', reason = '放置のため終了', updated_at = now()
   WHERE winner IS NULL AND player2_id IS NOT NULL
     AND (player1_id = p_user_id OR player2_id = p_user_id)
     AND player1_go IS DISTINCT FROM false
     AND player2_go IS DISTINCT FROM false
     AND updated_at <= now() - INTERVAL '3 minutes'
   RETURNING id INTO v_room_id;

  IF v_room_id IS NULL THEN
    RETURN json_build_object('success', false, 'room_id', NULL);
  END IF;
  RETURN json_build_object('success', true, 'room_id', v_room_id);
END;
$function$;

-- ---------- 4. 保険: v2_process_game_result の match_record 書き込みを冪等化 ----------
-- どの経路でも二重解決で主キー重複の例外にならないようにする
-- （cancel フラグは上書きしない＝キャンセル記録を消さない）
CREATE OR REPLACE FUNCTION public.v2_process_game_result()
  RETURNS trigger
  LANGUAGE plpgsql
  AS $function$
DECLARE
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

  -- match_record に記録（既に記録がある場合は上書き＝冪等）
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
  )
  ON CONFLICT (roomid) DO UPDATE SET
    player1_id = EXCLUDED.player1_id,
    player2_id = EXCLUDED.player2_id,
    theme = EXCLUDED.theme,
    winner = EXCLUDED.winner,
    player1_move_trophy = EXCLUDED.player1_move_trophy,
    player2_move_trophy = EXCLUDED.player2_move_trophy,
    is_underdog = EXCLUDED.is_underdog,
    move_trophy = EXCLUDED.move_trophy,
    result = EXCLUDED.result,
    player1_choice = EXCLUDED.player1_choice,
    player2_choice = EXCLUDED.player2_choice,
    scores = EXCLUDED.scores;
    -- cancel は上書きしない（キャンセル記録を保持）
  RETURN NEW;
END;
$function$;
