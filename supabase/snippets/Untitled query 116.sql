-- ============================================================
-- レスバ関連データ 全消去（テスト用・何度でも実行OK）
-- ============================================================

-- 1. レスバの応募（依存順: 先に応募）
DELETE FROM battle_invite_applications;

-- 2. レスバ本体
DELETE FROM battle_invites;

-- 3. レスバ関連の通知
DELETE FROM notifications
WHERE type IN ('resba_invite', 'resba_accepted', 'resba_declined');

-- 4. 試合ルーム（対戦中のブロックを全解除）
--    ※ rooms_v2 には通常の対戦履歴も混ざっているため、
--      レスバの試合（is_bbs = true）だけ消します
DELETE FROM rooms_v2 WHERE is_bbs = true;

-- 5. （おまけ）テストで作った掲示板ポスト・コメント・いいねも消す
--    ※ 本番データが混ざっている場合はコメントアウト推奨
DELETE FROM bbs_comment_likes;
DELETE FROM bbs_likes;
DELETE FROM bbs_comments;
DELETE FROM bbs_posts;

-- 6. （おまけ）DM関連も消す
--    ※ 本番DMが混ざっている場合はコメントアウト推奨
DELETE FROM dm_messages;
DELETE FROM dm_room_members;
DELETE FROM dm_rooms;