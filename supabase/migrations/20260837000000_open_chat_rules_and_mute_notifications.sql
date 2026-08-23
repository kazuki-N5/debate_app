-- ==============================================================================
-- マイグレーション: オプチャのルール機能 ＆ ルーム・DM個別通知ON/OFF (ミュート)
-- ==============================================================================

-- 1. open_chat_rooms テーブルに rules カラムを追加
ALTER TABLE public.open_chat_rooms 
  ADD COLUMN IF NOT EXISTS rules TEXT;

-- 2. open_chat_members テーブルに is_muted カラムを追加
ALTER TABLE public.open_chat_members 
  ADD COLUMN IF NOT EXISTS is_muted BOOLEAN DEFAULT false NOT NULL;

-- 3. dm_room_members テーブルに is_muted カラムを追加
ALTER TABLE public.dm_room_members 
  ADD COLUMN IF NOT EXISTS is_muted BOOLEAN DEFAULT false NOT NULL;

-- 4. RLSポリシーの調整
-- 自分のメンバー情報の is_muted を更新可能にする (open_chat_members)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'open_chat_members' AND policyname = '自分のメンバー情報を更新可能'
  ) THEN
    CREATE POLICY "自分のメンバー情報を更新可能" 
      ON public.open_chat_members 
      FOR UPDATE 
      USING (auth.uid() = user_id)
      WITH CHECK (auth.uid() = user_id);
  END IF;
END $$;

-- 自分のDMメンバー情報の is_muted を更新可能にする (dm_room_members)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'dm_room_members' AND policyname = '自分のDMメンバー情報を更新可能'
  ) THEN
    CREATE POLICY "自分のDMメンバー情報を更新可能" 
      ON public.dm_room_members 
      FOR UPDATE 
      USING (auth.uid() = user_id)
      WITH CHECK (auth.uid() = user_id);
  END IF;
END $$;
