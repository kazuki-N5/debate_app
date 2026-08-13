# Handoff Report — challenger_1

**Verdict**: **REQUEST_CHANGES (修正要求)**

`SUPABASE_LOCAL_DEV_GUIDE.md` に対する敵対的検証 (Adversarial Challenge & Stress-Test) を実施した結果、実際に運用した際に環境構築の失敗、本番デプロイのクラッシュ、CI/CDパイプラインの失敗を引き起こす重大な欠陥および不整合が複数発見されました。以下の指摘事項を修正することを要求します。

---

## 1. Observation (直接的な観測事実)

1. **`supabase db pull` と `supabase start` の実行順序逆転**
   - 該当箇所: 2.3節（137-142行目）および 2.4節（153-156行目）
   - 記述内容: 2.3節で `supabase db pull` を実行した後、2.4節で `supabase start` を実行する順序になっている。
   - エラー動作: `supabase db pull` はローカルの Docker PostgreSQL コンテナ（シャドウDB）を起動して差分を抽出するため、事前に `supabase start` が実行されていない環境では `Error: supabase start is not running` を返して即座に異常終了する。

2. **本番ベースライン記録 (`supabase migration repair`) の欠落**
   - 該当箇所: 2.3節（137-150行目）および 3.4節（372-380行目）
   - 記述内容: 本番から取得した `<TIMESTAMP>_remote_schema.sql` をローカルに保存する手順のみが記載され、リモート本番環境へのベースライン登録手順が記載されていない。
   - エラー動作: 初回の本番 CI/CD (`supabase db push`) 実行時、リモート本番DBの `supabase_migrations.schema_migrations` に `<TIMESTAMP>_remote_schema.sql` が記録されていないため、CI/CDが本番環境に対して同ファイルを再実行しようとし、`ERROR: relation "..." already exists` でデプロイがクラッシュする。

3. **GitHub Actions ワークフローにおける存在しないアクションバージョンの指定とフラグ不備**
   - 該当箇所: 3.4節 368行目および378行目
   - 記述内容: `uses: supabase/setup-cli@v3` および `supabase link --project-ref $SUPABASE_PROJECT_ID`
   - エラー動作:
     - `supabase/setup-cli` に `@v3` タグは存在せず（公式は `@v1`）、GitHub Actions 実行時に `Action not found` エラーが発生する。
     - 非対話型 CI 環境での `supabase link` 実行時、`--password` オプションまたは非対話用パラメータが不足しており、認証プロンプトでハングするか失敗するリスクがある。

4. **PR検証用 CI ワークフロー (`pull_request`) の未定義**
   - 該当箇所: 4.4節（444-483行目） vs 3.4節（345-380行目）
   - 記述内容: 4.4節で「PR時に `supabase db reset`, `supabase db lint`, `supabase test db` を自動実行して検証する」と記述されているが、3.4節の YAML は `on: push: branches: [main]` のみである。
   - 影響: 本文で強調されている PR 時の自動検証用ワークフローファイルがドキュメント内に存在しないため、開発者が CI を構築できない。

5. **スキーマドリフト発生時の復旧手順の欠落**
   - 該当箇所: 4.1節（412-418行目）
   - 記述内容: スキーマドリフトの概念と禁止ルールは書かれているが、万が一Dashboard操作等でドリフトが発生した場合の回復コマンド手順が一切記載されていない。

6. **Flutter SDK API の非互換パラメータ**
   - 該当箇所: 2.6節 262行目
   - 記述内容: `await Supabase.initialize(url: url, anonKey: anonKey, debug: kDebugMode);`
   - エラー動作: `supabase_flutter` v2.x 以降において `debug` パラメータは `Supabase.initialize` の引数から削除・非推奨となっており、コンパイルエラーまたは警告が発生する。

7. **クリーンアーキテクチャにおけるデータソース・リポジトリ層のコード欠落**
   - 該当箇所: 2.6節（234-266行目）
   - 記述内容: `SupabaseConfig` クラスによる初期化コードのみで、アプリ層やデータソース層で `SupabaseClient` をどのように注入・利用すべきかのパターンが示されていない。

---

## 2. Logic Chain (論理的推論)

1. **実行順序エラーの論理**:
   - 観測: `supabase db pull` (2.3) -> `supabase start` (2.4)
   - 推論: CLI仕様上 `supabase db pull` はローカルコンテナ環境に依存する。依存対象が起動する前に実行を指示しているため、開発者がガイド通りに実行すると100%ステップ2.3で失敗する。

2. **ベースライン欠落の論理**:
   - 観測: `db pull` 後に `migration repair` なしで `db push` を実行
   - 推論: `supabase db push` は「ローカルにあってリモートの `schema_migrations` にないマイグレーション」を全て実行しようとする。初期プルした巨大なスキーマが未適用と判定され、稼働中の本番DBにDDLが再実行されて衝突・ダウンを引き起こす。

3. **CI/CD 記述不備の論理**:
   - 観測: `setup-cli@v3` の記述
   - 推論: 存在しない Action バージョンを指定しているため、CIパイプラインのファーストフックで即座にエラー停止する。

4. **PR検証欠落の論理**:
   - 観測: 4.4節の仕様に対して 3.4節の YAML に `pull_request` トリガーおよびテストステップが存在しない
   - 推論: 仕様書としての整合性が破綻しており、開発者がそのまま導入した場合にPRの保護機能が働かない。

---

## 3. Caveats (留意事項・考慮した代替解釈)

- **Supabase CLIのバージョン相違**: 今後の CLI アップデートで `supabase db pull` が完全スタンドアロン化される可能性は否定できませんが、現行のすべての主要バージョンにおいてローカルコンテナ（または Docker）が必須です。
- **Database Branching の利用時**: Supabase Proの Database Branching を利用する場合、本番への直接 `db push` ではなく Branch マージフローが適用される場合がありますが、本ガイドでは標準的な GitHub Actions + `supabase db push` フローを記述対象としているため、上記の指摘がそのまま当てはまります。

---

## 4. Conclusion (結論・判定)

**判定: REQUEST_CHANGES (修正要求)**

`SUPABASE_LOCAL_DEV_GUIDE.md` は概念的なベストプラクティスの説明としては優れているものの、**記載されているコマンド手順をそのまま実行するとローカル構築がエラーで停止し、CI/CDデプロイが本番環境でクラッシュする致命的な問題**を含んでいます。

以下の修正を行った上で再提出してください：
1. **2.3節と2.4節の順序入れ替え**: `supabase start` を先に実行してから `supabase db pull` を行う手順に変更。
2. **`supabase migration repair` の追加**: `supabase db pull` 実行後、リモート本番環境に対して `<TIMESTAMP>` を applied として記録するコマンドを明記。
3. **GitHub Actions YAML の修正**: `setup-cli@v1` への変更、`--password` または `db push` への統合。
4. **PR検証用 CI ワークフローの追加**: `.github/workflows/supabase_ci.yml` (PRトリガーで `reset`, `lint`, `test db` を行う YAML) の新設。
5. **スキーマドリフト復旧手順の追加**: 万が一のドリフト発生時の修復コマンドの記載。
6. **Flutter `Supabase.initialize` の修正**: `debug: kDebugMode` の削除と `SupabaseClient` の注入例の追加。

---

## 5. Verification Method (検証方法)

以下の手順で上記指摘事項を再現・検証できます：

1. **手順順序検証**:
   - Docker環境で `supabase init` -> `supabase link` 実行後、`supabase start` を実行せずに `supabase db pull` を実行する。
   - **期待される失敗結果**: `Error: supabase start is not running...`

2. **本番ベースライン検証**:
   - `supabase db pull` で生成された `migrations/<TIMESTAMP>_remote_schema.sql` を保持した状態で、`supabase migration repair` を実行せずに `supabase db push` をターゲットDBに試行する。
   - **期待される失敗結果**: 既存テーブルに対する `relation "..." already exists` エラー。

3. **GitHub Actions 検証**:
   - `.github/workflows/supabase_deploy.yml` の `uses: supabase/setup-cli@v3` を含むリポジトリを push する。
   - **期待される失敗結果**: GitHub Actions タブで `Unable to resolve action supabase/setup-cli@v3` エラー。

4. **Flutter コード検証**:
   - `supabase_flutter: ^2.0.0` を設定した Flutter プロジェクトで `Supabase.initialize(url: '...', anonKey: '...', debug: true);` を記述し `flutter analyze` を実行する.
   - **期待される失敗結果**: `The named parameter 'debug' isn't defined` コンパイルエラー。
