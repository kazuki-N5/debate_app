-- 通知ログ用テーブルの作成
CREATE TABLE IF NOT EXISTS public.notification_logs (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id uuid REFERENCES auth.users(id),
    created_at timestamp WITH TIME ZONE DEFAULT now()
);

-- 検索高速化のためのインデックス
CREATE INDEX IF NOT EXISTS idx_notification_logs_user_id_created_at 
ON public.notification_logs(user_id, created_at DESC);
