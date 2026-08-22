-- ============================================================
-- Migration: fix_is_user_in_battle
-- 「対戦中」判定の修正
--  従来: (player1=自分 OR player2=自分) AND winner IS NULL
--    → 対戦募集タブで立てた「募集中ルーム」(player2未定) も
--      対戦中と誤判定され、レスバ送信が全てブロックされる問題
--  修正: 実際に対戦が始まっている (player2 確定) かつ未終了のみ対戦中とする
-- ============================================================

CREATE OR REPLACE FUNCTION public.is_user_in_battle(p_user_id uuid)
  RETURNS boolean
  LANGUAGE sql
  STABLE
  AS $function$
  SELECT EXISTS (
    SELECT 1 FROM rooms_v2
    WHERE (player1_id = p_user_id OR player2_id = p_user_id)
      AND player2_id IS NOT NULL  -- 相手が確定 = 実際に対戦が始まっている
      AND winner IS NULL          -- まだ結果が出ていない
  );
$function$;
