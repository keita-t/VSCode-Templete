# VSCode Project Template Setup - AI コーディング支援用ドキュメント

## プロジェクト概要

これは、VSCodeプロジェクト設定をGitHubからダウンロードして任意のプロジェクトディレクトリに適用する**テンプレート配布システム**です。VSCodeプロジェクト設定専用の「dotfilesマネージャー」と考えてください。

**コアコンセプト**: ユーザーが`./vscode-project-startup.sh <template-name>`を実行すると、`templates/`ディレクトリからテンプレートファイル（settings.json、.gitignoreなど）をダウンロードしてプロジェクトにマージします。

## アーキテクチャと主要コンポーネント

### メインスクリプト: vscode-project-startup.sh

**設定駆動設計**: スクリプトはBashの連想配列を通じて高い拡張性を持ちます。新しいテンプレートはデフォルトマッピングで自動的に動作し、カスタムマッピングは`<TEMPLATE>_FOLDER_MAPPING`配列を宣言することで追加できます。

**重要なマッピング** (31-63行目):
- `DEFAULT_FOLDER_MAPPING`: テンプレートのサブディレクトリをプロジェクト内の場所にマップ
  - `vscode/` → `.vscode/` (VSCode設定)
  - `git/` → `.` (プロジェクトルート、.gitignore用)
  - `config/` → `.` (.editorconfigなど用)
- `DEFAULT_MERGE_SETTING`: マージするファイルのパターン（上書きしない）: `*.json`, `*.code-snippets`
- テンプレート固有のマッピング: 例）`PYTHON_FOLDER_MAPPING`は`docs/`と`tests/`ディレクトリを追加

**JSONマージ戦略** (368-383行目): 既存プロジェクトを更新する際、`jq`を使用してJSONファイルを深くマージします。これにより既存設定を失わずに段階的な更新が可能です。`jq`が利用できない場合は単純上書きにフォールバックします。

### テンプレート構造

```
templates/
├── base/           # すべてのプロジェクト用の汎用設定
├── python/         # baseを拡張するPython固有設定
└── docker/         # Docker固有の設定
```

**レイヤリングパターン**: テンプレートは組み合わせて使用するよう設計されています。`./vscode-project-startup.sh base python`を実行すると、最初にbaseを適用し、次にPython固有のオーバーライドを適用します。後から指定したテンプレートが優先されます。

## 開発ワークフロー

### テスト

**2段階テスト戦略**:

1. **ローカルテスト** (推奨): `./test/manual/test-local-templates.sh`
   - ローカルの`templates/test`を使用して高速テスト（GitHubアクセス不要）
   - VS Codeタスクから実行: "Run Local Tests"（デフォルトテストタスク）
   - **カバレッジ**: ファイル配置ロジック、JSONマージ、ディレクトリ構造

2. **GitHub統合テスト**: `./test/manual/test-github-download.sh`
   - GitHub APIを使用した実際のダウンロードをテスト
   - VS Codeタスクから実行: "Run GitHub Tests"
   - **カバレッジ**: GitHub API認証、ダウンロード、テンプレートディレクトリオプション

### 新しいテンプレートの追加

1. 標準サブディレクトリ（vscode/、git/、config/）を持つ`templates/<name>/`ディレクトリを作成
2. 適切なサブディレクトリにファイルを追加
3. （オプション）デフォルトが合わない場合、スクリプトにカスタムマッピングを追加:
   ```bash
   declare -A MYTEMPLATE_FOLDER_MAPPING=(["special"]="custom/path")
   ```
4. 一時ディレクトリで`./vscode-project-startup.sh mytemplate`を実行してテスト

## プロジェクト固有の規約

### 設定優先のアプローチ

- **ハードコードされたパスなし**: すべてのファイル配置はマッピング配列によって駆動
- **デフォルト優先設計**: 新しいテンプレートは設定なしですぐに動作
- **Bash連想配列**: 柔軟な設定のために広範囲に使用（Bash 4+が必要）

### ファイル命名パターン

- テンプレートはサブディレクトリ名（`vscode/`、`git/`）を使用して配置先を示す
- 個別ファイルは`<TEMPLATE>_FILE_MAPPING`で上書き可能（例：`requirements.txt` → プロジェクトルート）

### カラー出力

- 緑（✓）: 成功
- 黄（!）: 警告またはマージ操作
- 赤（✗）: エラー
- 青: 情報ヘッダー

スクリプトの先頭で定義されたANSIカラーコードを使用（14-17行目）。

### JSONマージの詳細

対象ファイルが存在し、`DEFAULT_MERGE_SETTING`パターンに一致する場合:
1. タイムスタンプ付きバックアップを作成: `filename.backup.20260201_123045`
2. `jq -s '.[0] * .[1]'`を使用して深くマージ（競合時は右側が優先）
3. `jq`がない場合は上書きにフォールバック（警告付き）

## 統合ポイント

- **GitHub API**: `https://api.github.com/repos/${GITHUB_USER}/${REPO_NAME}/contents/`を使用してファイルをリスト
- **GitHub Raw**: `https://raw.githubusercontent.com/${GITHUB_USER}/${REPO_NAME}/${BRANCH}/`経由でダウンロード
- **依存関係**:
  - `curl`（必須）: ファイルダウンロード
  - `jq`（オプション）: JSONマージ
  - プライベートリポジトリの場合: `GITHUB_TOKEN`（環境変数、.github_token、または~/.config/vscode-templates/token）

## 重要な設定

**初回使用前に必ず設定**（37行目）:
```bash
GITHUB_USER="keita-t"  # 実際のGitHubユーザー名に変更
```

これがないとGitHub APIコールが失敗します（リポジトリが見つからない）。

### GitHub Token設定（プライベートリポジトリの場合）

**優先順位**: 環境変数 > .github_token > ~/.config/vscode-templates/token

**方法1: 外部ファイル（推奨）**
```bash
# プロジェクトローカル
echo 'github_pat_xxxxx' > .github_token
chmod 600 .github_token

# グローバル設定
mkdir -p ~/.config/vscode-templates
echo 'github_pat_xxxxx' > ~/.config/vscode-templates/token
chmod 600 ~/.config/vscode-templates/token
```

**方法2: 環境変数**
```bash
export GITHUB_TOKEN="github_pat_xxxxx"
```

## よくある落とし穴

1. **大文字小文字の区別**: テンプレート名は大文字小文字を区別しますが、変数検索時は大文字に変換されます（`python` → `PYTHON_FOLDER_MAPPING`）
2. **マッピングの優先順位**: ファイルマッピングは特定ファイルについてフォルダマッピングを上書き
3. **複数テンプレート**: 順序が重要 - 後から指定したテンプレートが優先
4. **Bashバージョン**: 連想配列のためにBash 4+が必要（`bash --version`で確認）
5. **JSONマージにはjqが必要**: マージ機能のために`brew install jq`または`apt-get install jq`でインストール
6. **テンプレートディレクトリオプション**: `-d`または`--template-dir`で代替ディレクトリを指定可能（テスト用に便利）

## 変更時の注意

- **テンプレートサポートの追加**: 設定セクション（20-91行目）を編集、メインロジックはほとんど変更不要
- **テストは必須**: マッピングロジックへの変更後はテストを実行
- **後方互換性の維持**: デフォルトマッピングは既存テンプレートで動作する必要がある
- **ドキュメント更新**: 新機能追加時はREADME.mdとこのファイルを更新

## プロジェクト構造の変更履歴

- 2026年2月1日: `templete/` → `templates/`にリネーム（正しいスペル）
- 2026年2月1日: `test-templete/` → `templates/test/`に移動（論理的な配置）
- 2026年2月1日: ドキュメントを`docs/`ディレクトリに集約
