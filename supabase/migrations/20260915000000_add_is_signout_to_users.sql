-- users テーブルにログアウトフラグを追加
-- ログアウト時に true になり、将来「死んでいるアカウント」の一括削除に使用する
ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS is_signout boolean NOT NULL DEFAULT false;
