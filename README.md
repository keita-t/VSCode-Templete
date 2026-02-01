# VSCode Project Template Setup

GitHubからVSCodeプロジェクト設定テンプレートを自動ダウンロードして配置するツールです。
設定ファイルのマージによる柔軟な差分設定をサポートしています。

## 🚀 クイックスタート

```bash
# 付属のテンプレートを使用
./vscode-project-startup.sh default/base

# 独自テンプレートを作成して使用（推奨）
./vscode-project-startup.sh my-template

# テンプレートを組み合わせる（後が優先）
./vscode-project-startup.sh default/base my-template
```

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
| `git/`        | `.git/`             |
| `config/`     | `.`（ルート）       |
| `docker/`     | `.`（ルート）       |

### 使用方法

```bash
# 作成したテンプレートを適用
./vscode-project-startup.sh my-template

# カテゴリで整理する場合（例：python/my-config）
./vscode-project-startup.sh python/my-config

# 複数テンプレートを組み合わせる（後が優先）
./vscode-project-startup.sh default/base my-template
```

### 設定ファイルのマージ

このツールの最大の特徴は、既存のプロジェクト設定を上書きせず、**マージ**することです。

#### JSONファイルのマージ

`settings.json`、`launch.json`、`*.code-snippets`などのJSONファイルは、既存の設定と自動的にマージされます：

```bash
# 既存のプロジェクトに設定を追加
cd /path/to/existing-project

# 既存の.vscode/settings.jsonがあっても、新しい設定が追加される
./vscode-project-startup.sh python/base

# さらに追加の設定を重ねる
./vscode-project-startup.sh python/pylance-lw
```

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

## � GitHub Personal Access Token（オプション）

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
