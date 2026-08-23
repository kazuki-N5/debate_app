-- リプライ機能用カラムの追加マイグレーション
-- 1. 対戦チャット (messages)
ALTER TABLE messages 
  ADD COLUMN IF NOT EXISTS reply_to_id UUID REFERENCES messages(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS reply_to_content TEXT,
  ADD COLUMN IF NOT EXISTS reply_to_user_name TEXT;

-- 2. オープンチャット (open_chat_messages)
ALTER TABLE open_chat_messages 
  ADD COLUMN IF NOT EXISTS reply_to_id UUID REFERENCES open_chat_messages(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS reply_to_content TEXT,
  ADD COLUMN IF NOT EXISTS reply_to_user_name TEXT;

-- 3. DM (dm_messages)
ALTER TABLE dm_messages 
  ADD COLUMN IF NOT EXISTS reply_to_id UUID REFERENCES dm_messages(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS reply_to_content TEXT,
  ADD COLUMN IF NOT EXISTS reply_to_user_name TEXT;

-- インデックスの作成
CREATE INDEX IF NOT EXISTS idx_messages_reply_to_id ON messages(reply_to_id);
CREATE INDEX IF NOT EXISTS idx_open_chat_messages_reply_to_id ON open_chat_messages(reply_to_id);
CREATE INDEX IF NOT EXISTS idx_dm_messages_reply_to_id ON dm_messages(reply_to_id);
