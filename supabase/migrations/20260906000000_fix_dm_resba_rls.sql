-- ============================================================
-- Migration: fix_dm_resba_rls
-- DMのレスバ（battle_invites の attach_type='dm'）が相手側に
-- リアルタイムで表示されない問題の修正
--
-- 原因:
--   battle_invites_select の SELECT RLS が DM型を
--     sender_id = auth.uid() OR responder_id = auth.uid()
--   の2条件だけで許可しており、募集型（target_user_id 廃止・
--   responder_id は未確定）のDMレスバは送信者以外のDMメンバー
--   （相手）から行が見えない。
--
--   Supabase Realtime (Postgres Changes) は配信時に RLS を検査する
--   ため、相手にはイベントが届かず、DmResbaNotifier の fetch() が
--   走らず画面が更新されない（戻って入り直すと SECURITY DEFINER の
--   get_dm_resbas が全件返すため表示される）。
--
-- 修正:
--   DM型は「添付先 dm_messages のルームに自分が参加している」
--   （dm_messages の RLS と同じ is_dm_room_member 判定）場合に
--   閲覧可能とする。DMルームは2人制なので実質当事者2名のみ。
-- ============================================================

DROP POLICY IF EXISTS "battle_invites_select" ON public.battle_invites;

CREATE POLICY "battle_invites_select" ON public.battle_invites
FOR SELECT TO public
USING (
  attach_type IN ('post', 'comment', 'open_chat', 'recruit')
  OR sender_id = auth.uid()
  OR responder_id = auth.uid()
  OR (
    attach_type = 'dm'
    AND EXISTS (
      SELECT 1 FROM public.dm_messages m
      WHERE m.id = battle_invites.attach_id
        AND public.is_dm_room_member(m.room_id)
    )
  )
);

-- 応募（battle_invite_applications）の RLS はホスト側 EXISTS が
-- battle_invites の sender_id 判定に依存しており、DM型でもホストは
-- 見えるため変更不要。相手側は applicant_id = auth.uid() で見える。