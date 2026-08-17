-- ============================================================
-- メッセージタブ用 SQL (v2)
--   通知テーブル / フォローテーブル / 通知自動生成トリガー / 一括取得RPC
--
-- 実行方法: Supabase ダッシュボード → SQL Editor に貼り付けて Run
-- ※v1 を実行済みの場合も、この v2 をそのまま実行すれば上書きされます
-- ============================================================

-- ------------------------------------------------------------
-- 1. notifications (アプリ内通知) テーブル
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.notifications (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id    UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,   -- 通知を受け取るユーザー
    actor_id   UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,   -- 通知を発生させたユーザー
    type       TEXT NOT NULL CHECK (type IN ('like_post','like_comment','follow','reply_comment','comment')),
    post_id    UUID REFERENCES public.bbs_posts(id) ON DELETE CASCADE,        -- 関連ポスト
    comment_id UUID REFERENCES public.bbs_comments(id) ON DELETE CASCADE,     -- 関連コメント
    count      INT NOT NULL DEFAULT 1,                                        -- いいね集約時の件数 (1=単発)
    actor_ids  UUID[] NOT NULL DEFAULT '{}',                                  -- 集約内のいいね主一覧 (重複カウント防止)
    is_read    BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 既存DBのCHECK制約にも 'comment' を追加（冪等・再実行安全）
ALTER TABLE public.notifications DROP CONSTRAINT IF EXISTS notifications_type_check;
ALTER TABLE public.notifications ADD CONSTRAINT notifications_type_check
    CHECK (type IN ('like_post','like_comment','follow','reply_comment','comment'));

-- 既存DBにいいね集約用カラムを追加（冪等）
ALTER TABLE public.notifications ADD COLUMN IF NOT EXISTS count INT NOT NULL DEFAULT 1;
ALTER TABLE public.notifications ADD COLUMN IF NOT EXISTS actor_ids UUID[] NOT NULL DEFAULT '{}';

CREATE INDEX IF NOT EXISTS idx_notifications_user_created
    ON public.notifications (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_user_unread
    ON public.notifications (user_id) WHERE is_read = false;

-- RLS: 自分宛ての通知のみ参照・既読更新できる
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS notifications_select_own ON public.notifications;
CREATE POLICY notifications_select_own
    ON public.notifications FOR SELECT
    USING (auth.uid() = user_id);

-- UPDATEは「自分宛て」かつ「user_id を書き換えない」場合のみ許可
DROP POLICY IF EXISTS notifications_update_own ON public.notifications;
CREATE POLICY notifications_update_own
    ON public.notifications FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- 書き込み(insert/delete)はトリガー関数(SECURITY DEFINER)からのみ許可
REVOKE INSERT, DELETE ON public.notifications FROM anon, authenticated;

-- Realtime パブリケーションに登録 (通知の即時反映に必須・冪等)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables
        WHERE pubname = 'supabase_realtime'
          AND schemaname = 'public'
          AND tablename = 'notifications'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
    END IF;
END $$;

-- ------------------------------------------------------------
-- 2. user_follows (フォロー) テーブル
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.user_follows (
    follower_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,  -- フォローした人
    followed_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,  -- フォローされた人
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (follower_id, followed_id),
    CHECK (follower_id <> followed_id)
);

-- RLS: 参照は認証済みユーザーのみ(フォロー関係は個人情報)、書き込みは自分がフォロワーの場合のみ
ALTER TABLE public.user_follows ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS user_follows_select_all ON public.user_follows;
DROP POLICY IF EXISTS user_follows_select_authenticated ON public.user_follows;
CREATE POLICY user_follows_select_authenticated
    ON public.user_follows FOR SELECT
    USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS user_follows_insert_own ON public.user_follows;
CREATE POLICY user_follows_insert_own
    ON public.user_follows FOR INSERT
    WITH CHECK (auth.uid() = follower_id);

DROP POLICY IF EXISTS user_follows_delete_own ON public.user_follows;
CREATE POLICY user_follows_delete_own
    ON public.user_follows FOR DELETE
    USING (auth.uid() = follower_id);

-- ------------------------------------------------------------
-- 3. 通知自動生成トリガー
--     ※ in-app 通知(notifications)は is_notification_enabled(プッシュ通知設定)とは
--        独立して生成します。デフォルト false のため、反映すると全員通知OFFになるためです。
--        FCMプッシュ通知を飛ばす場合は、別途 Edge Function(push_notification)連携が必要です。
--     ※ 通知の削除方針: いいね・返信の通知は解除後も履歴として残す(削除トリガー無し)。
--        フォロー通知のみ、フォロー解除で削除する。
-- ------------------------------------------------------------

-- 3-1. ポストへのいいね → like_post 通知 (同一対象は未読バッチに集約)
--      例: 2件いいね → 「2件」の行 (未読) → 既読 → さらに3件 → 新しい「3件」の行
CREATE OR REPLACE FUNCTION public.notify_bbs_post_like()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_owner UUID; v_batch_id UUID; v_actors UUID[]; v_is_new BOOLEAN;
BEGIN
    SELECT user_id INTO v_owner FROM public.bbs_posts WHERE id = NEW.post_id;
    IF v_owner IS NOT NULL AND v_owner <> NEW.user_id THEN
        -- 最新の「未読」バッチを探す (既読になったら次のいいねで新しいバッチ行になる)
        SELECT id, actor_ids INTO v_batch_id, v_actors
        FROM public.notifications
        WHERE user_id = v_owner AND type = 'like_post' AND post_id = NEW.post_id
          AND is_read = false
        ORDER BY created_at DESC LIMIT 1;

        IF v_batch_id IS NULL THEN
            -- 初回 or 前バッチが既読 → 新しいバッチ行 (count=1)
            INSERT INTO public.notifications (user_id, actor_id, type, post_id, count, actor_ids)
            VALUES (v_owner, NEW.user_id, 'like_post', NEW.post_id, 1, ARRAY[NEW.user_id]);
            v_is_new := true;
        ELSIF NOT (NEW.user_id = ANY(v_actors)) THEN
            -- 未読バッチに追加 (件数+1・最新のいいね主を actor に・一覧先頭へ)
            UPDATE public.notifications
            SET count = count + 1,
                actor_ids = actor_ids || NEW.user_id,
                actor_id = NEW.user_id,
                created_at = now()
            WHERE id = v_batch_id;
            v_is_new := true;
        ELSE
            -- 同じ人からの再いいね → 件数もFCMも送らない (連打スパム防止)
            v_is_new := false;
        END IF;

        -- FCMプッシュ通知: 新規いいねのみ送信
        -- (URL は環境に合わせて置換。NOTIFY_SECRET 未設定なら x-notify-secret ヘッダー行を削除)
        IF v_is_new THEN
            PERFORM net.http_post(
                url := 'http://192.168.11.52:54321/functions/v1/notify_trigger',
                headers := jsonb_build_object(
                    'Content-Type', 'application/json',
                    'x-notify-secret', 'YOUR_NOTIFY_SECRET'
                ),
                body := jsonb_build_object(
                    'user_id', v_owner,
                    'type', 'like_post',
                    'actor_name', (SELECT name FROM public.users WHERE id = NEW.user_id)
                )
            );
        END IF;
    END IF;
    RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_notify_bbs_post_like ON public.bbs_likes;
CREATE TRIGGER trg_notify_bbs_post_like
AFTER INSERT ON public.bbs_likes
FOR EACH ROW EXECUTE FUNCTION public.notify_bbs_post_like();

-- 3-2. コメントへのいいね → like_comment 通知 (同一対象は未読バッチに集約)
CREATE OR REPLACE FUNCTION public.notify_bbs_comment_like()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_owner UUID; v_post_id UUID; v_batch_id UUID; v_actors UUID[]; v_is_new BOOLEAN;
BEGIN
    SELECT user_id, post_id INTO v_owner, v_post_id
    FROM public.bbs_comments WHERE id = NEW.comment_id;
    IF v_owner IS NOT NULL AND v_owner <> NEW.user_id THEN
        -- 最新の「未読」バッチを探す
        SELECT id, actor_ids INTO v_batch_id, v_actors
        FROM public.notifications
        WHERE user_id = v_owner AND type = 'like_comment' AND comment_id = NEW.comment_id
          AND is_read = false
        ORDER BY created_at DESC LIMIT 1;

        IF v_batch_id IS NULL THEN
            -- 初回 or 前バッチが既読 → 新しいバッチ行 (count=1)
            INSERT INTO public.notifications (user_id, actor_id, type, post_id, comment_id, count, actor_ids)
            VALUES (v_owner, NEW.user_id, 'like_comment', v_post_id, NEW.comment_id, 1, ARRAY[NEW.user_id]);
            v_is_new := true;
        ELSIF NOT (NEW.user_id = ANY(v_actors)) THEN
            -- 未読バッチに追加
            UPDATE public.notifications
            SET count = count + 1,
                actor_ids = actor_ids || NEW.user_id,
                actor_id = NEW.user_id,
                created_at = now()
            WHERE id = v_batch_id;
            v_is_new := true;
        ELSE
            -- 同じ人からの再いいね → 件数もFCMも送らない (連打スパム防止)
            v_is_new := false;
        END IF;

        -- FCMプッシュ通知: 新規いいねのみ送信
        IF v_is_new THEN
            PERFORM net.http_post(
                url := 'http://192.168.11.52:54321/functions/v1/notify_trigger',
                headers := jsonb_build_object(
                    'Content-Type', 'application/json',
                    'x-notify-secret', 'YOUR_NOTIFY_SECRET'
                ),
                body := jsonb_build_object(
                    'user_id', v_owner,
                    'type', 'like_comment',
                    'actor_name', (SELECT name FROM public.users WHERE id = NEW.user_id)
                )
            );
        END IF;
    END IF;
    RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_notify_bbs_comment_like ON public.bbs_comment_likes;
CREATE TRIGGER trg_notify_bbs_comment_like
AFTER INSERT ON public.bbs_comment_likes
FOR EACH ROW EXECUTE FUNCTION public.notify_bbs_comment_like();

-- 3-3. コメント通知 (返信 → reply_comment / ポストへのコメント → comment)
--      (parent_comment_id が入っているコメントが「返信」、入っていないのが「ポストへのコメント」)
--      post_id は親コメント由来を使用し、ポスト不整合を防ぐ
CREATE OR REPLACE FUNCTION public.notify_comment_reply()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_target_owner UUID; v_post_id UUID;
BEGIN
    IF NEW.parent_comment_id IS NOT NULL THEN
        -- 返信: 親コメントの作者に通知
        SELECT user_id, post_id INTO v_target_owner, v_post_id
        FROM public.bbs_comments WHERE id = NEW.parent_comment_id;
        IF v_target_owner IS NOT NULL AND v_target_owner <> NEW.user_id THEN
            INSERT INTO public.notifications (user_id, actor_id, type, post_id, comment_id)
            VALUES (v_target_owner, NEW.user_id, 'reply_comment', v_post_id, NEW.id);

            -- FCMプッシュ通知: Edge Function を呼び出し
            PERFORM net.http_post(
                url := 'http://192.168.11.52:54321/functions/v1/notify_trigger',
                headers := jsonb_build_object(
                    'Content-Type', 'application/json',
                    'x-notify-secret', 'YOUR_NOTIFY_SECRET'
                ),
                body := jsonb_build_object(
                    'user_id', v_target_owner,
                    'type', 'reply_comment',
                    'actor_name', (SELECT name FROM public.users WHERE id = NEW.user_id)
                )
            );
        END IF;
    ELSE
        -- トップレベルコメント: ポストの作者に通知
        SELECT user_id INTO v_target_owner FROM public.bbs_posts WHERE id = NEW.post_id;
        IF v_target_owner IS NOT NULL AND v_target_owner <> NEW.user_id THEN
            INSERT INTO public.notifications (user_id, actor_id, type, post_id, comment_id)
            VALUES (v_target_owner, NEW.user_id, 'comment', NEW.post_id, NEW.id);

            -- FCMプッシュ通知: Edge Function を呼び出し
            PERFORM net.http_post(
                url := 'http://192.168.11.52:54321/functions/v1/notify_trigger',
                headers := jsonb_build_object(
                    'Content-Type', 'application/json',
                    'x-notify-secret', 'YOUR_NOTIFY_SECRET'
                ),
                body := jsonb_build_object(
                    'user_id', v_target_owner,
                    'type', 'comment',
                    'actor_name', (SELECT name FROM public.users WHERE id = NEW.user_id)
                )
            );
        END IF;
    END IF;
    RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_notify_comment_reply ON public.bbs_comments;
CREATE TRIGGER trg_notify_comment_reply
AFTER INSERT ON public.bbs_comments
FOR EACH ROW EXECUTE FUNCTION public.notify_comment_reply();

-- 3-4. フォロー → follow 通知
CREATE OR REPLACE FUNCTION public.notify_follow()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
    INSERT INTO public.notifications (user_id, actor_id, type)
    VALUES (NEW.followed_id, NEW.follower_id, 'follow');

    -- FCMプッシュ通知: Edge Function を呼び出し
    PERFORM net.http_post(
        url := 'http://192.168.11.52:54321/functions/v1/notify_trigger',
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'x-notify-secret', 'YOUR_NOTIFY_SECRET'
        ),
        body := jsonb_build_object(
            'user_id', NEW.followed_id,
            'type', 'follow',
            'actor_name', (SELECT name FROM public.users WHERE id = NEW.follower_id)
        )
    );
    RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_notify_follow ON public.user_follows;
CREATE TRIGGER trg_notify_follow
AFTER INSERT ON public.user_follows
FOR EACH ROW EXECUTE FUNCTION public.notify_follow();

-- 3-5. フォロー解除 → follow 通知を削除
CREATE OR REPLACE FUNCTION public.remove_follow_notification()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
    DELETE FROM public.notifications
    WHERE user_id = OLD.followed_id AND actor_id = OLD.follower_id AND type = 'follow';
    RETURN OLD;
END $$;

DROP TRIGGER IF EXISTS trg_remove_follow_notification ON public.user_follows;
CREATE TRIGGER trg_remove_follow_notification
AFTER DELETE ON public.user_follows
FOR EACH ROW EXECUTE FUNCTION public.remove_follow_notification();

-- ------------------------------------------------------------
-- 4. DM 既読管理の効率化 (メンバー単位 last_read_at 方式)
--    メッセージ単位 is_read の一括UPDATEではなく、メンバー行1件の更新に置き換える
-- ------------------------------------------------------------
ALTER TABLE public.dm_room_members ADD COLUMN IF NOT EXISTS last_read_at TIMESTAMPTZ;

-- メッセージ一覧・未読カウント用インデックス
CREATE INDEX IF NOT EXISTS idx_dm_messages_room_created
    ON public.dm_messages (room_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_dm_messages_room_unread
    ON public.dm_messages (room_id) WHERE is_read = false;

-- 既読化: ルームメンバーの最終既読時刻を更新 (参加者チェック付き)
CREATE OR REPLACE FUNCTION public.mark_dm_room_read(p_room_id UUID)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
    IF NOT public.is_dm_room_member(p_room_id) THEN
        RAISE EXCEPTION 'Not a member of this room';
    END IF;
    UPDATE public.dm_room_members
    SET last_read_at = now()
    WHERE room_id = p_room_id AND user_id = auth.uid();
END $$;

-- ------------------------------------------------------------
-- 5. メッセージタブ一覧の一括取得RPC (N+1解消)
-- ------------------------------------------------------------

-- 5-1. DM一覧: ルーム・相手・最新メッセージ・未読数 を1クエリで返す
CREATE OR REPLACE FUNCTION public.get_dm_inbox(p_user_id UUID)
RETURNS TABLE(
    room_id            UUID,
    other_user_id      UUID,
    other_user_name    TEXT,
    other_avatar_url   TEXT,
    last_message       TEXT,
    last_message_at    TIMESTAMPTZ,
    unread_count       BIGINT
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
    IF p_user_id IS DISTINCT FROM auth.uid() THEN
        RAISE EXCEPTION 'Not allowed';
    END IF;
    RETURN QUERY
        SELECT
            m.room_id,
            MAX(CASE WHEN mm.user_id <> p_user_id THEN mm.user_id END),
            MAX(CASE WHEN mm.user_id <> p_user_id THEN u.name END),
            MAX(CASE WHEN mm.user_id <> p_user_id THEN u.avatar_url END),
            (SELECT x.content FROM public.dm_messages x
              WHERE x.room_id = m.room_id ORDER BY x.created_at DESC LIMIT 1),
            (SELECT x.created_at FROM public.dm_messages x
              WHERE x.room_id = m.room_id ORDER BY x.created_at DESC LIMIT 1),
            (SELECT count(*) FROM public.dm_messages x
              WHERE x.room_id = m.room_id AND x.sender_id <> p_user_id
                AND x.created_at > COALESCE(
                    (SELECT lr.last_read_at FROM public.dm_room_members lr
                     WHERE lr.room_id = m.room_id AND lr.user_id = p_user_id),
                    '-infinity'::timestamptz))
        FROM public.dm_room_members m
        JOIN public.dm_room_members mm ON mm.room_id = m.room_id AND mm.user_id <> p_user_id
        LEFT JOIN public.users u ON u.id = mm.user_id
        WHERE m.user_id = p_user_id
        GROUP BY m.room_id;
END $$;

-- 5-2. オプチャ一覧RPC: 「7. オプチャの未読管理」にて unread_count 対応版を定義
--      (CREATE OR REPLACE は戻り値の型を変更できないため、ここでは定義しない)


-- ------------------------------------------------------------
-- 6. DM / オプチャ のプッシュ通知 (FCM)
--    notifications テーブルには記録せず、Edge Function 経由でプッシュ通知のみ送る
-- ------------------------------------------------------------

-- 6-1. DM新着 → 相手にプッシュ通知
CREATE OR REPLACE FUNCTION public.notify_dm_message()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
    PERFORM net.http_post(
        url := 'http://192.168.11.52:54321/functions/v1/notify_trigger',
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'x-notify-secret', 'YOUR_NOTIFY_SECRET'
        ),
        body := jsonb_build_object(
            'type', 'dm',
            'room_id', NEW.room_id,
            'sender_id', NEW.sender_id
        )
    );
    RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_notify_dm_message ON public.dm_messages;
CREATE TRIGGER trg_notify_dm_message
AFTER INSERT ON public.dm_messages
FOR EACH ROW EXECUTE FUNCTION public.notify_dm_message();

-- 6-2. オプチャ新着 → 参加者全員にプッシュ通知
CREATE OR REPLACE FUNCTION public.notify_open_chat_message()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
    PERFORM net.http_post(
        url := 'http://192.168.11.52:54321/functions/v1/notify_trigger',
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'x-notify-secret', 'YOUR_NOTIFY_SECRET'
        ),
        body := jsonb_build_object(
            'type', 'open_chat',
            'room_id', NEW.room_id,
            'sender_id', NEW.user_id
        )
    );
    RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_notify_open_chat_message ON public.open_chat_messages;
CREATE TRIGGER trg_notify_open_chat_message
AFTER INSERT ON public.open_chat_messages
FOR EACH ROW EXECUTE FUNCTION public.notify_open_chat_message();

-- ------------------------------------------------------------
-- 7. オプチャの未読管理 (メンバー単位 last_read_at)
-- ------------------------------------------------------------
ALTER TABLE public.open_chat_members ADD COLUMN IF NOT EXISTS last_read_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_open_chat_messages_room_created
    ON public.open_chat_messages (room_id, created_at DESC);

-- オプチャ既読化: 自分のメンバー行の最終既読時刻を更新
CREATE OR REPLACE FUNCTION public.mark_open_chat_room_read(p_room_id UUID)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
    UPDATE public.open_chat_members
    SET last_read_at = now()
    WHERE room_id = p_room_id AND user_id = auth.uid();
END $$;

-- オプチャ一覧RPCを未読数対応に更新 (戻り値の型が変わるため、先に DROP してから再作成)
DROP FUNCTION IF EXISTS public.get_open_chat_inbox(uuid);
CREATE OR REPLACE FUNCTION public.get_open_chat_inbox(p_user_id UUID)
RETURNS TABLE(
    room                   JSONB,
    last_message           TEXT,
    last_message_user_name TEXT,
    last_message_at        TIMESTAMPTZ,
    unread_count           BIGINT
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
    IF p_user_id IS DISTINCT FROM auth.uid() THEN
        RAISE EXCEPTION 'Not allowed';
    END IF;
    RETURN QUERY
        SELECT
            to_jsonb(ocr.*),
            x.content,
            xu.name,
            x.created_at,
            (SELECT count(*) FROM public.open_chat_messages ocmsg
              WHERE ocmsg.room_id = ocr.id AND ocmsg.user_id <> p_user_id
                AND ocmsg.created_at > COALESCE(
                    (SELECT lr.last_read_at FROM public.open_chat_members lr
                     WHERE lr.room_id = ocr.id AND lr.user_id = p_user_id),
                    '-infinity'::timestamptz))
        FROM public.open_chat_rooms ocr
        LEFT JOIN LATERAL (
            SELECT content, user_id, created_at
            FROM public.open_chat_messages
            WHERE room_id = ocr.id
            ORDER BY created_at DESC LIMIT 1
        ) x ON true
        LEFT JOIN public.users xu ON xu.id = x.user_id
        WHERE EXISTS (
            SELECT 1 FROM public.open_chat_members ocm
            WHERE ocm.room_id = ocr.id AND ocm.user_id = p_user_id
        );
END $$;

-- 検証用: 通知テーブルが正しく作られたか確認
-- SELECT * FROM public.notifications ORDER BY created_at DESC LIMIT 10;

-- ------------------------------------------------------------
-- 8. 通知カテゴリ別設定 (プッシュ通知の細かいON/OFF)
--    ※ アプリ内通知(notifications)には影響しない。
--       プッシュ(FCM)送信時に Edge Function 側で
--       is_notification_enabled(マスター) とカテゴリ設定の両方を判定する。
--       → カテゴリONでもマスターOFFならプッシュは送られない。
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.notification_settings (
    user_id               UUID PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
    like_enabled          BOOLEAN NOT NULL DEFAULT true,   -- いいね (like_post / like_comment)
    comment_enabled       BOOLEAN NOT NULL DEFAULT true,   -- コメント・返信 (comment / reply_comment)
    follow_enabled        BOOLEAN NOT NULL DEFAULT true,   -- フォロー
    dm_enabled            BOOLEAN NOT NULL DEFAULT true,   -- DM
    open_chat_enabled     BOOLEAN NOT NULL DEFAULT true,   -- オプチャ
    match_waiting_enabled BOOLEAN NOT NULL DEFAULT true,   -- 対戦待ち
    updated_at            TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- RLS: 自分自身の設定のみ参照・挿入・更新できる
ALTER TABLE public.notification_settings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS notification_settings_select_own ON public.notification_settings;
CREATE POLICY notification_settings_select_own
    ON public.notification_settings FOR SELECT
    USING (auth.uid() = user_id);

DROP POLICY IF EXISTS notification_settings_insert_own ON public.notification_settings;
CREATE POLICY notification_settings_insert_own
    ON public.notification_settings FOR INSERT
    WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS notification_settings_update_own ON public.notification_settings;
CREATE POLICY notification_settings_update_own
    ON public.notification_settings FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- 既存ユーザー分を初期化（全カテゴリON。マスター is_notification_enabled とは独立）
INSERT INTO public.notification_settings (user_id)
SELECT id FROM public.users
ON CONFLICT (user_id) DO NOTHING;

-- 新規ユーザー作成時に設定行を自動生成
CREATE OR REPLACE FUNCTION public.handle_new_notification_settings()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
    INSERT INTO public.notification_settings (user_id) VALUES (NEW.id) ON CONFLICT DO NOTHING;
    RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_new_notification_settings ON public.users;
CREATE TRIGGER trg_new_notification_settings
AFTER INSERT ON public.users
FOR EACH ROW EXECUTE FUNCTION public.handle_new_notification_settings();
