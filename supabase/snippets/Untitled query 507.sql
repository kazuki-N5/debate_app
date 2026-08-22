-- ========== テストデータ クリーンアップ ==========

-- 1. レスバの応募 → レスバ本体（依存関係の順）
DELETE FROM battle_invite_applications;
DELETE FROM battle_invites;

-- 2. 試合（これを消すと「対戦中」判定がリセットされる）
DELETE FROM rooms_v2;

-- 3. 通知（レスバ関連の通知も消える）
DELETE FROM notifications;

-- 4. 掲示板（コメント → ポストの順。いいねも）
DELETE FROM bbs_comment_likes;
DELETE FROM bbs_likes;
DELETE FROM bbs_comments;
DELETE FROM bbs_posts;

-- 5. DM（メッセージ → メンバー → ルームの順）
DELETE FROM dm_messages;
DELETE FROM dm_room_members;
DELETE FROM dm_rooms;

-- 6. 必要なら（試合履歴・チャット履歴）
-- DELETE FROM match_record;
-- DELETE FROM messages;
-- DELETE FROM notification_logs;