# VSCode Project Template Setup

プロジェクトテンプレートをGitHubリポジトリから自動ダウンロードして配置するスクリプトです。

## 🚀 クイックスタート

```bash
# 基本的な使い方
./vscode-project-startup.sh base

# Python環境をセットアップ
./vscode-project-startup.sh base python/base

# Python + Pylance最適化
./vscode-project-startup.sh base python/base python/pylance-lw

# 複数のテンプレートを組み合わせ
./vscode-project-startup.sh base python/base docker
```

## 📁 プロジェクト構造

```
VSCode-Templete/
├── docs/                         # ドキュメント
│   ├── development.md            # 開発者向けドキュメント（AI Copilot用）
│   └── testing.md                # テスト関連ドキュメント
├── .vscode/                      # プロジェクト設定
│   ├── extensions.json           # 推奨拡張機能
│   ├── settings.json             # VSCode設定
│   └── tasks.json                # タスク定義（テスト実行など）
├── templates/                    # テンプレートフォルダ
│   ├── base/                     # 基本設定
│   │   ├── git/.gitignore        # 汎用.gitignore
│   │   └── vscode/settings.json  # 汎用VSCode設定
│   ├── lightweight/              # メモリ最適化設定
│   │   └── vscode/settings.json
│   ├── python/                   # Python関連テンプレート
│   │   ├── base/                 # Python基本設定
│   │   │   ├── vscode/settings.json
│   │   │   └── snippets/python.code-snippets
│   │   └── pylance-lw/           # Pylance軽量版
│   │       └── vscode/settings.json
│   ├── docker/                   # Docker環境
│   │   ├── config/
│   │   │   ├── Dockerfile
│   │   │   └── docker-compose.yml
│   │   └── vscode/settings.json  # Docker用設定
│   └── test/                     # テスト用テンプレート
│       ├── simple/               # シンプルなテストテンプレート
│       │   ├── vscode/settings.json
│       │   ├── git/.gitignore
│       │   └── config/.editorconfig
│       └── advanced/             # 高度なテストテンプレート
│           └── vscode/settings.json
├── test/                         # テストスイート
│   └── manual/                   # 手動統合テスト
│       ├── test-local-templates.sh   # ローカルテスト（オフライン）
│       └── test-github-download.sh   # GitHubテスト（オンライン）
├── vscode-project-startup.sh     # メインスクリプト
├── .github_token.example         # トークンファイル例
├── .gitignore
└── README.md                     # このファイル
```

## ⚙️ セットアップ

### 1. GitHubユーザー名を設定

`vscode-project-startup.sh` を開き、以下を編集：

```bash
GITHUB_USER="YOUR_GITHUB_USERNAME"  # ← 実際のユーザー名に変更
```

### 2. プロジェクトフォルダで実行

```bash
# プロジェクトディレクトリに移動
cd /path/to/your/project

# テンプレートを適用
/path/to/vscode-project-startup.sh base python
```

### 3. プライベートリポジトリを使用する場合

プライベートリポジトリからテンプレートをダウンロードする場合は、GitHub Personal Access Tokenが必要です。

**トークンの設定方法（3つの選択肢）:**

#### 方法1: 外部ファイル（推奨）

**プロジェクトローカル設定（プロジェクト固有のトークン）:**
```bash
# プロジェクトルートに.github_tokenファイルを作成
echo 'github_pat_xxxxx' > .github_token
chmod 600 .github_token  # セキュリティのため読み取り専用に

# テンプレートを適用（自動的に.github_tokenが読み込まれます）
./vscode-project-startup.sh base python
```

**グローバル設定（すべてのプロジェクトで共通のトークン）:**
```bash
# グローバル設定ディレクトリを作成
mkdir -p ~/.config/vscode-templates

# トークンファイルを作成
echo 'github_pat_xxxxx' > ~/.config/vscode-templates/token
chmod 600 ~/.config/vscode-templates/token

# どのプロジェクトでも自動的に読み込まれます
./vscode-project-startup.sh base python
```

#### 方法2: 環境変数

```bash
# トークンを環境変数に設定
export GITHUB_TOKEN='github_pat_xxxxx'

# テンプレートを適用
./vscode-project-startup.sh base python

# セキュリティのため、使用後はトークンを削除
unset GITHUB_TOKEN
```

**トークンの優先順位:**
1. 環境変数 `GITHUB_TOKEN`（最優先）
2. プロジェクトローカル `.github_token`
3. グローバル設定 `~/.config/vscode-templates/token`

**トークンの作成:**
GitHub Settings → Developer settings → Personal access tokens → Tokens (classic) から作成
必要な権限: `repo` (Full control of private repositories)

**⚠️ セキュリティ注意:**
- `.github_token`ファイルは`.gitignore`に含まれています（コミットされません）
- ファイルのパーミッションは必ず`600`または`400`に設定してください
- 環境変数を使用する場合は、使用後に`unset GITHUB_TOKEN`でトークンを削除してください

## 💡 使用例

### 基本設定のみ

```bash
./vscode-project-startup.sh base
```

### Python開発環境

```bash
# Python基本設定
./vscode-project-startup.sh base python/base

# Python + Pylance最適化（メモリ使用量を削減）
./vscode-project-startup.sh base python/base python/pylance-lw
```

### メモリ最適化設定

```bash
# 軽量なVSCode設定
./vscode-project-startup.sh base lightweight
```

### Docker開発環境

```bash
./vscode-project-startup.sh base docker
```

### 階層的な設定

```bash
# 基本 → カテゴリ → 特殊設定の順で適用
./vscode-project-startup.sh base python/base python/pylance-lw
```

## 📝 テンプレートの作成

### 1. フォルダ構造を作成

```bash
templates/
└── my-template/          # 任意の名前
    ├── vscode/           # .vscode/に配置
    │   ├── settings.json
    │   └── launch.json
    ├── git/              # プロジェクトルートに配置
    │   └── .gitignore
    └── config/           # プロジェクトルートに配置
        └── .editorconfig
```

### 2. カテゴリフォルダで整理（推奨）

関連するテンプレートをカテゴリフォルダで階層化できます：

```bash
templates/
├── python/
│   ├── base/             # Python基本設定
│   │   ├── vscode/settings.json
│   │   └── snippets/python.code-snippets
│   └── pylance-lw/       # Pylance軽量版
│       └── vscode/settings.json
└── javascript/
    ├── base/
    └── react/
```

使用例：
```bash
# カテゴリ/サブテンプレートとして指定
./vscode-project-startup.sh base python/base python/pylance-lw
```

### 3. 実行

```bash
# 単一テンプレート
./vscode-project-startup.sh my-template

# 階層化されたテンプレート
./vscode-project-startup.sh python/base
```

## 🔧 カスタム設定

デフォルトと異なる配置が必要な場合、スクリプト内に設定を追加：

```bash
# my-templateフォルダ用のカスタム設定
declare -A MY-TEMPLATE_FOLDER_MAPPING=(
    ["special-folder"]="custom/path"
)
declare -A MY-TEMPLATE_FILE_MAPPING=(
    ["special-file.json"]="."
)
```

## 🎯 デフォルトマッピング

以下のフォルダは自動的にマッピングされます：

| テンプレート内 | プロジェクト内 |
|---------------|----------------|
| `vscode/`     | `.vscode/`     |
| `snippets/`   | `.vscode/`     |
| `git/`        | `.`（プロジェクトルート） |
| `config/`     | `.`（プロジェクトルート） |
| `docker/`     | `.`（プロジェクトルート） |

**注意:** `snippets/`フォルダは`.vscode/`に配置されるため、VSCodeスニペットの管理に最適です。

## 📚 テンプレート一覧

### base

汎用的な基本設定

- `.gitignore`: OS、エディタ、Python全般の除外設定（統合版）
- `settings.json`: VSCodeの基本設定（視覚効果は含まない）

### lightweight

メモリ最適化設定

- 低スペックマシンや大規模プロジェクト向け
- 視覚効果の無効化、エディタタブ制限、ファイル監視の最適化
- Gitの自動機能を無効化してパフォーマンス向上
- 使用例: `./vscode-project-startup.sh base lightweight`

### python/base

Python基本設定

- Python固有のVSCode設定（tabSize: 4、rulers、フォーマッター）
- Pythonスニペット
- baseとのマージ前提（単体では不完全）
- 使用例: `./vscode-project-startup.sh base python/base`

### python/pylance-lw

Pylanceメモリ最適化設定

- Python開発でPylanceのメモリ使用量を削減
- インデックス無効化、診断モードの制限、メモリ上限設定
- 低スペックマシンや大規模Pythonプロジェクト向け
- 使用例: `./vscode-project-startup.sh base python/base python/pylance-lw`

### docker

Docker開発環境の設定

- Dockerfile、docker-compose.yml のテンプレート
- Docker用のVSCode設定

### カスタムテンプレート

独自のテンプレートを `templates/` 配下に作成できます。
階層化もサポートしています（例: `myproject/dev`, `myproject/prod`）

## 🤝 貢献

1. このリポジトリをFork
2. `templates/` 配下に新しいテンプレートを追加
3. Pull Requestを作成

## 🧪 テスト

### ローカルテスト（オフライン）

GitHub接続不要で高速にテスト：

```bash
# ローカルテンプレートを使用したテスト（5つのテストケース）
./test/manual/test-local-templates.sh
```

### GitHubテスト（オンライン）

GitHub APIとダウンロード機能をテスト：

```bash
# プライベートリポジトリの場合はトークン設定
export GITHUB_TOKEN='your_token'

# GitHubからダウンロードするテスト（5つのテストケース）
./test/manual/test-github-download.sh
```

**テスト内容：**
- ローカルテスト: ファイル配置、JSON マージ、ディレクトリ構造
- GitHubテスト: API認証、ダウンロード、テンプレートディレクトリオプション

詳細は [docs/testing.md](docs/testing.md) を参照してください。

## 📄 ライセンス

MIT License

## 🔗 リンク

- [GitHub Repository](https://github.com/YOUR_USERNAME/VSCode-Templete)
