# VSCode Project Template Setup

プロジェクトテンプレートをGitHubリポジトリから自動ダウンロードして配置するスクリプトです。

## 🚀 クイックスタート

```bash
# 基本的な使い方
./vscode-project-startup.sh base

# Python環境をセットアップ
./vscode-project-startup.sh base python

# 複数のテンプレートを組み合わせ
./vscode-project-startup.sh base python docker
```

## 📁 プロジェクト構造

```
VSCode-Templete/
├── vscode-project-startup.sh    # メインスクリプト
├── templete/                     # テンプレートフォルダ
│   ├── base/                     # 基本設定
│   │   ├── git/.gitignore       # 汎用.gitignore
│   │   └── vscode/settings.json # 汎用VSCode設定
│   └── python/                   # Python環境
│       ├── vscode/
│       ├── docs/
│       └── tests/
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

## 💡 使用例

### 基本設定のみ
```bash
./vscode-project-startup.sh base
```

### Python開発環境
```bash
./vscode-project-startup.sh base python
```

### React Native + iOS
```bash
./vscode-project-startup.sh base react-native ios
```

### 階層的な設定
```bash
# 基本 → チーム設定 → 個人設定の順で適用
./vscode-project-startup.sh base team-config my-preferences
```

## 📝 テンプレートの作成

### 1. フォルダ構造を作成

```bash
templete/
└── my-template/          # 任意の名前
    ├── vscode/           # .vscode/に配置
    │   ├── settings.json
    │   └── launch.json
    ├── git/              # プロジェクトルートに配置
    │   └── .gitignore
    └── config/           # プロジェクトルートに配置
        └── .editorconfig
```

### 2. 実行

```bash
./vscode-project-startup.sh my-template
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
| `git/`        | `.git`         |
| `config/`     | `.`            |
| `docker/`     | `.`            |

## 📚 テンプレート一覧

### base
汎用的な基本設定
- `.gitignore`: OS、エディタ、一般的な除外設定
- `settings.json`: VSCodeの基本設定

### python
Python開発環境の設定
- VSCode設定（Python固有）
- ドキュメント・テストフォルダ構造

### （追加可能）
独自のテンプレートを `templete/` 配下に作成できます

## 🤝 貢献

1. このリポジトリをFork
2. `templete/` 配下に新しいテンプレートを追加
3. Pull Requestを作成

## 🧪 テスト

### 自動ユニットテスト（推奨）

BATSを使用した自動テスト：

```bash
# BATSのインストール（初回のみ）
sudo apt-get install bats  # Ubuntu/Debian
brew install bats-core      # macOS

# テスト実行
bats test/vscode-project-startup.bats

# VS Codeのテストエクスプローラからも実行可能
```

### 手動統合テスト

エンドツーエンドでの動作確認：

```bash
# ローカル環境テスト
./test/manual/test-local.sh

# JSONマージ機能テスト
./test/manual/test-merge.sh
```

詳細は [test/README.md](test/README.md) を参照してください。

## 📄 ライセンス

MIT License

## 🔗 リンク

- [GitHub Repository](https://github.com/YOUR_USERNAME/VSCode-Templete)
