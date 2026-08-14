# Flutter × Supabase ローカル開発環境構築 & 本番マージ運用完全ガイド

すでにユーザーが存在し本番稼働しているFlutter × Supabaseアプリケーションにおいて、安全にローカル開発環境を構築・運用し、開発から本番へのマージおよびスキーマ反映をゼロダウンタイムで実現するための包括的な技術仕様書・運用ガイドラインです。

---

## 1. エグゼクティブサマリー & アーキテクチャ概要

### 1.1 エグゼクティブサマリー

本番環境のデータおよび稼働中サービスを破壊することなく、新機能開発やデータベース設計の変更を安全に行うためには、**「コードとしてのインフラ管理 (Infrastructure as Code: IaC)」** と **「データと環境の完全隔離」** の徹底が不可欠です。

本ガイドラインでは、以下の3つの柱を基本原則とします：

1. **完全宣言型スキーマ管理**: データベースのテーブル、関数、RLS（Row Level Security）ポリシー、トリガーはすべて `supabase/migrations/*.sql` のマイグレーションファイルとしてGit管理し、本番Web Dashboardでの手動変更を全面的に禁止します。
2. **決定論的開発データの分離**: 本番データベースの顧客個人情報（PII）のローカル環境持ち込みを禁止し、`supabase/seed.sql` による決定論的ダミーデータおよび認証モックを活用します。
3. **ゼロダウンタイム・クライアント同期**: モバイルアプリ（Flutter）の旧バージョンが端末に一定期間残存する特性に対応するため、**Expand & Contract (Parallel Change) パターン**による非破壊的デプロイメントを実践します。

---

### 1.2 全体アーキテクチャ概要

```
┌────────────────────────────────────────────────────────────────────────┐
│                         Local Machine (Docker)                         │
│  ┌─────────────┐  ┌─────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │ Flutter App │  │ Studio UI   │  │ PostgreSQL   │  │ GoTrue Auth  │  │
│  │ (Emulator/  │  │ (Port 54323)│  │ (Port 54322) │  │ & Storage    │  │
│  │  Physical)  │  └─────────────┘  └──────────────┘  └──────────────┘  │
│  └──────┬──────┘                          ▲                            │
│         │ http://10.0.2.2:54321           │ supabase db reset          │
│         │ or 127.0.0.1:54321              │                            │
│  ┌──────▼─────────────────────────────────┴─────────────────────────┐  │
│  │                     Supabase Gateway (Kong)                      │  │
│  └──────────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────┬─────────────────────────────────────┘
                                   │ Git Pull Request / Push (main)
                                   ▼
┌────────────────────────────────────────────────────────────────────────┐
│                        GitHub Actions (CI/CD)                          │
│  [PR (CI)] supabase_ci.yml:                                           │
│    1. supabase start & db reset (マイグレーション順次再現性検証)      │
│    2. supabase db lint  (静的セキュリティ・パフォーマンス解析)        │
│    3. supabase test db  (pgTAP による RLS ユニットテスト)              │
│                                                                        │
│  [Merge (CD)] supabase_deploy.yml:                                     │
│    4. supabase db push  (本番 DB への未適用マイグレーション自動反映)  │
└──────────────────────────────────┬─────────────────────────────────────┘
                                   │ Database Connection (TLS)
                                   ▼
┌────────────────────────────────────────────────────────────────────────┐
│                      Supabase Cloud (Production)                       │
│  ┌───────────────────────────────┐  ┌──────────────────────────────┐  │
│  │ PostgreSQL (Production DB)    │  │ WAL-G Continuous Archive     │  │
│  │ (Row Level Security Enabled)  │  │ (Point-in-Time Recovery)     │  │
│  └───────────────────────────────┘  └──────────────────────────────┘  │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 2. 要件R1: ローカル開発環境の初期化手順とコマンド

### 2.1 開発環境の前提条件と CLI インストール

ローカル環境では、Dockerコンテナ群としてSupabaseのフルスタック（PostgreSQL, Auth/GoTrue, Storage, Edge Functions, Studio UI, Kong API Gateway等）が独立して動作します。

#### ① Docker エンジンの準備・検証
- **Windows / macOS**: Docker Desktop または Podman を起動
- **検証コマンド**:
  ```bash
  docker info
  ```
  ※ `Cannot connect to the Docker daemon` エラーが表示される場合は、Docker Desktopが起動しているか確認してください。

#### ② Supabase CLI のインストール
OSに応じた最適なパッケージマネージャーを使用して Supabase CLI をインストールします。

- **Windows (Scoop)**:
  ```bash
  scoop bucket add supabase https://github.com/supabase/scoop-bucket.git
  scoop install supabase
  ```
- **Windows (Winget)**:
  ```bash
  winget install Supabase.CLI
  ```
- **macOS / Linux (Homebrew)**:
  ```bash
  brew install supabase/tap/supabase
  ```
- **Cross-platform (NPM)**:
  ```bash
  npm install -g supabase
  ```

インストール検証：
```bash
supabase --version
```

#### ③ Supabase CLI への認証ログイン
```bash
supabase login
```
ブラウザが起動するので、Supabase Personal Access Token を生成・承認し、ローカルCLIに認証設定を保存します。

---

### 2.2 プロジェクト初期化と本番プロジェクトのバインド

#### ① プロジェクト初期化 (`supabase init`)
既存のFlutterプロジェクトのルートディレクトリで実行します：
```bash
supabase init
```
実行により、以下の構造が生成されます：
- `supabase/config.toml` — ローカルサービスポート、認証プロバイダ、ストレージ制限等の設定ファイル
- `supabase/seed.sql` — ローカル開発用の初期ダミーデータ投入用SQLスクリプト
- `supabase/migrations/` — スキーマ変更マイグレーションSQLファイルを保持する空ディレクトリ

#### ② `.gitignore` の設定追加
CLIの一時ファイルやローカルのブランチキャッシュをGit管理対象外にします：
```gitignore
# Supabase CLI Local Temporary & Cache Files
supabase/.temp/
supabase/.branches/
.env.local
.env.development
.env.local.json
```

#### ③ 本番プロジェクトとのリンク (`supabase link`)
Supabase Dashboard の `Project Settings -> General` より **Project Reference ID** (`<project-ref>`) を確認・取得します。

```bash
supabase link --project-ref <project-ref>
```
実行時、PostgreSQLデータベース接続パスワードが要求されます。環境変数 `SUPABASE_DB_PASSWORD` を設定しておくことでプロンプトをスキップできます。

---

### 2.3 ローカルスタックの起動と状態検証 (`supabase start`)

> **極めて重要（実行順序）**: リモートDBからスキーマを取得する `supabase db pull` コマンドは、差分抽出および定義検証のためにローカルの Docker PostgreSQL コンテナ（シャドウDB）を利用します。そのため、**`supabase db pull` を実行する前に必ず `supabase start` を起動させておく必要があります**。

#### ① ローカルコンテナ群の起動 (`supabase start`)
```bash
supabase start
```
初回起動時は各種コンテナイメージが自動的にダウンロードされ、ローカルPostgreSQLおよび関連サービス群が起動します。

#### ② ステータス確認 (`supabase status`)
```bash
supabase status
```
出力される主要な接続エンドポイント一覧：
- **API Gateway (Kong)**: `http://127.0.0.1:54321`
- **PostgreSQL Database**: `postgresql://postgres:postgres@127.0.0.1:54322/postgres`
- **Studio UI (Web GUI)**: `http://127.0.0.1:54323`
- **Inbucket (ローカルメール受信箱)**: `http://127.0.0.1:54324`
- **anon key (JWT)**: `<LOCAL_JWT_ANON_KEY>`
- **service_role key (JWT)**: `<LOCAL_JWT_SERVICE_ROLE_KEY>`

ブラウザで `http://127.0.0.1:54323` を開くことで、本番環境と全く同等のStudio管理画面をローカルで利用できます。

---

### 2.4 既存本番スキーマの取得 (`supabase db pull`)

現在本番環境で稼働しているデータベースから、テーブル構造、RLSポリシー、関数、Enum、トリガー等の全DDL定義を抽出し、ローカルのベースラインマイグレーションとして書き出します。

```bash
supabase db pull
```
生成されるファイル：
`supabase/migrations/<TIMESTAMP>_remote_schema.sql` (例: `supabase/migrations/20260813120000_remote_schema.sql`)

> **重要（データ保護）**: `supabase db pull` はデータベースの構造（DDL）のみを取得します。ユーザーレコードや顧客データ（DML）は**一切抽出されない**ため、本番データの安全性が担保されます。

---

### 2.5 本番ベースラインマイグレーションの記録 (`supabase migration repair`)

> **クリティカル（本番障害防止）**: `supabase db pull` で生成されたベースラインマイグレーション（`<TIMESTAMP>_remote_schema.sql`）は、本番環境のデータベース構造そのものです。この状態で何もしないまま初回 CI/CD や `supabase db push` を実行すると、Supabase CLI は「本番環境に未適用のマイグレーションファイルが存在する」と判断し、本番DBに対してテーブル作成SQLを再実行して `ERROR: relation "..." already exists` でデプロイが破綻・クラッシュします。

これを防止するため、`supabase db pull` 完了直後に、リモート本番環境のマイグレーション履歴テーブル (`supabase_migrations.schema_migrations`) に対し、このベースラインマイグレーションが**「適用済み (applied)」**であることを明示的に記録（リペア）します。

#### 実行コマンド:
```bash
supabase migration repair --status applied <TIMESTAMP>
```
*(例: ファイル名が `20260813120000_remote_schema.sql` の場合)*
```bash
supabase migration repair --status applied 20260813120000
```

このコマンドにより、本番DBのスキーマを一切変更することなく、「ベースラインマイグレーション適用済み」のフラグのみが記録され、今後の `supabase db push` が安全に行えるようになります。

---

### 2.6 テスト用シードデータと認証モック作成 (`seed.sql`)

ローカル開発環境では本番のユーザーアカウントが存在しないため、`supabase/seed.sql` にテスト用認証ユーザーと初期ドメインデータを定義します。

`auth.users` にユーザーを作成する際は、GoTrue認証基盤と整合性を維持するため `auth.identities` にも必ずセットでレコードを追加します。また、誤って本番・Staging環境で `seed.sql` が実行される事故を防止するため、スクリプト先頭に環境チェックガードを挿入します。

#### `supabase/seed.sql` の実装例：
```sql
-- Guard: Prevent seed execution in production
DO $$
BEGIN
  IF current_setting('app.environment', true) IN ('production', 'prod', 'staging') THEN
    RAISE EXCEPTION 'CRITICAL: seed.sql execution blocked in non-local environment!';
  END IF;
END $$;

-- 1. テスト用認証ユーザーの追加 (ログインパスワード: Password123!)
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token
) VALUES (
  '00000000-0000-0000-0000-000000000000',
  '11111111-1111-1111-1111-111111111111',
  'authenticated', 'authenticated',
  'devuser@example.com',
  extensions.crypt('Password123!', extensions.gen_salt('bf')),
  now(),
  '{"provider":"email","providers":["email"]}',
  '{"name":"Dev User"}',
  now(), now(), ''
) ON CONFLICT (id) DO NOTHING;

-- 2. 対応する認証アイデンティティの追加
INSERT INTO auth.identities (
  id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at, provider_id
) VALUES (
  '11111111-1111-1111-1111-111111111111',
  '11111111-1111-1111-1111-111111111111',
  format('{"sub":"%s","email":"%s"}', '11111111-1111-1111-1111-111111111111', 'devuser@example.com')::jsonb,
  'email', now(), now(), now(), 'devuser@example.com'
) ON CONFLICT (id) DO NOTHING;

-- 3. アプリケーション用プロフィール初期データの追加
INSERT INTO public.profiles (id, username, display_name)
VALUES ('11111111-1111-1111-1111-111111111111', 'devuser', '開発テストユーザー')
ON CONFLICT (id) DO NOTHING;
```

#### ローカルDBリセットとシード検証 (`supabase db reset`)
```bash
supabase db reset
```
ローカルDBが一度全削除・再作成され、`supabase/migrations/` 内のSQLが順次実行された後、`supabase/seed.sql` が自動適用されます。

---

### 2.7 Flutter アプリケーションの接続設定と環境分岐

FlutterアプリからローカルSupabaseに接続する際、実行プラットフォームに応じたネットワーク設定および環境変数の安全な管理を行います。

#### ① 環境変数・`.env` ファイルの管理手順
機密情報（APIキーや接続URL）をハードコードせず、`.env.local.json` または `--dart-define-from-file` を活用します。

1. **プロジェクトルートに `.env.local.json` を作成**:
   ```json
   {
     "SUPABASE_URL": "http://10.0.2.2:54321",
     "SUPABASE_ANON_KEY": "eyJhbGciOi..."
   }
   ```
2. **`.gitignore` に登録**: `.env.local.json` や `.env.development` をコミット対象外にします。

#### ② Android Cleartext (HTTP) 通信の許可設定
ローカルSupabase Gatewayはデフォルトで HTTP (`http://10.0.2.2:54321`) で稼働します。Android 9 (API level 28) 以降のデフォルトセキュリティポリシーでは明示的な暗号化なしの通信（Cleartext Traffic）が禁止されており、接続時に `SocketException: Connection refused` 等のクラッシュが発生します。

**対策**: `android/app/src/main/AndroidManifest.xml` の `<application>` タグに `android:usesCleartextTraffic="true"` を追加します。

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application
        android:label="debata"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher"
        android:usesCleartextTraffic="true">
        <!-- ... -->
    </application>
</manifest>
```

#### ③ ループバックアドレスの割当規則:
- **iOS シミュレータ / macOS / Web / デスクトップ**: `http://127.0.0.1:54321`
- **Android エミュレータ**: `http://10.0.2.2:54321` (Android特有のホストマシン参照ループバックIP)
- **Android エミュレータ (`adb reverse` 使用時)**: `http://127.0.0.1:54321`
- **Wi-Fi接続の実機デバイス**: `http://<HOST_LAN_IP>:54321` (例: `http://192.168.1.15:54321`)

#### ④ 動的ホスト設定ファイル (`lib/core/config/supabase_config.dart`):
*(※注: `supabase_flutter` v2.x 以降で非推奨・削除された `debug: kDebugMode` パラメータは排除しています)*

```dart
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static String get url {
    // 1. ビルド時引数 (--dart-define / --dart-define-from-file) を優先
    const envUrl = String.fromEnvironment('SUPABASE_URL');
    if (envUrl.isNotEmpty) return envUrl;

    // 2. 実行プラットフォームに応じた自動デフォルト値
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:54321';
    }
    return 'http://127.0.0.1:54321';
  }

  static String get anonKey {
    return const String.fromEnvironment(
      'SUPABASE_ANON_KEY',
      defaultValue: 'YOUR_LOCAL_ANON_KEY', // supabase status で確認した anon key
    );
  }

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: url,
      anonKey: anonKey,
    );
  }
}

/// アプリケーション内で SupabaseClient を提供するシングルトン/依存注入プロバイダ
SupabaseClient get supabaseClient => Supabase.instance.client;
```

#### ⑤ Flutter アプリ起動コマンド:
- **`--dart-define-from-file` を使用した起動 (推奨)**:
  ```bash
  flutter run --dart-define-from-file=.env.local.json
  ```
- **Android エミュレータ (個別指定)**:
  ```bash
  flutter run --dart-define=SUPABASE_URL=http://10.0.2.2:54321 --dart-define=SUPABASE_ANON_KEY=<LOCAL_ANON_KEY>
  ```
- **Android エミュレータ (`adb reverse` 経由)**:
  ```bash
  adb reverse tcp:54321 tcp:54321
  flutter run --dart-define=SUPABASE_URL=http://127.0.0.1:54321 --dart-define=SUPABASE_ANON_KEY=<LOCAL_ANON_KEY>
  ```

---

## 3. 要件R2: 開発から本番へのマージ・デプロイフロー

### 3.1 ローカル開発でのスキーマ変更とマイグレーション生成

ローカル開発での変更作業には、開発規模や目的に応じて2つの手法を使い分けます。

#### 手法A: ローカルStudio UI操作からの自動差分抽出 (`supabase db diff`)
1. ブラウザで `http://127.0.0.1:54323` (ローカルStudio) を開き、GUIでテーブル、カラム、RLS、Enum等の作成・変更を行う。
2. 変更結果をCLIコマンドでマイグレーションSQLファイルとして生成する：
   ```bash
   supabase db diff -f add_topics_table
   ```
3. `supabase/migrations/<TIMESTAMP>_add_topics_table.sql` が自動作成されます。

> **警告（自動差分のリスク）**: `supabase db diff` は既存カラムの改名や削除を行った場合、単一の `RENAME COLUMN` または `DROP COLUMN` を生成します。本番環境で運用中のアプリが存在する場合、これをそのまま適用すると旧バージョンアプリがクラッシュします。破壊的変更を行う場合は、後述の **Expand & Contract パターン** に従って手動でマイグレーションを分割してください。

#### 手法B: マイグレーションファイルの手動新規作成 (`supabase migration new`)
複雑なPostgreSQL関数、トリガー、独自のRLSポリシーを直接記述する場合：
```bash
supabase migration new create_custom_functions
```
`supabase/migrations/<TIMESTAMP>_create_custom_functions.sql` が生成されるので、エディタで直接SQLを記述します。

---

### 3.2 チーム開発におけるマイグレーション衝突防止・タイムスタンプ調整ルール

複数人の開発者が並行してブランチを作成しマイグレーションを追加した場合、マージ順序によってタイムスタンプが前後し、本番環境へのデプロイ時に `supabase db push` が out-of-order エラーで拒否されることがあります。

#### タイムスタンプ衝突回避プロトコル:
1. **マージ前の状態確認**:
   PRをマージする前に、ローカルとリモートの適用状況を比較します：
   ```bash
   supabase migration list
   ```
2. **Rebase & タイムスタンプ更新**:
   `main` ブランチを rebase した際、自分のマイグレーションファイルのタイムスタンプが `main` に存在する最新のマイグレーションより古い場合は、ファイル名のタイムスタンプ接頭辞を最新の日時 (`YYYYMMDDHHMMSS`) にリネーム更新します。
3. **リセット再現性の再確認**:
   リネーム後、`supabase db reset` を実行し、タイムスタンプ順でマイグレーションが正常に完走することを確認してから PR をマージします。

---

### 3.3 マイグレーションのローカル再現性検証 (`supabase db reset`)

作成したマイグレーションスクリプトが、依存関係エラーや構文エラーを起こさないかコミット前に必ず検証します。

```bash
supabase db reset
```
- データベースが初期化され、`supabase/migrations/` 内のすべてのファイルがタイムスタンプ順にゼロから順次適用されます。
- マイグレーション完了後、`supabase/seed.sql` が自動実行されます。
- **このコマンドがエラーなしで完了することにより、Gitへ安全にコミットできる状態であることが証明されます。**

---

### 3.4 Git バージョン管理ルール

データベース構造をソースコードと同等にバージョン管理（Infrastructure as Code）します。

| ファイル/ディレクトリ | Git管理区分 | 運用ルール |
| :--- | :--- | :--- |
| `supabase/config.toml` | **管理対象** | プロジェクトの構成定義。パスワードやAPIキー等の秘密情報は環境変数参照とする。 |
| `supabase/migrations/*.sql` | **管理対象 (厳格)** | 一度 `main` ブランチにマージされたファイルは**絶対に変更・削除禁止**。変更は新しいマイグレーションの追加によって行う。 |
| `supabase/seed.sql` | **管理対象** | ローカル開発・テスト用ダミーデータのみ。本番データや個人情報は含めない。 |
| `supabase/.temp/`, `.branches/` | **管理外 (`.gitignore`)** | CLIの内部状態・一時ファイルのため除外。 |

---

### 3.5 GitHub Actions CI/CD による自動デプロイと PR 検証パイプライン

開発者のローカルPCから直接 `supabase db push` を実行することを禁止し、GitHub Actions パイプラインを介して自動検証・自動デプロイを行います。

#### ① リポジトリ Secret の登録
GitHub の `Settings -> Secrets and variables -> Actions` に以下を登録します：
- `SUPABASE_ACCESS_TOKEN`: Supabase Personal Access Token
- `SUPABASE_DB_PASSWORD`: 本番PostgreSQLデータベースの接続パスワード
- `SUPABASE_PROJECT_ID`: 本番プロジェクトの Reference ID

#### ② PR 自動検証ワークフロー (`.github/workflows/supabase_ci.yml`)
Pull Request 作成・更新時に自動起動し、マイグレーションの整合性、静的セキュリティ解析、RLSテストを検証します。

```yaml
name: Supabase CI (PR Validation)

on:
  pull_request:
    branches:
      - main
    paths:
      - 'supabase/**'

concurrency:
  group: supabase-ci-${{ github.ref }}
  cancel-in-progress: true

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout Repository
        uses: actions/checkout@v4

      - name: Setup Supabase CLI
        uses: supabase/setup-cli@v1
        with:
          version: latest

      - name: Start Local Supabase Stack
        run: supabase start

      - name: Verify Migration Replay (db reset)
        run: supabase db reset

      - name: Run Static Security & Performance Lint (db lint)
        run: supabase db lint

      - name: Run RLS Unit Tests (test db)
        run: supabase test db

      - name: Stop Supabase Stack
        if: always()
        run: supabase stop
```

#### ③ 本番自動デプロイワークフロー (`.github/workflows/supabase_deploy.yml`)
`main` ブランチへのマージをトリガーに、本番環境へ未適用のマイグレーションを順次安全適用します。

> **セキュリティ & 整合性注意 (`cancel-in-progress: false`)**: データベースのマイグレーション実行中にワークフローが途中キャンセルされると、DDLトランザクションが途中で分断され、本番DBのスキーマ状態と `schema_migrations` テーブルの記録が不可逆に不整合を起こします。そのため、**デプロイワークフローでは `cancel-in-progress: false` を絶対条件**とします。

```yaml
name: Deploy Supabase Migrations (Production)

on:
  push:
    branches:
      - main
    paths:
      - 'supabase/migrations/**'
  workflow_dispatch:

concurrency:
  group: supabase-deploy-${{ github.ref }}
  cancel-in-progress: false

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout Repository
        uses: actions/checkout@v4

      - name: Setup Supabase CLI
        uses: supabase/setup-cli@v1
        with:
          version: latest

      - name: Deploy Migrations to Supabase Production
        env:
          SUPABASE_ACCESS_TOKEN: ${{ secrets.SUPABASE_ACCESS_TOKEN }}
          SUPABASE_DB_PASSWORD: ${{ secrets.SUPABASE_DB_PASSWORD }}
          SUPABASE_PROJECT_ID: ${{ secrets.SUPABASE_PROJECT_ID }}
        run: |
          supabase link --project-ref $SUPABASE_PROJECT_ID
          supabase db push --password "$SUPABASE_DB_PASSWORD"
```

---

### 3.6 FlutterクライアントとDBのゼロダウンタイム同期 (Expand & Contract パターン)

本番稼働中のアプリケーションにおいて、ユーザー端末の旧バージョンFlutterアプリと新バージョンDBの互換性を保ちながらスキーマを変更するため、**Expand & Contract (Parallel Change) パターン**を適用します。

具体的な例として、`profiles` テーブルのカラム `old_username` を `new_display_name` に安全に移行するステップを示します。

```
  【Phase 1: Expand (拡張フェーズ)】
  DBに new_display_name カラムを NULL 許容で追加。
  Postgres トリガーにより旧・新カラムの双方向同期（Dual-Write）を開始。
            │
            ▼
  【Phase 2: Client Migration (移行フェーズ)】
  両方のカラム名を柔軟に読み書きできるFlutterアプリ（フォールバック実装）を各ストアに配信。
  バックグラウンドで既存データの全件移行 DML を実行。
            │
            ▼
  【Phase 3: Contract (収縮・削除フェーズ)】
  旧アプリの利用率が 0%（または強制アップデート完了）となった後、
  同期トリガーを削除し、旧カラム old_username を DROP。
```

#### ① Phase 1: Expand (拡張マイグレーション SQL)
`supabase/migrations/20260814100000_expand_display_name.sql`:

```sql
-- 1. 新カラムの追加 (NULL許容またはデフォルト値付き)
ALTER TABLE public.profiles ADD COLUMN new_display_name text;

-- 2. 双方向同期 (Dual-Write) 用トリガー関数の作成
CREATE OR REPLACE FUNCTION sync_profiles_display_name()
RETURNS TRIGGER AS $$
BEGIN
  -- Bi-directional synchronization for Expand phase
  IF NEW.new_display_name IS DISTINCT FROM OLD.new_display_name AND NEW.new_display_name IS NOT NULL THEN
    NEW.old_username := NEW.new_display_name;
  ELSIF NEW.old_username IS DISTINCT FROM OLD.old_username AND NEW.old_username IS NOT NULL THEN
    NEW.new_display_name := NEW.old_username;
  ELSIF NEW.new_display_name IS NULL AND NEW.old_username IS NOT NULL THEN
    NEW.new_display_name := NEW.old_username;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 3. BEFORE INSERT OR UPDATE トリガーの登録
CREATE TRIGGER trigger_sync_profiles_display_name
BEFORE INSERT OR UPDATE ON public.profiles
FOR EACH ROW EXECUTE FUNCTION public.sync_profiles_display_name();
```

#### ② Phase 2: Client Migration & Data Backfill (データ移行 SQL & Flutter 実装)
既存レコードのバックグラウンド移行 SQL:
`supabase/migrations/20260815100000_backfill_display_name.sql`:

```sql
-- 既存の未移行レコードを一括データ更新
UPDATE public.profiles
SET new_display_name = old_username
WHERE new_display_name IS NULL AND old_username IS NOT NULL;
```

Flutter / Dart 側のフォールバックモデル実装 (`lib/features/profile/domain/user_profile.dart`):

```dart
class UserProfile {
  final String id;
  final String displayName;

  UserProfile({
    required this.id,
    required this.displayName,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      // フォールバックチェーン: 新カラム -> 旧カラム -> デフォルト空文字 の順でパース
      displayName: (json['new_display_name'] as String?) ??
          (json['old_username'] as String?) ??
          '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      // 新規書き込みは新カラムに対して行う (DB側トリガーが旧カラムにも双方向コピー)
      'new_display_name': displayName,
    };
  }
}
```

#### ③ Phase 3: Contract (収縮・削除マイグレーション SQL)
旧アプリの移行完了を確認後、マイグレーションを追加投入して旧カラムを削除します。
`supabase/migrations/20260901100000_contract_old_username.sql`:

```sql
-- 1. 不要となった同期トリガーおよび関数の削除
DROP TRIGGER IF EXISTS trigger_sync_profiles_display_name ON public.profiles;
DROP FUNCTION IF EXISTS public.sync_profiles_display_name();

-- 2. 旧カラムの安全な削除
ALTER TABLE public.profiles DROP COLUMN old_username;

-- 3. (必要に応じて) 新カラムへ NOT NULL 制約の付与
ALTER TABLE public.profiles ALTER COLUMN new_display_name SET NOT NULL;
```

---

## 4. 要件R3: 本番データの保護・運用ベストプラクティス

### 4.1 本番 Dashboard 手動操作の禁止とスキーマドリフト防止

#### スキーマドリフト (Schema Drift) の脅威
Supabase Dashboard (Web画面) で直接テーブル追加やRLS変更を行うと、Git上のマイグレーション履歴 (`supabase/migrations/`) と本番DBの間に整合性のズレ（スキーマドリフト）が生じます。この状態で CI/CD や `supabase db push` を実行すると、不整合によるデプロイクラッシュや意図しないデータ損壊の原因となります。

#### 予防策・運用ルール:
1. **本番 Dashboard での DDL 変更を完全禁止**: テーブル、カラム、RLS、関数、インデックスの追加・変更は必ずローカルマイグレーションとして記述する。
2. **本番アクセスの権限分離**: 開発者に本番DBの直接書き込み権限（DDL権限）を与えず、CI/CDサービスアカウントのみにデプロイ権限を集中させる。

---

### 4.2 スキーマドリフト発生時の復旧手順 (Schema Drift Recovery)

万が一、緊急障害対応等で本番 Dashboard から手動 DDL 変更が行われ、スキーマドリフトが発生した場合の復旧プロトコルです。

1. **ドリフト内容の抽出 (`supabase db pull`)**:
   本番環境の最新スキーマをローカルの別ディレクトリまたは一時ブランチに抽出します：
   ```bash
   supabase db pull --linked
   ```
2. **差分比較と手動統合 (Reconciliation)**:
   生成された DDL と、Git 管理下のマイグレーション群を比較し、手動で行われた DDL 変更箇所（例: `CREATE INDEX ...` や `ALTER TABLE ...`）を特定します。
3. **新規マイグレーション化**:
   手動変更された DDL を新しいマイグレーションファイル (`supabase/migrations/<NEW_TIMESTAMP>_fix_drift.sql`) として書き起こし、Git にコミットします。
4. **マイグレーション履歴のリペア**:
   すでに本番に反映済みの手動変更であるため、リペアコマンドで適用済みとして記録します：
   ```bash
   supabase migration repair --status applied <NEW_TIMESTAMP>
   ```

---

### 4.3 Supabase Database Branching と PR プレビュー環境

Supabase の **Database Branching** 機能（GitHub連携）を活用することで、GitHubで Pull Request（PR）を作成するたびに完全隔離された使い捨てのプレビューDBインスタンスが自動生成されます。

#### 利点と動作フロー:
- PR作成時、本番データに影響を与えない独立したプレビューDBが立ち上がり、PR内のマイグレーションおよび `seed.sql` が自動適用される。
- レビュアーやQA担当者は、PR段階で実機アプリやローカルからプレビューDBに接続し、動作やRLSの安全性を確認可能。
- PRのマージまたはクローズに伴い、プレビュー環境は自動削除されるためコスト管理も容易。

---

### 4.4 本番データの隔離と PII (個人情報) の保護

本番環境のデータベースをローカルにダンプして持ち込む行為は、以下のリスクがあるため固く禁止します：
- 顧客個人情報（PII: Personally Identifiable Information）の漏洩リスク。
- 本番接続とローカル接続の誤認によるデータ破壊事故。

#### 隔離ルール:
1. **ローカルおよびCI環境**: `supabase/seed.sql` で生成した完全に匿名化されたモックデータのみを使用する。
2. **Stagingでの大規模データ検証**: どうしても本番規模のデータでパフォーマンス検証を行う場合は、`postgresql-anonymizer` 等で個人情報をハッシュ化・無効化した「無害化ダンプ」を作成してStaging環境にのみ投入する。

---

### 4.5 事前自動検証 (CI リンティング & テスト)

プルリクエスト（PR）のCIパイプラインで以下の検証を自動実行し、不良マイグレーションの本番流入を遮断します。

#### ① マイグレーション再構築テスト (`supabase db reset`)
空のデータベースに対し、マイグレーションが最初からエラーなく再構築できることを自動検証します。

#### ② 静的セキュリティ・パフォーマンス解析 (`supabase db lint`)
Supabase CLI 内蔵の静的解析エンジン (`splinter`) により以下を検出します：
- RLS（Row Level Security）が有効化されていないパブリックテーブルの自動検出
- 外部キーに対するインデックスの欠如（パフォーマンス悪化原因）の指摘
- セキュリティリスクのある関数定義の警告

#### ③ RLS ユニットテスト (`supabase test db` / pgTAP)
`pgTAP` テストフレームワークを使用し、匿名ユーザー (`anon`) や認証ユーザー (`authenticated`) のロールをシミュレートしたアクセス制御テストを実行します。

`supabase/tests/database/rls_test.sql` の実装例：
```sql
BEGIN;
SELECT plan(2);

-- anon ロールでは profiles テーブルへのアクセスが拒否されることを検証
SET LOCAL ROLE anon;
SELECT is_empty(
  'SELECT * FROM public.profiles',
  'Anon user should not be able to read profiles'
);

-- authenticated ロールでは自身のプロフィールのみ参照可能であることを検証
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "11111111-1111-1111-1111-111111111111"}';
SELECT results_eq(
  'SELECT username FROM public.profiles WHERE id = ''11111111-1111-1111-1111-111111111111''',
  ARRAY['devuser'],
  'Authenticated user can read own profile'
);

SELECT * FROM finish();
ROLLBACK;
```

---

### 4.6 災害復旧 (Disaster Recovery) 戦略

#### ① ポイントインタイムリカバリ (PITR) の有効化
Supabase Proプラン以上で提供される **Point-in-Time Recovery (PITR)** を本番環境で有効化します。
- WAL (Write-Ahead Logging) の継続的アーカイブにより、誤ったデータ削除や障害発生直前（1秒精度）の任意時点へデータベースを秒単位で復元可能です。
- ※ 注意: PITRはPostgreSQLデータベースのみを復元対象とします。StorageのファイルやEdge Functions、環境変数は別途バックアップ管理が必要です。

#### ② Forward-Fix (前進修正) 戦略の採用
障害発生時、過去の変更を打ち消す「Downマイグレーション」の実行は、データ整合性の衝突により失敗するリスクが高くなります。
障害時は、**問題箇所を修正・リカバリする新たなマイグレーションを追加投入する「Forward-Fix (前進修正) 戦略」を基本方針**とします。

---

## 5. コマンドチートシート & 検証チェックリスト

### 5.1 Supabase CLI コマンドチートシート

| カテゴリ | コマンド | 説明 |
| :--- | :--- | :--- |
| **環境構築** | `supabase init` | プロジェクト初期化（`config.toml`, `seed.sql`, `migrations/` 生成） |
| **認証・リンク** | `supabase login` | Supabase CLI へのログイン（Personal Access Token保存） |
| | `supabase link --project-ref <id>` | ローカル環境を特定の本番/Stagingプロジェクトに紐付け |
| **サービス管理** | `supabase start` | ローカルSupabaseスタック（Dockerコンテナ群）を起動 ※`db pull`の前に必須 |
| | `supabase status` | ローカルエンドポイントURL、APIキー、ポート情報の表示 |
| | `supabase stop` | ローカルSupabaseスタックの停止 |
| **スキーマ取得** | `supabase db pull` | リモート本番DBのスキーマを抽出してベースラインマイグレーション作成 |
| | `supabase migration repair --status applied <TS>` | ベースラインマイグレーションを本番DBで「適用済み」として記録（`push`の衝突防止） |
| **マイグレーション**| `supabase db diff -f <name>` | ローカルDBの変更差分をマイグレーションSQLとして出力 |
| | `supabase migration new <name>` | 手動SQL記述用の空マイグレーションファイルを生成 |
| | `supabase db reset` | ローカルDB破棄・全マイグレーション再適用・`seed.sql` 自動実行 |
| | `supabase migration list` | ローカルとリモートのマイグレーション適用状態およびタイムスタンプ比較 |
| **デプロイ・検証**| `supabase db push` | 未適用のマイグレーションを本番環境へ順次安全適用 |
| | `supabase db lint` | PostgreSQLのセキュリティ・パフォーマンス静的解析の実行 |
| | `supabase test db` | `pgTAP` によるデータベース/RLSユニットテストの実行 |

---

### 5.2 独立検証チェックリスト (Verification Checklist)

#### 1. ローカル初期化チェック (`R1`)
- [ ] `docker info` が正常にレスポンスを返す（Dockerサービス稼働中）。
- [ ] `supabase init` により `supabase/config.toml` が作成されている。
- [ ] `supabase link --project-ref <id>` で本番プロジェクトと連携済みである。
- [ ] `supabase start` を `supabase db pull` より前に実行している。
- [ ] `supabase db pull` で生成されたベースラインマイグレーションに対し、`supabase migration repair --status applied <TIMESTAMP>` を実行して記録済みである。
- [ ] `supabase start` 実行後、`http://127.0.0.1:54323` でローカルStudioにアクセスできる。
- [ ] `supabase/seed.sql` 先頭に事故防止ガード処理があり、`auth.users` / `auth.identities` のモックユーザーが定義されている。
- [ ] `supabase db reset` がエラーなく正常完了する。
- [ ] Flutterアプリから `http://10.0.2.2:54321` (Android) または `http://127.0.0.1:54321` (iOS/Web) 経由でローカルSupabaseに接続できる（Androidで `usesCleartextTraffic="true"` 設定済み）。

#### 2. マージ・デプロイフローチェック (`R2`)
- [ ] ローカルで追加したテーブル/カラムが `supabase db diff -f` または `supabase migration new` でSQLマイグレーション化されている。
- [ ] 複数人開発時のマイグレーションタイムスタンプ衝突回避ルール（`supabase migration list` + rebaseリネーム）が定義されている。
- [ ] 新規マイグレーション作成後、`supabase db reset` でクリーン環境での再構築性が確認されている。
- [ ] `supabase/migrations/*.sql` および `supabase/config.toml` がGitコミット対象になっている。
- [ ] 一度 `main` ブランチにマージされた過去のマイグレーションファイルが書き換え・削除されていない。
- [ ] 破壊的変更（カラム削除・改名）を行う場合、Expand & Contract パターンのフェーズ（SQLトリガー・DML・Flutterフォールバックパース・Contract SQL）を満たしている。
- [ ] GitHub Actions に PR 検証ワークフロー (`supabase_ci.yml`) と本番デプロイワークフロー (`supabase_deploy.yml`, `cancel-in-progress: false`, `setup-cli@v1`) が正しく定義されている。

#### 3. 本番データ保護チェック (`R3`)
- [ ] 本番Supabase Dashboardでの直接的なテーブル・RLS編集を行っていない。
- [ ] 万が一のスキーマドリフト発生時の復旧プロトコル（`db pull --linked` & `migration repair`）が準備されている。
- [ ] 本番データベースの顧客データ（PII）がローカルの `seed.sql` に混入していない。
- [ ] PR作成時に `supabase db lint` による静的解析エラーが発生していない。
- [ ] `supabase test db` (pgTAP) によりRLSアクセス制御が正常系・異常系ともにテストされている。
- [ ] 本番プロジェクトで PITR (Point-in-Time Recovery) が有効化されている。
