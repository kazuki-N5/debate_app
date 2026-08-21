-- ============================================================
-- 過去の放置部屋クリーンアップ ＆ レスバ状態判定の強化
-- ============================================================

-- ---------- 1. is_user_in_battle の改善 ----------
-- ユーザーが新しい試合やレスバを始める際に、過去の未終了部屋をすべて適切に解決する
CREATE OR REPLACE FUNCTION public.is_user_in_battle(p_user_id uuid)
  RETURNS boolean
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
BEGIN
  -- A. キャンセル済みの部屋（player1_go/player2_go = false）や、相手不在の待機部屋（player2_id IS NULL）
  --    → 勝敗はつけず「キャンセル終了（winner = 'C'）」として片付ける
  UPDATE rooms_v2
     SET winner = 'C',
         reason = COALESCE(reason, 'マッチングキャンセルまたは待機終了'),
         updated_at = now()
   WHERE (player1_id = p_user_id OR player2_id = p_user_id)
     AND winner IS NULL
     AND (
       player2_id IS NULL
       OR player1_go = false
       OR player2_go = false
     );

  -- B. 実際に試合が開始されて進行中だった部屋（双方がキャンセルしていない）
  --    → 「試合放棄」として自分が負け（相手の勝ち）にして解決する（複数部屋あってもすべて一括処理）
  UPDATE rooms_v2
     SET winner = CASE WHEN player1_id = p_user_id THEN 'B' ELSE 'A' END,
         reason = '前の試合を放棄して新規参加',
         updated_at = now()
   WHERE (player1_id = p_user_id OR player2_id = p_user_id)
     AND player2_id IS NOT NULL
     AND winner IS NULL
     AND player1_go IS DISTINCT FROM false
     AND player2_go IS DISTINCT FROM false;

  -- 解決完了したのでブロックしない
  RETURN false;
END;
$function$;

GRANT ALL ON FUNCTION public.is_user_in_battle(uuid) TO anon;
GRANT ALL ON FUNCTION public.is_user_in_battle(uuid) TO authenticated;
GRANT ALL ON FUNCTION public.is_user_in_battle(uuid) TO service_role;


-- ---------- 2. get_my_resba_status の改善 ----------
-- 対戦中であっても、応募件数・募集件数・招待件数を必ず計算して返す
CREATE OR REPLACE FUNCTION public.get_my_resba_status(p_user_id uuid)
  RETURNS json
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_state          text;
  v_pending_sender int := 0;
  v_pending_app    int := 0;
  v_pending_target int := 0;
  v_battle_room_id uuid;
BEGIN
  -- 1. レスバの待機件数を常に正確にカウント
  SELECT count(*) INTO v_pending_sender FROM battle_invites
   WHERE sender_id = p_user_id AND status = 'pending';

  SELECT count(*) INTO v_pending_target FROM battle_invites
   WHERE target_user_id = p_user_id AND status = 'pending';

  SELECT count(*) INTO v_pending_app FROM battle_invite_applications
   WHERE applicant_id = p_user_id AND status = 'pending';

  -- 2. 本当に進行中の試合があるか厳格にチェック（キャンセル済み・古い放置部屋は除外）
  SELECT id INTO v_battle_room_id FROM rooms_v2
   WHERE (player1_id = p_user_id OR player2_id = p_user_id)
     AND winner IS NULL
     AND player2_id IS NOT NULL
     AND player1_go IS DISTINCT FROM false
     AND player2_go IS DISTINCT FROM false
     AND updated_at >= now() - INTERVAL '5 minutes'
   ORDER BY created_at DESC
   LIMIT 1;

  -- 3. 状態ステータスの決定
  IF v_battle_room_id IS NOT NULL THEN
    v_state := 'battle';
  ELSIF v_pending_sender > 0 THEN
    v_state := 'proposing';
  ELSIF v_pending_app > 0 THEN
    v_state := 'applying';
  ELSIF v_pending_target > 0 THEN
    v_state := 'invited';
  ELSE
    v_state := 'free';
  END IF;

  -- 4. 対戦中（battle）であっても、応募件数（pending_application_count）などのカウントを必ず含めて返却！
  RETURN json_build_object(
    'state', v_state,
    'battle_room_id', v_battle_room_id,
    'pending_sender_count', v_pending_sender,
    'pending_application_count', v_pending_app,
    'pending_target_count', v_pending_target
  );
END;
$function$;

GRANT ALL ON FUNCTION public.get_my_resba_status(uuid) TO anon;
GRANT ALL ON FUNCTION public.get_my_resba_status(uuid) TO authenticated;
GRANT ALL ON FUNCTION public.get_my_resba_status(uuid) TO service_role;


-- ---------- 3. 既存の放置ルーム（winner IS NULL）の一括クリーンアップ ----------
UPDATE rooms_v2
   SET winner = 'C',
       reason = '過去の放置ルーム自動クリーンアップ',
       updated_at = now()
 WHERE winner IS NULL
   AND (
     player2_id IS NULL
     OR player1_go = false
     OR player2_go = false
     OR updated_at <= now() - INTERVAL '5 minutes'
   );
