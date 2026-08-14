# R3 (本番データ保護・安全対策・運用のベストプラクティス) 調査レポート

## 概要
本レポートは、Flutter × Supabase プロジェクトにおいて、既にユーザーが存在し稼働している本番環境のデータを破壊せず、安全に開発〜デプロイを行うための運用ベストプラクティスおよび技術的対策を調査・整理したものです。

---

## 1. Observation（観察・確認事実）

Supabase公式ドキュメントおよびPostgreSQL運用ベストプラクティス調査により以下の事実を確認しました：

1. **Dashboard手動変更とスキーマドリフト (Schema Drift)**
   - Supabase Dashboardで直接テーブルやカラムを変更すると、ローカルのマイグレーション履歴 (`supabase/migrations/`) と本番DBの間に差分（スキーマドリフト）が生じる。
   - スキーマドリフトが発生した状態で `supabase db push` や CI/CD を実行すると、意図しない競合やマイグレーション失敗、データ破損の原因となる。

2. **破壊的マイグレーションとモバイルアプリ (Flutter) のライフサイクル**
   - Webアプリと異なり、Flutterなどのモバイルアプリはユーザーの端末上に旧バージョンが残存する。
   - `DROP COLUMN` や `RENAME COLUMN` を直接実行すると、旧バージョンのアプリからAPIリクエストが送られた際に即座に実行時エラー (`column "x" does not exist`) が発生する。

3. **Supabase Database Branching 機能**
   - GitHub連携を有効にすることで、PR (Pull Request) ごとに完全に隔離されたプレビュー用Supabaseインスタンス/DBブランチが自動生成される。
   - プレビューブランチは本番データを引き継がず空の状態で起動し、`supabase/seed.sql` が自動適用される。PRマージ/クローズ時に自動削除される。

4. **静的検証・リンティング (`supabase db lint`)**
   - Supabase CLIの `supabase db lint` は内部的に `splinter` (Postgres linter) を使用し、RLSが有効化されていないテーブルやAPI露出のリスク、インデックスの欠如などを自動検出する。

5. **ポイントインタイムリカバリ (PITR)**
   - WAL (Write-Ahead Logging) アーカイブを WAL-G を用いて継続的にストレージに保存し、秒単位 (1秒精度) で任意の過去の時点へリカバリ可能。
   - PITRはデータベースのみが対象であり、Storageバケット、Edge Functions、環境変数のプロジェクトシークレットは復元対象外。

6. **RLSテストとローカルAuthエミュレーション**
   - ローカル開発環境 (`supabase start`) では GoTrue (Auth) および Inbucket (ローカルSMTP) が動作し、本番Authプロバイダに影響を与えずに認証フローをテスト可能。
   - `supabase test db` コマンドで pgTAP テストを実行でき、`authenticated` や `anon` ロールをシミュレートしてRLSポリシーの正常系・異常系（アクセス拒否）を検証可能。

---

## 2. Logic Chain（理論的推論プロセス）

以上の観察事実に基づき、本番データ保護のための論理的ガイドラインを導出しました。

### ① スキーマドリフト防止とCI/CDによるデプロイ統制
- **推論**: 本番環境での手動SQL実行やDashboard操作を禁止し、「コードファースト（`supabase/migrations/*.sql`）」とGitバージョン管理に一元化することで、環境間の不整合を完全に排除できる。
- **手段**: 
  - ローカルで `supabase migration new <name>` を実行。
  - GitHub Actions 等の CI/CD パイプライン（`supabase/setup-cli`）経由で `main` ブランチマージ時にのみ本番へ `supabase db push` (または `supabase migration up`) を実行する。

### ② Flutterクライアントの互換性を保つ Expand-Contract パターン（ゼロダウンタイム）
- **推論**: Flutterアプリの旧バージョンがストア上に存在するため、単一のSQLで破壊的変更を行ってはならない。段階的リファクタリング（Expand-Contract）が必須。
- **具体的な3フェーズ戦術**:
  1. **Expand (拡張)**: 新しいカラムやテーブルを追加（NULL許可またはデフォルト値付き）。DBトリガーまたはAppで旧・新双方に二重書き込みを実施。
  2. **Migrate & Shift (移行・更新)**: バックグラウンドで既存データを移行。Flutterアプリのアップデート版をリリースし、参照・更新を新カラムへ切り替える。
  3. **Contract (縮小・削除)**: 旧アプリの利用率がアクティブユーザーの閾値（例: 99%移行完了）以下になった後、別マイグレーションで旧カラム・トリガーを削除 (`DROP COLUMN`)。

### ③ モックシードデータ戦略による本番データ漏洩・破壊の遮断
- **推論**: 本番データをローカル開発環境にダンプして持ち込むと、個人情報（PII）の漏洩リスクおよびローカルでの誤操作（本番接続と誤認した破壊）のリスクが生じる。
- **対策**:
  - ローカル開発およびPRプレビュー環境では、完全に匿名化された開発用ダミーデータ (`supabase/seed.sql`) のみを使用する。
  - どうしても本番相当のデータ規模でパフォーマンス検証を行う場合は、`postgresql-anonymizer` 等で個人情報をマスキングした無害化ダンプを作成して staging 環境に投入する。

### ④ 事前検証（CIでの自動化テスト）
- **推論**: デプロイ前にマイグレーションファイルの文法・再構築可能性・セキュリティの脆弱性を自動検証することで、本番デプロイ失敗や障害を未然に防ぐ。
- **検証項目**:
  - `supabase db reset`: マイグレーションを最初から順番に適用してロールバック・再現性を確認。
  - `supabase db lint`: RLS欠落やセキュリティ・パフォーマンス違反をチェック。
  - `supabase test db`: pgTAPによるRLSポリシーテストを実施。

### ⑤ PITRと災害復旧 (Disaster Recovery) の備え
- **推論**: 万が一、誤ったデータ更新やマイグレーション事故が発生した場合の最終防衛線としてリカバリ手段を確立する。
- **運用の鉄則**:
  - 本番プロジェクトでは PITR (Point-in-Time Recovery) を有効化（Proプラン以上）。
  - 大規模またはリスクの高いマイグレーション実行直前には、手動バックアップ (`supabase db dump`) を念のため取得する。
  - マイグレーションの「Down (ロールバックSQL)」スクリプトに過度に依存せず、本番障害発生時は「Forward-Fix (修正マイグレーションの追加適用)」を基本方針とする（データ状態のズレによるDown失敗を防ぐため）。

---

## 3. Caveats（注意事項・制約事項）

1. **PITRの適用範囲制限**: PITRはPostgreSQLデータベースのみを復元します。Supabase Storage内のファイル、Edge Functions、Dashboardで設定したシークレット（環境変数）は復元されません。これらは別途バックアップ/Git管理が必要です。
2. **PostgreSQLのロック制御**: 大規模テーブル（数百万件以上）への `ALTER TABLE` や `ADD FOREIGN KEY` はテーブルロック（AccessExclusiveLock）を引き起こす可能性があります。インデックス作成時は `CREATE INDEX CONCURRENTLY` を使用するなどの考慮が必要です。
3. **Supabase CLI / Branchingのプラン制限**: Supabase Branching 機能は組織のプランや設定によってブランチ数制限や従量課金が発生する場合があります。
4. **Authの外部プロバイダテスト**: Apple AuthやGoogle AuthなどサードパーティOAuthは、ローカル開発環境では直接テストしにくいため、モック認証またはテスト用Firebase/Supabaseプロジェクトを別途用意してテストする必要があります。

---

## 4. Conclusion（結論・推奨運用仕様）

### R3における本番データ保護・運用ベストプラクティス まとめ表

| 項目 | アンチパターン (禁止事項) | 推奨プラクティス (ベストプラクティス) |
| :--- | :--- | :--- |
| **デプロイ方式** | Dashboardでの手動SQL実行、ローカルからの直接 `db push` | Git管理＋GitHub ActionsによるCI/CDデプロイ (`supabase/setup-cli`) |
| **DB変更** | `DROP COLUMN` や `RENAME COLUMN` の即時実行 | **Expand-Contract パターン**（拡張→移行→収縮）の3段階運用 |
| **開発・検証データ** | 本番DBの直接ダンプをローカルで使用 | 決定論的モックデータ (`supabase/seed.sql`) またはマスキング済ダンプ |
| **PR/機能検証** | 共有Staging DBへの手動変更 | **Supabase Branching** によるPR単位の使い捨てプレビュー環境 |
| **事前チェック** | 目視によるSQL確認のみ | `supabase db lint` + `supabase test db` (pgTAP) をCIで自動化 |
| **データ復旧準備** | 日次バックアップのみに依存 | **PITR (ポイントインタイムリカバリ)** 有効化＋重大変更前の手動ダンプ |
| **RLS/Auth検証** | 本番プロジェクトでの権限確認 | ローカルAuthエミュレータ＋ `pgTAP` による権限テストの自動化 |

---

## 5. Verification Method（独立検証手順）

以下の手順で上記プラクティスが正しく機能するかローカル環境およびCI上で検証できます。

1. **ローカルリンティング & マイグレーションテスト**:
   ```bash
   # マイグレーション履歴の完全再構築検証
   supabase db reset
   
   # スキーマセキュリティ・パフォーマンスの静的解析
   supabase db lint
   
   # pgTAPによるRLSユニットテストの実行
   supabase test db
   ```

2. **マイグレーション差分の比較**:
   ```bash
   # リモート(本番/Staging)とのマイグレーション適用状況の確認
   supabase migration list
   ```

3. **Expand-Contract パターンの検証**:
   - `supabase/migrations/` に `add_column` マイグレーションを作成し `supabase db reset` で適用。
   - シードデータが正常に投入され、旧カラムと新カラムが共存していることを確認。
