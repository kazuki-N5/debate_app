# Requirement R2: 開発から本番へのマージフロー調査報告書 (Handoff Report)

## 1. Observation (直接的な観察結果)

- **プロジェクト構造の観察**
  - プロジェクトルート: `C:\Users\kazuk\program\AppList\debata\`
  - `pubspec.yaml`, `lib/` (Flutterアプリ本体), `schema.sql`, `data.sql` (レガシー/バックアップSQL), および `supabase/` ディレクトリが存在する。
  - `supabase/` ディレクトリ構造:
    - `config.toml` (サイズ: 12.5 KB - CLIの設定ファイル)
    - `seed.sql` (サイズ: 12 B)
    - `.gitignore` (サイズ: 72 B)
    - `functions/`, `.temp/`, `.branches/`
    - 現状 `supabase/migrations/` ディレクトリは未作成（または本番初期マイグレーションが未適用状態）。

- **Supabase CLI仕様およびドキュメントの観察**
  - ローカルStudio URL: `http://127.0.0.1:54323` (ローカル開発時のWeb UI GUI)
  - マイグレーション生成コマンド:
    - `supabase db diff -f <migration_name>` (ローカルDBとシャドウDB/リモートDBの差分抽出)
    - `supabase migration new <name>` (手動SQL記述用の空ファイル作成)
  - マイグレーション検証コマンド: `supabase db reset` (ローカルDBリセット & マイグレーション順次全実行 + `seed.sql` 実行)
  - リモート適用コマンド: `supabase db push` (`supabase/migrations/` 内の未適用マイグレーションをリモート環境へ安全順次適応)
  - 認証キー:
    - `SUPABASE_ACCESS_TOKEN`: CLI/Management API操作用の個人アクセストークン
    - `SUPABASE_DB_PASSWORD`: PostgreSQLデータベース接続用パスワード
    - `SUPABASE_PROJECT_ID` (`DB_PROJECT_REF`): リモートSupabaseプロジェクト識別子
  - CI/CDアクション: Official `supabase/setup-cli@v3` (GitHub Actions用)

---

## 2. Logic Chain (論理的推論チェーン)

1. **ローカル環境でのスキーマ変更ワークフロー**
   - **推論**: ローカル環境では「Studio UI操作による手軽な試走」と「SQLスクリプトによる宣言的管理」の2つの方法がある。
   - **結論**: Studio UIで直感的にテーブル/カラム/RLSを変更した後、`supabase db diff -f <migration_name>` を実行してSQL形式のマイグレーションファイルに自動変換するのが最も効率的でミスが少ない。一方、複雑なRLSポリシーや関数/トリガー作成は `supabase migration new <name>` で手動記述するのが適している。

2. **Gitバージョン管理の最適化**
   - **推論**: データベース定義をソースコードと同等にバージョン管理（Infrastructure as Code）する必要がある。
   - **結論**: 
     - `supabase/config.toml`: バージョン管理に含める（プロジェクト構成の標準化）。ただし環境依存の認証キー等は環境変数で参照。
     - `supabase/migrations/*.sql`: 厳格にバージョン管理に含める。一度Git `main` にマージ・適用されたマイグレーションファイルは**絶対に変更・削除せず、追加のマイグレーションで差分修復する**。
     - `supabase/seed.sql`: テスト用初期データとして管理。本番データ（個人情報や実環境データ）は絶対に含まない。
     - `supabase/.temp`, `supabase/.branches`: `.gitignore` に追加してGit管理から除外。

3. **マイグレーションのローカル検証**
   - **推論**: マイグレーションスクリプトが依存関係エラーや構文エラーを起こさないかを事前に確定させる必要がある。
   - **結論**: `supabase db reset` を実行することで、データベースを初期化し、全マイグレーションファイルをタイムスタンプ順に再実行、最後に `seed.sql` を流し込む。これにより「最初から再現可能なスキーマ構造」であることが保証される。

4. **本番環境への反映（`supabase db push` & CLI認証）**
   - **推論**: 手動での本番DB直接操作はヒューマンエラーの原因となる。
   - **結論**: `supabase db push` コマンドを使用して、本番環境に適用されていない差分マイグレーションのみを順番に自動適用する。認証には `SUPABASE_ACCESS_TOKEN`（API操作権限）と `SUPABASE_DB_PASSWORD`（Postgres直接接続用）が必要。

5. **GitHub ActionsによるCI/CD自動化フロー**
   - **推論**: 開発者がローカルから手動で本番へ `db push` するリスクを排除し、PRマージ時に自動適用させる。
   - **結論**:
     - `main` ブランチへの `push` (または `paths: supabase/migrations/**`) をトリガーとする。
     - `supabase/setup-cli@v3` を使用してCLIをセットアップ。
     - Repository Secrets に `SUPABASE_ACCESS_TOKEN`, `SUPABASE_DB_PASSWORD`, `SUPABASE_PROJECT_ID` を登録。
     - `concurrency` 設定で同時デプロイによるロック衝突を防止。

6. **FlutterクライアントとDBスキーマのゼロダウンタイム同期（Expand and Contractパターン）**
   - **推論**: 稼働中の本番アプリのユーザーは、アプリを即座にアップデートするわけではない。DBスキーマの破壊的変更（カラム削除や型変更など）は旧バージョンのアプリをクラッシュさせる。
   - **結論**: Expand & Contract (Parallel Change) パターンを適用する。
     - **Phase 1 (Expand - 拡張)**: DBに新しいカラム/テーブルを追加（旧カラムは残す・NULL許容またはデフォルト値設定）。旧アプリも正常動作継続。
     - **Phase 2 (Flutter App Deploy & Migration - 移行)**: 新旧両書きまたは新カラム参照を行うFlutterアプリをリリース。既存データを新カラムへ移行するDMLを実行。
     - **Phase 3 (Contract - 収束)**: 旧アプリの利用割合が十分に低下した後（または強制アップデート発動後）、旧カラムや旧テーブルを削除するマイグレーションを適用。

---

## 3. Caveats (注意点・前提条件・未調査事項)

- **直接変更の禁止**: Supabase Dashboard（Web本番画面）上で直接テーブル追加・変更を行うと、Git管理のマイグレーション履歴と乖離（ドリフト）が発生するため禁物。
- **データ移行SQLの実行タイミング**: 大容量データの移行 (`UPDATE table SET new_col = old_col`) をマイグレーションファイル内で行うと、トランザクションタイムアウトやロックが発生する可能性がある。大規模データの場合は非同期バッチ処理を検討する。
- **RLSポリシーの破壊的変更**: RLSを変更すると、旧バージョンアプリからのアクセスが拒否されるリスクがある。新しいポリシーは旧クライアントからのリクエストも考慮する。
- **強制アップデート機能の未検証**: 現状Flutterアプリ側に Remote Config 等によるバージョン強制アップデートの仕組みが存在するかは未調査。

---

## 4. Conclusion (結論・詳細設計)

### 【ステップバイステップ】開発〜本番へのマージ & デプロイフロー

```
[Local Dev]
  1. Local Studio UI or SQL edits
  2. `supabase db diff -f add_new_table`
  3. `supabase db reset` (Verification)
  4. Git Commit & Push (PR created)
        │
[GitHub Actions CI/CD]
  5. PR checks (Linting & Dry-run reset test)
  6. Merge PR to `main` branch
  7. Automated `supabase db push` to Production DB
        │
[Flutter Deployment]
  8. Deploy updated Flutter client (Expand-compatible)
```

#### 詳細コマンド集
1. **ローカル差分作成**: `npx supabase db diff -f <migration_name>`
2. **手動新規作成**: `npx supabase migration new <migration_name>`
3. **ローカル検証**: `npx supabase db reset`
4. **本番リンク & 手動プッシュ (CLI)**:
   ```bash
   npx supabase link --project-ref <PROJECT_ID>
   npx supabase db push
   ```

#### GitHub Actions ワークフロー設定例 (`.github/workflows/supabase_deploy.yml`)
```yaml
name: Deploy Supabase Migrations

on:
  push:
    branches:
      - main
    paths:
      - 'supabase/migrations/**'
  workflow_dispatch:

concurrency:
  group: supabase-deploy-${{ github.ref }}
  cancel-in-progress: true

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout Repository
        uses: actions/checkout@v4

      - name: Setup Supabase CLI
        uses: supabase/setup-cli@v3
        with:
          version: latest

      - name: Deploy Migrations to Supabase Production
        env:
          SUPABASE_ACCESS_TOKEN: ${{ secrets.SUPABASE_ACCESS_TOKEN }}
          SUPABASE_DB_PASSWORD: ${{ secrets.SUPABASE_DB_PASSWORD }}
          SUPABASE_PROJECT_ID: ${{ secrets.SUPABASE_PROJECT_ID }}
        run: |
          supabase link --project-ref $SUPABASE_PROJECT_ID
          supabase db push
```

#### Flutter × Supabase 段階的デプロイ手順 (Expand & Contract)
1. **[DB] Expand Migration**: 新規テーブル/カラムを非破壊的（NULL許容またはデフォルト値付き）に追加しデプロイ。
2. **[Flutter] Client Release**: 新スキーマを利用するアプリバージョンをビルド・各ストアに配信。
3. **[App Version Gating] 強制アップデート判定**: 最小必要アプリバージョン (Minimum Supported Version) を設定し、旧アプリ利用者に更新を促す。
4. **[DB] Contract Migration**: 旧アプリの利用がなくなった段階で、廃止予定のカラム・テーブルを削除するマイグレーションをデプロイ。

---

## 5. Verification Method (独立検証方法)

### 検証コマンド
- **ローカル動作検証**:
  ```bash
  # 1. ローカルSupabaseの起動
  npx supabase start
  
  # 2. 空マイグレーション生成テスト
  npx supabase migration new test_migration
  
  # 3. DBリセットによるマイグレーション全適用検証
  npx supabase db reset
  ```

### 出力ファイル検証
- `C:\Users\kazuk\program\AppList\debata\.agents\explorer_r2_1\handoff.md` が本報告書の内容で正しく書き出されていることを確認。

### 不成立条件 (Invalidation Conditions)
- `supabase db reset` でマイグレーション実行時にエラーが発生する（タイムスタンプ順序の逆転、SQL構文エラー、未定義テーブル参照）。
- `supabase db push` 実行時に `SUPABASE_ACCESS_TOKEN` または `SUPABASE_DB_PASSWORD` の権限不足で接続失敗する。
- DB側の非互換なスキーマ変更（カラム即時削除）により、ストア上の既存FlutterアプリでAPI呼び出しエラー（500/400）が発生する。
