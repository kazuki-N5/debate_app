-- ============================================================
-- Migration: ensure_resba_realtime
-- battle_invites / battle_invite_applications を supabase_realtime
-- の publication に確実に登録する（冪等）
--
-- 背景: 送信者側アプリは Realtime（postgres_changes）で
--   battle_invites の status 変化（accepted）を購読してバトル画面へ遷移する。
--   テーブルが publication に未登録だとイベントが配信されない。
-- ============================================================

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'battle_invites'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.battle_invites;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'battle_invite_applications'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.battle_invite_applications;
  END IF;
END $$;
