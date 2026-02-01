# テストディレクトリ

このディレクトリには、`vscode-project-startup.sh` スクリプトの統合テストが含まれています。

## ディレクトリ構造

```
test/
├── README.md                        # このファイル
└── manual/
    ├── test-local-templates.sh     # ローカルテスト（GitHubアクセス不要）
    └── test-github-download.sh     # GitHubダウンロード統合テスト
```

## テストの種類

### 1. ローカルテスト（推奨）

**ファイル**: `manual/test-local-templates.sh`

**目的**: ローカルの`test-templete`を使用して高速にテスト（GitHubアクセス不要）

**テストケース**:

1. **simple テンプレート配置**: ローカルファイルを直接配置
2. **advanced テンプレート配置**: 異なる設定値の確認
3. **複数テンプレート適用**: simple → advanced の上書き順序
4. **JSONマージ**: 既存ファイルとのマージとバックアップ
5. **ディレクトリ構造検証**: 完全な構造の確認

**カバー範囲**:
- ✅ ファイル配置ロジック（vscode/、git/、config/）
- ✅ JSONマージ機能（jq使用時）
- ✅ バックアップファイル作成
- ✅ 複数テンプレートの適用順序
- ✅ ディレクトリ構造の正確性

**利点**:
- 🚀 高速（GitHubアクセス不要）
- 💻 オフライン実行可能
- 🔧 開発中の頻繁なテストに最適

### 2. GitHubダウンロード統合テスト

**ファイル**: `manual/test-github-download.sh`

**目的**: GitHub APIを使用した実際のダウンロードをテスト

**テストケース**:

1. **デフォルト動作**: `templete/base`からダウンロード
2. **カスタムディレクトリ（短縮形）**: `-d test-templete simple`
3. **カスタムディレクトリ（完全形）**: `--template-dir test-templete advanced`
4. **複数テンプレート**: `test-templete/simple`と`advanced`を順番に適用
5. **JSONマージ＆バックアップ**: 既存ファイルとのマージ

**カバー範囲**:
- ✅ GitHub API経由でのファイル取得
- ✅ 認証（GitHub Token）の動作
- ✅ --template-dir オプション
- ✅ エラーハンドリング
- ✅ エンドツーエンド統合

## 実行方法

### ローカルテスト（推奨、GitHubアクセス不要）

#### 前提条件
- `test-templete`ディレクトリがローカルに存在
- `jq`（オプション、JSONマージテスト用）

#### 実行
```bash
cd /home/keita/Project/vs_code/VSCode-Templete
./test/manual/test-local-templates.sh
```

#### VS Codeから実行
1. Ctrl+Shift+P（Cmd+Shift+P on Mac）でコマンドパレットを開く
2. "Tasks: Run Test Task"を選択
3. "Run Local Tests"を選択（デフォルト）

### GitHub統合テスト（GitHub Token必要）

#### 前提条件

- **GITHUB_TOKEN**: プライベートリポジトリへのアクセスに必要（環境変数、`.github_token`ファイル、または`~/.config/vscode-templates/token`で設定）
- **curl**: GitHubからのファイルダウンロードに使用
- **jq**: JSONマージに使用（オプション、ないとマージが単純上書きになります）
- **bash**: 4.0以上（連想配列を使用）
- **インターネット接続**

#### トークンの設定

**方法1: 外部ファイル（推奨）**
```bash
# プロジェクトローカル
echo 'github_pat_xxxxx' > .github_token
chmod 600 .github_token

# または、グローバル設定
mkdir -p ~/.config/vscode-templates
echo 'github_pat_xxxxx' > ~/.config/vscode-templates/token
chmod 600 ~/.config/vscode-templates/token
```

**方法2: 環境変数**
```bash
export GITHUB_TOKEN="your_github_personal_access_token"
```

#### 実行

```bash
cd /home/keita/Project/vs_code/VSCode-Templete
./test/manual/test-github-download.sh
```

#### VS Codeから実行
1. Ctrl+Shift+P（Cmd+Shift+P on Mac）でコマンドパレットを開く
2. "Tasks: Run Task"を選択
3. "Run GitHub Tests"を選択

### 出力例

```
================================================================================
テスト 1/5: デフォルト動作（templete/base）
================================================================================
✓ テスト環境作成...
✓ スクリプト実行（デフォルト）...
✓ ファイル配置確認...
✓ ファイル内容確認...
[SUCCESS] テスト 1 完了

================================================================================
テスト 2/5: -d test-templete simple
================================================================================
✓ テスト環境作成...
✓ スクリプト実行（-d test-templete simple）...
✓ ファイル配置確認...
✓ ファイル内容確認...
[SUCCESS] テスト 2 完了

...

================================================================================
テスト結果サマリー
================================================================================
総テスト数: 5
成功: 5
失敗: 0
```

## テストの詳細

### テスト 1: デフォルト動作

デフォルトの`templete/base`からテンプレートをダウンロードし、適切なディレクトリに配置されることを確認します。

**確認項目**:
- `.vscode/settings.json`が配置される
- 配置先が正しい（`templete/base/vscode/settings.json` → `.vscode/settings.json`）

### テスト 2 & 3: カスタムテンプレートディレクトリ

`--template-dir`（`-d`）オプションで`test-templete/`ディレクトリからテンプレートを取得し、適切に配置されることを確認します。

**確認項目**:
- `-d`（短縮形）と`--template-dir`（完全形）の両方が動作する
- 指定したディレクトリからファイルが取得される
- ファイル内容が正しい（simple/advancedの違いを検証）

### テスト 4: 複数テンプレートの適用

simpleとadvancedを順番に適用し、後から適用したテンプレートが優先されることを確認します。

**確認項目**:
- 両方のテンプレートが適用される
- 後から適用したテンプレート（advanced）の値が優先される

### テスト 5: JSONマージとバックアップ

既存のJSONファイルがある状態で新しいテンプレートを適用し、マージとバックアップが正しく動作することを確認します。

**確認項目**:
- 既存のJSONファイルがバックアップされる（`settings.json.backup.YYYYMMDD_HHMMSS`）
- JSONが深くマージされる（jqがある場合）
- 既存の設定値が保持される
- 新しい設定値が追加される
- 上書き時は新しい値が優先される

## test-templeteディレクトリについて

`test-templete/`ディレクトリは、`--template-dir`オプションをテストするための専用ディレクトリです。

**構造**:
```
test-templete/
├── simple/
│   ├── vscode/
│   │   └── settings.json         # テスト用設定（editor.fontSize: 14）
│   ├── git/
│   │   └── .gitignore            # テスト用gitignore
│   └── config/
│       └── .editorconfig         # テスト用editorconfig
└── advanced/
    └── vscode/
        └── settings.json         # テスト用設定（editor.fontSize: 16）
```

このディレクトリは本番の`templete/`とは独立しており、テストのためだけに使用されます。

## 依存関係

- **bash**: 4.0以上（連想配列を使用）
- **curl**: GitHubからのダウンロード用（必須）
- **jq**: JSONマージ用（オプション、ないと単純上書きになります）
- **GITHUB_TOKEN**: プライベートリポジトリアクセス用（環境変数）

## トラブルシューティング

### GITHUB_TOKENが設定されていない

```
Error: GITHUB_TOKEN environment variable is not set
```

環境変数を設定してください：
```bash
export GITHUB_TOKEN="your_token_here"
```

### jqがインストールされていない

jqがない場合、マージではなく単純上書きになります：
```
Warning: jq is not installed, falling back to overwrite mode
```

jqをインストール：
```bash
# macOS
brew install jq

# Ubuntu/Debian
sudo apt-get install jq
```

### テンプレートが見つからない

```
Error: Template 'xxx' not found in GitHub repository
```

- テンプレート名が正しいか確認
- GitHubリポジトリに該当ディレクトリが存在するか確認
- GITHUB_TOKENの権限が正しいか確認

## CI/CD 統合例

### GitHub Actions

```yaml
name: Integration Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Install dependencies
        run: |
          sudo apt-get update
          sudo apt-get install -y jq curl
      - name: Run integration tests
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: ./test/manual/test-template-dir-option.sh
```

## テストの追加方法

新しいテストケースを追加する場合：

1. `test/manual/test-template-dir-option.sh`を編集
2. `run_test`関数を使ってテストケースを追加
3. 検証項目を`verify_file_exists`、`verify_file_content`関数で確認
4. 必要に応じて新しい`test-templete/`のテンプレートを作成

例：
```bash
# テスト 6: 新しいテストケース
run_test 6 "新しい機能のテスト" "$TEST_DIR_6" "command" "args"
verify_file_exists "$TEST_DIR_6/.vscode/settings.json"
verify_file_content "$TEST_DIR_6/.vscode/settings.json" "expected_value"
```

## どのように使うか？

| 状況 | 推奨アクション |
|------|------------|
| スクリプト変更後 | 統合テスト実行（全テストケース） |
| 新機能追加後 | 新しいテストケースを追加して実行 |
| バグ修正後 | 該当するテストケースが通ることを確認 |
| リリース前 | 統合テスト実行（全テストケース） |
| CI/CD | GitHub Actionsで自動実行 |
