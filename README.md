# VSCode Project Template Setup

GitHubからVSCodeプロジェクト設定テンプレートを自動ダウンロードして配置するツールです。
設定ファイルのマージによる柔軟な差分設定をサポートしています。

**🎉 Python版に移行しました！** より安定した処理とクリーンなコードで、構造化ファイルのマージが確実に動作します。

## 🚀 クイックスタート

```bash
# 付属のテンプレートを使用
./vscode-project-startup.py default/base

# 独自テンプレートを作成して使用（推奨）
./vscode-project-startup.py my-template

# テンプレートを組み合わせる（後が優先）
./vscode-project-startup.py default/base my-template

# ローカルテンプレートを使用（開発時）
./vscode-project-startup.py -l ./templates -d test simple
```

## 🔧 インストール

### 必要なもの

- Python 3.7 以上

### 推奨パッケージ（マージ機能用）

マージ機能を使用する場合、以下のパッケージのインストールが必要です：

```bash
# Python 3.10以前の場合
pip install pyyaml tomli tomli-w

# Python 3.11以降の場合（tomliは標準ライブラリのtomlibを使用）
pip install pyyaml tomli-w
```

パッケージがインストールされていない場合、該当フォーマットのマージは上書きモードで動作します（警告が表示されます）。

## ⚙️ 設定のカスタマイズ

### config.json

スクリプトの設定は `config.json` で管理されます。
ファイルが存在しない場合、初回実行時に自動的にデフォルトの設定ファイルが作成されます。

```json
{
  "github": {
    "user": "keita-t",
    "repo": "VSCode-Templete",
    "branch": "main"
  },
  "folder_mapping": {
    "vscode": ".vscode",
    "snippets": ".vscode",
    "git": ".",
    "config": ".",
    "docker": "."
  },
  "file_mapping": {
    ".gitignore": ".",
    ".dockerignore": ".",
    ".editorconfig": "."
  },
  "merge_patterns": [
    "*.json",
    "*.yaml",
    "*.yml",
    "*.toml",
    "*.xml"
  ],
  "templates": {
    "python": {
      "folder_mapping": {
        "docs": "docs",
        "tests": "tests"
      },
      "file_mapping": {
        "requirements.txt": ".",
        "setup.py": "."
      }
    }
  }
}
```

**カスタマイズ例：**

- `github`: 独自のフォークを使用する場合に変更
- `folder_mapping`: カスタムフォルダマッピングを追加
- `merge_patterns`: マージ対象ファイルパターンを追加
- `templates.<name>`: テンプレート固有の設定を追加

## 📝 カスタムテンプレートの作り方

### 基本構造

`templates/` 配下にテンプレート名のフォルダを作成し、特定のサブフォルダに設定ファイルを配置します。

```bash
templates/
└── my-template/              # 任意のテンプレート名
    ├── vscode/               # .vscode/ に配置されるファイル
    │   ├── settings.json
    │   └── launch.json
    ├── snippets/             # .vscode/ に配置されるスニペット
    │   └── custom.code-snippets
    ├── git/                  # プロジェクトルートに配置
    │   └── .gitignore
    └── config/               # プロジェクトルートに配置
        └── .editorconfig
```

### フォルダマッピング（自動）

| テンプレート内 | プロジェクト内の配置先 |
|---------------|---------------------|
| `vscode/`     | `.vscode/`          |
| `snippets/`   | `.vscode/`          |
| `git/`        | `.`（ルート）       |
| `config/`     | `.`（ルート）       |
| `docker/`     | `.`（ルート）       |

### 使用方法

```bash
# 作成したテンプレートを適用
./vscode-project-startup.py my-template

# カテゴリで整理する場合（例：python/my-config）
./vscode-project-startup.py python/my-config

# 複数テンプレートを組み合わせる（後が優先）
./vscode-project-startup.py default/base my-template
```

### 設定ファイルのマージ

このツールの最大の特徴は、既存のプロジェクト設定を上書きせず、**マージ**することです。

#### 対応フォーマット

以下の構造化ファイルは自動的にマージされます：

- **JSON** (`.json`, `.code-snippets`) - Pythonネイティブ実装
- **YAML** (`.yaml`, `.yml`) - Python `PyYAML`を使用
- **TOML** (`.toml`) - Python `tomli`/`tomli_w`を使用
- **XML** (`.xml`) - 基本的な実装

**必要なパッケージ：**

マージ機能を使用する場合、事前にパッケージをインストールしてください：

```bash
# Python 3.10以前の場合
pip install pyyaml tomli tomli-w

# Python 3.11以降の場合（tomliは標準ライブラリ）
pip install pyyaml tomli-w
```

パッケージがインストールされていない場合、該当フォーマットのマージは上書きモードで動作します（警告が表示されます）。

#### JSONファイルのマージ

`settings.json`、`launch.json`、`*.code-snippets`などのJSONファイルは、既存の設定と自動的にマージされます：

```bash
# 既存のプロジェクトに設定を追加
cd /path/to/existing-project

# 既存の.vscode/settings.jsonがあっても、新しい設定が追加される
./vscode-project-startup.py python/base

# さらに追加の設定を重ねる
./vscode-project-startup.py python/pylance-lw
```

**マージの動作例：**

既存の `settings.json`:
```json
{
  "editor.fontSize": 16,
  "editor.tabSize": 4,
  "myCustomSetting": "preserve-this"
}
```

テンプレートの `settings.json`:
```json
{
  "editor.fontSize": 14,
  "python.linting.enabled": true
}
```

マージ後:
```json
{
  "editor.fontSize": 14,
  "editor.tabSize": 4,
  "myCustomSetting": "preserve-this",
  "python.linting.enabled": true
}
```

- 既存の設定は保持される
- 同じキーはテンプレートの値で上書き
- 新しいキーは追加される

**マージの動作：**
- 新しいキーは追加される
- 既存のキーは新しい値で上書きされる
- マージされていないキーは保持される
- ネストしたオブジェクトも深くマージされる（`jq`使用時）

**例：**
```json
// 既存の settings.json
{
  "editor.fontSize": 14,
  "editor.tabSize": 2
}

// テンプレートの settings.json
{
  "editor.tabSize": 4,
  "python.linting.enabled": true
}

// マージ後
{
  "editor.fontSize": 14,        // 保持
  "editor.tabSize": 4,          // 上書き
  "python.linting.enabled": true // 追加
}
```

#### その他のファイル

JSONファイル以外（`.gitignore`、`.editorconfig`など）は上書きまたはスキップされます。

### カテゴリで整理（推奨）

関連するテンプレートをカテゴリフォルダで階層化できます：

```bash
templates/
├── myproject/
│   ├── dev/              # 開発環境用
│   │   └── vscode/settings.json
│   └── prod/             # 本番環境用
│       └── vscode/settings.json
└── python/
    └── data-science/     # データサイエンス用
        └── vscode/settings.json
```

使用例：
```bash
./vscode-project-startup.sh myproject/dev
./vscode-project-startup.sh default/base python/data-science
```

## 📚 付属テンプレート（参考例）

リポジトリに含まれているテンプレートは使用例です。プロジェクトに合わせて独自のテンプレートを作成することを推奨します。

- `default/base` - 汎用的な基本設定（.gitignore、VSCode設定）
- `default/lightweight` - メモリ最適化設定
- `python/base` - Python開発用の基本設定
- `python/pylance-lw` - Pylance軽量版設定
- `docker/base` - Docker関連ファイル（Dockerfile、docker-compose.yml）

## 🔧 高度な設定

デフォルトマッピング以外の配置が必要な場合は、スクリプト内で設定を追加できます：

```bash
# vscode-project-startup.sh 内に追加
declare -A MY_TEMPLATE_FOLDER_MAPPING=(
    ["special"]="custom/path"
)
```

詳細は [docs/development.md](docs/development.md) を参照してください。

## 🧪 テスト

### pytest (推奨)

```bash
# 開発環境のセットアップ
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements-dev.txt

# テスト実行
pytest tests/ -v

# VS Code タスクから実行
# Ctrl+Shift+P → "Run Test Task" → "Run Tests (pytest)"
```

### レガシーBashテスト

```bash
# ローカルテンプレートテスト
./test/manual/test-local-templates.sh

# GitHubダウンロードテスト（トークン必要）
./test/manual/test-github-download.sh
```

## 🔑 GitHub Personal Access Token（オプション）

このリポジトリはパブリックなので通常トークンは不要です。プライベートフォークを使用する場合やAPI rate limitを回避したい場合に設定してください。

### 設定方法

```bash
# グローバル設定（推奨）
mkdir -p ~/.config/vscode-templates
echo 'github_pat_xxxxx' > ~/.config/vscode-templates/token
chmod 600 ~/.config/vscode-templates/token

# または環境変数で設定
export GITHUB_TOKEN='github_pat_xxxxx'
```

トークンの作成：GitHub Settings → Developer settings → Personal access tokens → Tokens (classic)
必要な権限：`repo`

## �📄 ライセンス

MIT License

## 🔗 リンク

- [GitHub Repository](https://github.com/YOUR_USERNAME/VSCode-Templete)
