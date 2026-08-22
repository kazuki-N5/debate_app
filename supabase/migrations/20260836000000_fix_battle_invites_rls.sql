-- ==============================================================================
-- battle_invites および battle_invite_applications の RLS ポリシー修正
-- ホストがリアルタイムで応募（battle_invite_applications）の通知を受け取れるようにする
-- ==============================================================================

-- 1. battle_invites の SELECT ポリシー
-- 公開型レスバ（post / comment / open_chat / recruit）は誰でも閲覧可能
-- DM型レスバは当事者（送信者または回答者）のみ閲覧可能
DROP POLICY IF EXISTS "battle_invites_select" ON public.battle_invites;

CREATE POLICY "battle_invites_select" ON public.battle_invites
FOR SELECT TO public
USING (
  attach_type IN ('post', 'comment', 'open_chat', 'recruit')
  OR sender_id = auth.uid()
  OR responder_id = auth.uid()
);

-- 2. battle_invite_applications の SELECT ポリシー
-- 応募者本人、またはレスバのホスト（battle_invites の sender_id）が閲覧可能
DROP POLICY IF EXISTS "battle_invite_applications_select" ON public.battle_invite_applications;

CREATE POLICY "battle_invite_applications_select" ON public.battle_invite_applications
FOR SELECT TO public
USING (
  applicant_id = auth.uid()
  OR EXISTS (
    SELECT 1 FROM public.battle_invites b
    WHERE b.id = battle_invite_applications.invite_id
      AND b.sender_id = auth.uid()
  )
);
