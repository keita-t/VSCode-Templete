# テストディレクトリ

このディレクトリには、`vscode-project-startup.sh` スクリプトのテストファイルが含まれています。

## ディレクトリ構造

```
test/
├── README.md                      # このファイル
├── vscode-project-startup.bats   # 自動ユニットテスト（推奨）
└── manual/                        # 手動統合テスト
    ├── test-local.sh             # ローカル環境でのE2Eテスト
    └── test-merge.sh             # JSONマージ機能の検証
```

## テストの種類

### 🤖 自動ユニットテスト（BATS）

**ファイル**: `vscode-project-startup.bats`

**目的**: 個別の関数やロジックを自動的にテスト

**カバー範囲**:
- ✅ マージ設定の取得
- ✅ ファイルのマージ判定
- ✅ テンプレートフォルダマッピング
- ✅ ファイルの配置先決定
- ✅ JSONマージ機能
- ✅ 引数処理とエラーハンドリング
- ✅ 使用方法の表示

**実行方法**: [自動ユニットテストの実行](#batsテストの実行方法)を参照

### 🔧 手動統合テスト（シェルスクリプト）

**ディレクトリ**: `manual/`

**目的**: エンドツーエンド（E2E）での動作確認

**ファイル**:
- **test-local.sh**: GitHub APIを使わずローカルのテンプレートを直接適用して動作確認
- **test-merge.sh**: JSONマージ機能の実際の動作を視覚的に確認

**使用シーン**:
- スクリプト全体の動作確認
- 実際のファイル配置を確認したい場合
- マージ結果を目視で確認したい場合

**実行方法**: [手動統合テストの実行](#手動統合テスト)を参照

## BATSテストの実行方法

### 1. BATSのインストール

#### macOS (Homebrew)
```bash
brew install bats-core
```

#### Ubuntu/Debian
```bash
sudo apt-get install bats
```

#### 手動インストール
```bash
git clone https://github.com/bats-core/bats-core.git
cd bats-core
sudo ./install.sh /usr/local
```

### 2. テストの実行

#### 全テストを実行
```bash
cd /home/keita/Project/vs_code/VSCode-Templete
bats test/vscode-project-startup.bats
```

#### 特定のテストのみ実行
```bash
# フィルタリング（説明にキーワードを含むテストのみ）
bats test/vscode-project-startup.bats --filter "merge"
bats test/vscode-project-startup.bats --filter "JSON"
```

#### 詳細出力で実行
```bash
bats test/vscode-project-startup.bats --tap
```

### 3. 出力例

```
✓ get_merge_setting: デフォルトマージ設定を返す
✓ should_merge_file: JSONファイルはマージ対象
✓ should_merge_file: スニペットファイルはマージ対象
✓ should_merge_file: 通常のテキストファイルはマージ対象外
✓ get_template_folder_mapping: デフォルトマッピングを返す
✓ merge_json_files: jqが利用可能な場合はマージ成功
...

15 tests, 0 failures
```

## テスト戦略

### 自動ユニットテスト（BATS）でカバー

| 機能 | テスト内容 | ステータス |
|------|-----------|----------|
| `get_merge_setting` | マージ設定の取得 | ✅ |
| `should_merge_file` | ファイルのマージ判定 | ✅ |
| `get_template_folder_mapping` | テンプレートフォルダマッピング | ✅ |
| `get_file_destination` | ファイルの配置先取得 | ✅ |
| `merge_json_files` | JSONマージ機能 | ✅ |
| 引数処理 | エラーハンドリング | ✅ |
| `usage` | 使用方法の表示 | ✅ |

### 手動統合テストでカバー

| テストシナリオ | 確認内容 |
|-------------|---------|
| ローカル環境テスト | テンプレートの実際の配置、マージ動作 |
| JSONマージテスト | マージ結果の視覚的確認 |

### 今後のテスト拡張候補

- [ ] GitHubからのファイルダウンロード（モック必要）
- [ ] 複数テンプレートの適用順序
- [ ] バックアップファイルの作成
- [ ] より複雑なエラーケース

## 手動統合テスト

これらのテストは、実際の環境でスクリプト全体の動作を確認するためのものです。

### ローカル環境テスト
```bash
cd /home/keita/Project/vs_code/VSCode-Templete
./test/manual/test-local.sh
```

このテストは：
- テンプレートファイルを実際にコピー
- 一時ディレクトリに配置
- マージ結果を表示

### JSONマージ詳細テスト
```bash
cd /home/keita/Project/vs_code/VSCode-Templete
./test/manual/test-merge.sh
```

このテストは：
- JSONマージ機能の詳細な動作確認
- マージ前後のファイル内容を比較表示
- jqの動作確認

## 依存関係

- **bash**: 4.0以上
- **bats-core**: 1.2.0以上（BATSテスト用）
- **jq**: 1.5以上（JSONマージテスト用、オプション）
- **curl**: GitHubからのダウンロード用

## トラブルシューティング

### jqがインストールされていない場合

jqが必要なテストはスキップされます：
```
- merge_json_files: jqが利用可能な場合はマージ成功 (skipped: jqがインストールされていません)
```

jqをインストール：
```bash
# macOS
brew install jq

# Ubuntu/Debian
sudo apt-get install jq
```

### BATSが見つからない場合

```bash
command not found: bats
```

上記の「BATSのインストール」セクションを参照してください。

## CI/CD 統合例

### GitHub Actions

```yaml
name: Test

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Install dependencies
        run: |
          sudo apt-get update
          sudo apt-get install -y bats jq
      - name: Run tests
        run: bats test/vscode-project-startup.bats
```

## テストの追加方法

### BATSテストの追加

新しいユニットテストを追加する場合：

1. `test/vscode-project-startup.bats` を編集
2. 適切なセクションに `@test "テスト名" { ... }` ブロックを追加
3. `run` コマンドでテスト対象の関数を実行
4. アサーション（`[ "$status" -eq 0 ]` など）で検証

例：
```bash
@test "新機能: 正常動作する" {
    run my_new_function "arg1" "arg2"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "期待される文字列" ]]
}
```

### 手動テストの追加

新しい統合テストを追加する場合：

1. `test/manual/` ディレクトリに新しいスクリプトを作成
2. 実行権限を付与: `chmod +x test/manual/your-test.sh`
3. このREADMEに説明を追加

## どのテストを使うべきか？

| 状況 | 推奨テスト |
|------|----------|
| 機能開発中 | BATSテスト（素早くフィードバック） |
| CI/CD | BATSテスト（自動実行） |
| リリース前 | 両方（完全な動作確認） |
| バグ調査 | 手動テスト（詳細な挙動確認） |
| 新機能の動作確認 | 手動テスト（実環境での確認） |
