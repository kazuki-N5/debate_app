-- QStash API トークンをリポジトリに直書きしないための取得関数。
--
-- 値はソース管理外で設定する（例）:
--   ALTER ROLE authenticator SET app.qstash_token = '<rotated QStash token>';
--   -- SQL エディタから直接実行する場合:
--   ALTER DATABASE postgres SET app.qstash_token = '<rotated QStash token>';
--
-- 未設定の場合は空文字を返す。QStash への publish は 401 で失敗するが、
-- トリガー本体の処理は継続する（net.http_post は非同期）。
--
-- RPC 経由でトークンが読まれないよう、公開ロールからは EXECUTE を剥奪する。
-- 呼び出し元のトリガー関数はいずれも SECURITY DEFINER (owner: postgres) のため実行可能。
CREATE OR REPLACE FUNCTION public.get_qstash_token()
RETURNS text
LANGUAGE sql
STABLE
AS $$
  SELECT COALESCE(current_setting('app.qstash_token', true), '');
$$;

REVOKE ALL ON FUNCTION public.get_qstash_token() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_qstash_token() FROM anon;
REVOKE ALL ON FUNCTION public.get_qstash_token() FROM authenticated;
