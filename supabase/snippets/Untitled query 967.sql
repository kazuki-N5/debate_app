-- ============================================================
-- Migration: resolve_old_battle
-- 「待ち時間でブロックを解除」方式を廃止し、
-- 「新しい試合に関わる操作をした瞬間に、前の試合を負け（相手勝ち）として確定」する方式に変更
--
--  is_user_in_battle を「解決型」に変更:
--    自分の進行中ルーム（player2確定・winner未確定）があれば、
--    すべて「前の試合を放棄して新規参加」として相手勝ち（winner設定）で確定し、
--    常に false（ブロックなし）を返す。
--    これによりユーザーは待ち時間ゼロで新しい試合に参加できる。
-- ============================================================

CREATE OR REPLACE FUNCTION public.is_user_in_battle(p_user_id uuid)
  RETURNS boolean
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
BEGIN
  -- 自分の進行中ルーム（player2確定・winner未確定）をすべて「負け（相手の勝ち）」として確定
  UPDATE rooms_v2
     SET winner = CASE WHEN player1_id = p_user_id THEN 'B' ELSE 'A' END,
         reason = '前の試合を放棄して新規参加',
         updated_at = now()
   WHERE (player1_id = p_user_id OR player2_id = p_user_id)
     AND player2_id IS NOT NULL
     AND winner IS NULL;

  -- 解決したのでブロックしない（常に許可）
  RETURN false;
END;
$function$;

-- フロント（ランダムマッチ前の解決呼び出し）からも RPC として呼べるように
GRANT ALL ON FUNCTION public.is_user_in_battle(uuid) TO anon;
GRANT ALL ON FUNCTION public.is_user_in_battle(uuid) TO authenticated;
GRANT ALL ON FUNCTION public.is_user_in_battle(uuid) TO service_role;
