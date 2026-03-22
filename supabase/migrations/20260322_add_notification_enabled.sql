-- users テーブルに通知のオンオフを管理するカラムを追加するSQL
-- カラム名: is_notification_enabled (初期値: true)
ALTER TABLE public.users ADD COLUMN is_notification_enabled boolean DEFAULT true;
