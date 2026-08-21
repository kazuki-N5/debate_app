-- ==============================================================================
-- 20260826000000_performance_optimization_indexes_rls.sql
-- パフォーマンス最適化: 複合インデックスの作成 ＆ RLSポリシーの高速化
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. 頻出検索・ソート用 複合インデックスの追加
-- ------------------------------------------------------------------------------

-- 1-1. 試合履歴 (match_record): プレイヤーID + 作成日時降順
CREATE INDEX IF NOT EXISTS idx_match_record_p1_created
  ON public.match_record (player1_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_match_record_p2_created
  ON public.match_record (player2_id, created_at DESC);

-- 1-2. DMメッセージ (dm_messages): ルームID + 作成日時降順
CREATE INDEX IF NOT EXISTS idx_dm_messages_room_created
  ON public.dm_messages (room_id, created_at DESC);

-- 1-3. オープンチャットメッセージ (open_chat_messages): ルームID + 作成日時降順
CREATE INDEX IF NOT EXISTS idx_open_chat_messages_room_created
  ON public.open_chat_messages (room_id, created_at DESC);

-- 1-4. 対戦中メッセージ (messages): ルームID + 作成日時降順
CREATE INDEX IF NOT EXISTS idx_messages_room_created
  ON public.messages (room_id, created_at DESC);

-- 1-5. 掲示板返信 (bbs_comments): ポストID + 作成日時昇順
CREATE INDEX IF NOT EXISTS idx_bbs_comments_post_created
  ON public.bbs_comments (post_id, created_at ASC);

-- 1-6. 掲示板いいね (bbs_likes): ポストID + ユーザーID
CREATE INDEX IF NOT EXISTS idx_bbs_likes_post_user
  ON public.bbs_likes (post_id, user_id);

-- 1-7. レスバ対戦招待 (battle_invites): ターゲットユーザーID / 送信者ID + 作成日時
CREATE INDEX IF NOT EXISTS idx_battle_invites_target_created
  ON public.battle_invites (target_user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_battle_invites_sender_created
  ON public.battle_invites (sender_id, created_at DESC);

-- ------------------------------------------------------------------------------
-- 2. RLS (Row Level Security) ポリシーの最適化
-- auth.uid() を (SELECT auth.uid()) にラップして毎行評価からクエリキャッシュ評価に変更
-- ------------------------------------------------------------------------------

-- users テーブルの更新ポリシー
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'users' AND policyname = 'Users can update their own data'
  ) THEN
    DROP POLICY "Users can update their own data" ON public.users;
    CREATE POLICY "Users can update their own data" ON public.users 
      FOR UPDATE USING (id = (SELECT auth.uid()));
  END IF;
END $$;

-- notification_settings テーブルのポリシー
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'notification_settings' AND policyname = 'Users can update their own notification settings'
  ) THEN
    DROP POLICY "Users can update their own notification settings" ON public.notification_settings;
    CREATE POLICY "Users can update their own notification settings" ON public.notification_settings 
      FOR ALL USING (user_id = (SELECT auth.uid()));
  END IF;
END $$;
