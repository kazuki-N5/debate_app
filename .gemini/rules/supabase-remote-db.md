# Supabase リモートDB適用ルール

本プロジェクトでは、Supabaseインスタンスが別PC（LAN内のリモートホスト）で稼働しています。

## 1. 接続情報の確認
- `.env` に記載された `P_VAR_URL` のホストIP（例: `192.168.11.52`）を確認する。
- PostgreSQLの接続先情報:
  - **ホスト**: `.env` のIPアドレス（例: `192.168.11.52`）
  - **ポート**: `54322`
  - **ユーザー**: `postgres`
  - **パスワード**: `postgres`
  - **データベース**: `postgres`

## 2. SQL変更時の必須アクション
- `supabase/migrations/` 配下に新しいマイグレーションSQLを作成、または既存SQLを変更した際は、**作業PCローカルの `npx supabase` コマンドを使用せず**、Node.jsの `pg` クライアント等を用いて上記のリモートPostgreSQLに直接接続し、作成したSQLを即座に適用（`query` 実行）すること。
- 適用後は、インデックスやテーブル、関数が正しく反映されたか（`pg_indexes` や `information_schema` 等）を必ず確認してユーザーに報告すること。
