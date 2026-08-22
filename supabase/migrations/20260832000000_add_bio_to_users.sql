-- users テーブルに自己紹介 (bio) カラムを追加
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS bio text;

COMMENT ON COLUMN public.users.bio IS 'ユーザーの自己紹介文 (160文字以内)';
