#!/bin/bash

# ============================================================================
# プロジェクトテンプレート セットアップスクリプト
# ============================================================================
# GitHubリポジトリからテンプレートをダウンロードして、プロジェクトに配置します
# 様々な開発環境・言語のテンプレートに対応
# ============================================================================

# ----------------------------------------------------------------------------
# カラー定義
# ----------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================================================================
# 設定セクション（ここを編集してテンプレートを追加/カスタマイズ）
# ============================================================================
#
# 【テンプレート設定の追加方法】
# 1. templates/<テンプレート名>/ フォルダを作成
# 2. 以下の命名規則で設定を追加（オプション）:
#    - <テンプレート名を大文字>_FOLDER_MAPPING
#    - <テンプレート名を大文字>_FILE_MAPPING
# 3. 設定がない場合は、デフォルト設定のみが自動適用されます
#
# 【例】
#   templates/rust/ の場合:
#     declare -A RUST_FOLDER_MAPPING=(["cargo"]="." ["src"]="src")
#     declare -A RUST_FILE_MAPPING=(["Cargo.toml"]=".")
#
# ----------------------------------------------------------------------------

# --- GitHubリポジトリ設定 ---
# テンプレートを取得するGitHubリポジトリの情報
# 公開リポジトリ以外で使用する場合は変更できます
GITHUB_USER="keita-t"               # GitHubユーザー名
REPO_NAME="VSCode-Templete"         # リポジトリ名
BRANCH="main"                       # ブランチ名（mainまたはmaster）

# --- 認証設定（オプション：このリポジトリはパブリックなので通常不要） ---
# GitHub Personal Access Token
# プライベートフォーク使用時やAPI rate limit回避のために設定可能
# 優先順位: 環境変数 > .github_token > ~/.config/vscode-templates/token
GITHUB_TOKEN="${GITHUB_TOKEN:-}"

# --- デフォルト設定（全テンプレート共通） ---
# すべてのテンプレートに自動適用される基本マッピング
declare -A DEFAULT_FOLDER_MAPPING=(
    ["vscode"]=".vscode"    # VSCode設定ファイル
    ["snippets"]=".vscode"  # VSCodeスニペットファイル
    ["git"]=".git"          # Git関連ファイル
    ["config"]="."          # 汎用設定ファイル
    ["docker"]="."          # Docker関連ファイル
)

declare -A DEFAULT_FILE_MAPPING=(
    [".gitignore"]="."
    [".dockerignore"]="."
    [".editorconfig"]="."
)

# --- マージ設定（全テンプレート共通） ---
# マージ対象とするファイルパターン（ワイルドカード使用可）
# ここに指定されたパターンに一致するファイルは、既存ファイルとマージされます
DEFAULT_MERGE_SETTING=(
    "*.json"          # JSONファイル（settings.json, package.jsonなど）
    "*.code-snippets" # VSCodeスニペットファイル
    "*.yaml"          # YAMLファイル（docker-compose.yml, .gitlab-ci.ymlなど）
    "*.yml"           # YAML短縮形式
    "*.toml"          # TOMLファイル（pyproject.toml, Cargo.tomlなど）
    "*.xml"           # XMLファイル（pom.xml, .idea/workspace.xmlなど）
)

# --- 個別テンプレート設定 ---
# 特定のテンプレート用の追加設定（デフォルトを上書き/拡張）

# Pythonフォルダ
declare -A PYTHON_FOLDER_MAPPING=(
    ["docs"]="docs"
    ["tests"]="tests"
)

declare -A PYTHON_FILE_MAPPING=(
    ["requirements.txt"]="."
    ["setup.py"]="."
)


# ============================================================================
# スクリプト本体（通常は編集不要）
# ============================================================================

# ----------------------------------------------------------------------------
# ヘルパー関数
# ----------------------------------------------------------------------------

# GitHubトークンを外部ファイルから読み込む
# 優先順位:
#   1. 環境変数 GITHUB_TOKEN（最優先）
#   2. プロジェクトローカル .github_token
#   3. ユーザーホーム ~/.config/vscode-templates/token
load_github_token() {
    # 環境変数が既に設定されている場合はそれを使用
    if [[ -n "$GITHUB_TOKEN" ]]; then
        return 0
    fi

    # プロジェクトローカルのトークンファイルをチェック
    local project_token=".github_token"
    if [[ -f "$project_token" && -r "$project_token" ]]; then
        # ファイルパーミッションの警告（600または400以外）
        local perms
        perms=$(stat -c '%a' "$project_token" 2>/dev/null || stat -f '%A' "$project_token" 2>/dev/null)
        if [[ "$perms" != "600" && "$perms" != "400" ]]; then
            echo -e "${YELLOW}Warning: $project_token has insecure permissions ($perms). Consider: chmod 600 $project_token${NC}" >&2
        fi

        # コメント行（#で始まる）と空行を除外して、最初の有効な行を取得
        GITHUB_TOKEN=$(grep -v '^[[:space:]]*#' "$project_token" | grep -v '^[[:space:]]*$' | head -1 | tr -d '[:space:]')
        if [[ -n "$GITHUB_TOKEN" ]]; then
            return 0
        fi
    fi

    # ユーザーホームのグローバル設定をチェック
    local global_token="$HOME/.config/vscode-templates/token"
    if [[ -f "$global_token" && -r "$global_token" ]]; then
        # ファイルパーミッションの警告
        local perms
        perms=$(stat -c '%a' "$global_token" 2>/dev/null || stat -f '%A' "$global_token" 2>/dev/null)
        if [[ "$perms" != "600" && "$perms" != "400" ]]; then
            echo -e "${YELLOW}Warning: $global_token has insecure permissions ($perms). Consider: chmod 600 $global_token${NC}" >&2
        fi

        # コメント行（#で始まる）と空行を除外して、最初の有効な行を取得
        GITHUB_TOKEN=$(grep -v '^[[:space:]]*#' "$global_token" | grep -v '^[[:space:]]*$' | head -1 | tr -d '[:space:]')
        if [[ -n "$GITHUB_TOKEN" ]]; then
            return 0
        fi
    fi

    # トークンが見つからない場合は空のまま（公開リポジトリ用）
    return 0
}

# マージ設定を取得
# DEFAULT_MERGE_SETTINGを返す（全テンプレート共通）
get_merge_setting() {
    # デフォルトマージ設定を出力（改行区切り）
    printf '%s\n' "${DEFAULT_MERGE_SETTING[@]}"
}

# ファイルがマージ対象かどうかをチェック
should_merge_file() {
    local filename="$1"

    # マージ設定を取得
    local merge_patterns
    readarray -t merge_patterns < <(get_merge_setting)

    # パターンマッチング
    for pattern in "${merge_patterns[@]}"; do
        if [[ "$filename" == $pattern ]]; then
            return 0  # マージ対象
        fi
    done

    return 1  # マージ対象外
}

# テンプレート設定を取得（フォルダマッピング）
# デフォルト設定と個別設定をマージして返す
get_template_folder_mapping() {
    local template_type="$1"

    # 結果を格納する一時的な連想配列
    declare -A merged_mapping

    # まずデフォルト設定をコピー
    for key in "${!DEFAULT_FOLDER_MAPPING[@]}"; do
        merged_mapping["${key}"]="${DEFAULT_FOLDER_MAPPING[$key]}"
    done

    # テンプレート名からベース名を抽出（サブディレクトリ対応）
    # 例: "python/base" -> "python", "base" -> "base"
    local base_template="${template_type%%/*}"

    # テンプレート名を大文字に変換して変数名を構築
    local mapping_var="${base_template^^}_FOLDER_MAPPING"

    # 個別設定が存在するかチェック（動的変数参照）
    if declare -p "$mapping_var" &>/dev/null; then
        # 個別設定をマージ
        local -n template_mapping="$mapping_var"
        for key in "${!template_mapping[@]}"; do
            merged_mapping["${key}"]="${template_mapping[$key]}"
        done
    fi

    # マージした結果を出力
    if [ ${#merged_mapping[@]} -eq 0 ]; then
        return 1
    fi

    for key in "${!merged_mapping[@]}"; do
        echo "${key}:${merged_mapping[$key]}"
    done

    return 0
}

# ファイル名による配置先を取得（個別マッピング）
# デフォルト設定と個別設定をチェック
get_file_destination() {
    local template_type="$1"
    local filename="$2"

    # テンプレート名からベース名を抽出（サブディレクトリ対応）
    local base_template="${template_type%%/*}"

    # テンプレート名を大文字に変換して変数名を構築
    local mapping_var="${base_template^^}_FILE_MAPPING"

    # 個別設定が存在する場合はチェック（動的変数参照）
    if declare -p "$mapping_var" &>/dev/null; then
        local -n template_file_mapping="$mapping_var"
        if [ -n "${template_file_mapping[$filename]}" ]; then
            echo "${template_file_mapping[$filename]}"
            return 0
        fi
    fi

    # 個別設定にない場合はデフォルト設定をチェック
    if [ -n "${DEFAULT_FILE_MAPPING[$filename]}" ]; then
        echo "${DEFAULT_FILE_MAPPING[$filename]}"
        return 0
    fi

    return 1
}

# テンプレートタイプに応じてファイルリストを取得
get_template_files() {
    local template_type="$1"
    local subfolder="$2"
    local template_path="${TEMPLATE_DIR}/${template_type}/${subfolder}"

    # ローカルディレクトリが存在する場合はそちらを使用
    if [ -d "${template_path}" ]; then
        # ローカルファイルシステムからファイルリストを取得
        while IFS= read -r filepath; do
            local filename=$(basename "${filepath}")
            if [ -f "${filepath}" ]; then
                ALL_FILES+=("${template_type}/${subfolder}/${filename}")
                ALL_FILE_DESTINATIONS+=("${subfolder}")
                ALL_FILE_TEMPLATES+=("${template_type}")
            fi
        done < <(find "${template_path}" -maxdepth 1 -type f)
    else
        # GitHub APIでファイルリストを取得
        local api_url="https://api.github.com/repos/${GITHUB_USER}/${REPO_NAME}/contents/${TEMPLATE_DIR}/${template_type}/${subfolder}?ref=${BRANCH}"

        local response
        if [ -n "$GITHUB_TOKEN" ]; then
            response=$(curl -s -H "Authorization: token $GITHUB_TOKEN" "${api_url}")
        else
            response=$(curl -s "${api_url}")
        fi

        # ファイル名を抽出
        local files
        files=$(echo "${response}" | grep -o '"name"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*:.*"\([^"]*\)".*/\1/')

        # ファイルパスの配列を追加
        while IFS= read -r filename; do
            if [ -n "$filename" ]; then
                ALL_FILES+=("${TEMPLATE_DIR}/${template_type}/${subfolder}/${filename}")
                ALL_FILE_DESTINATIONS+=("${subfolder}")
                ALL_FILE_TEMPLATES+=("${template_type}")
            fi
        done <<< "$files"
    fi
}

# 使用方法を表示
usage() {
    echo "使用方法: $0 [options] <template_name> [<template_name2> ...]"
    echo ""
    echo "オプション:"
    echo "  -d, --template-dir <dir>  テンプレートディレクトリを指定 (デフォルト: templete)"
    echo ""
    echo "例:"
    echo "  $0 base          # 基本設定"
    echo "  $0 base python   # 基本 + Python"
    echo "  $0 -d test-templete base  # test-templeteディレクトリから取得"
    echo ""
    echo "プライベートリポジトリの場合:"
    echo "  export GITHUB_TOKEN='token' してから実行"
    echo "  詳細: README.md を参照"
    exit 1
}

# ----------------------------------------------------------------------------
# メイン処理
# ----------------------------------------------------------------------------

# GitHubトークンの読み込み（環境変数、プロジェクトローカル、グローバル設定の順に試行）
load_github_token

# デフォルトのテンプレートディレクトリ
TEMPLATE_DIR="templates"

# 引数解析
TEMPLATE_TYPES=()
while [ $# -gt 0 ]; do
    case "$1" in
        -d|--template-dir)
            if [ -z "$2" ]; then
                echo -e "${RED}エラー: --template-dir に値が必要です${NC}"
                exit 1
            fi
            TEMPLATE_DIR="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        -*)
            echo -e "${RED}エラー: 不明なオプション: $1${NC}"
            usage
            ;;
        *)
            TEMPLATE_TYPES+=("$1")
            shift
            ;;
    esac
done

# 引数チェック
if [ ${#TEMPLATE_TYPES[@]} -eq 0 ]; then
    echo -e "${RED}エラー: テンプレートを1つ以上指定してください${NC}"
    echo ""
    usage
fi

# 内部変数（変更不要）
BASE_URL="https://raw.githubusercontent.com/${GITHUB_USER}/${REPO_NAME}/${BRANCH}"
PROJECT_DIR=$(pwd)

# --- セットアップ開始 ---

echo -e "${GREEN}プロジェクトテンプレート セットアップ${NC}"
echo "適用テンプレート: ${TEMPLATE_TYPES[*]}"
echo "テンプレートディレクトリ: ${TEMPLATE_DIR}"
echo "対象ディレクトリ: ${PROJECT_DIR}"
echo ""

# 全テンプレートのファイルリストを取得
declare -a ALL_FILES=()
declare -a ALL_FILE_DESTINATIONS=()
declare -a ALL_FILE_TEMPLATES=()

for TEMPLATE_TYPE in "${TEMPLATE_TYPES[@]}"; do
    # テンプレートマッピングを検証
    MAPPING_LIST=$(get_template_folder_mapping "${TEMPLATE_TYPE}")
    if [ -z "$MAPPING_LIST" ]; then
        echo -e "${RED}エラー: テンプレート '${TEMPLATE_TYPE}' の設定が見つかりません${NC}"
        exit 1
    fi

    # このテンプレートのファイルリストを取得
    while IFS=: read -r subfolder dest_dir; do
        get_template_files "${TEMPLATE_TYPE}" "${subfolder}"
    done <<< "$MAPPING_LIST"
done

echo -e "${GREEN}✓${NC} 合計 ${#ALL_FILES[@]} 個のファイルを検出"

# 配列を統合
FILES=("${ALL_FILES[@]}")
FILE_DESTINATIONS=("${ALL_FILE_DESTINATIONS[@]}")
FILE_TEMPLATES=("${ALL_FILE_TEMPLATES[@]}")

if [ ${#FILES[@]} -eq 0 ]; then
    echo -e "${RED}エラー: ダウンロードするファイルが見つかりません${NC}"
    exit 1
fi

# --- ダウンロード準備 ---

# 一時ディレクトリを作成
TEMP_DIR=$(mktemp -d)

# クリーンアップ関数
cleanup() {
    rm -rf "${TEMP_DIR}"
}

# スクリプト終了時にクリーンアップ
trap cleanup EXIT

# --- ファイルダウンロード ---

# ファイルをダウンロード（またはコピー）
echo "ダウンロード中... (${#FILES[@]} files)"
SUCCESS_COUNT=0
FAIL_COUNT=0

for file in "${FILES[@]}"; do
    # 空のファイル名をスキップ
    if [ -z "$file" ]; then
        continue
    fi

    dest_file="${TEMP_DIR}/${file}"
    mkdir -p "$(dirname "${dest_file}")"

    # ローカルファイルが存在する場合はコピー
    local_file="${TEMPLATE_DIR}/${file}"
    if [ -f "${local_file}" ]; then
        if cp "${local_file}" "${dest_file}"; then
            ((SUCCESS_COUNT++))
        else
            ((FAIL_COUNT++))
        fi
    else
        # GitHubからダウンロード
        url="${BASE_URL}/${file}"
        if [ -n "$GITHUB_TOKEN" ]; then
            if curl -s -f -H "Authorization: token $GITHUB_TOKEN" -o "${dest_file}" "${url}"; then
                ((SUCCESS_COUNT++))
            else
                ((FAIL_COUNT++))
            fi
        else
            if curl -s -f -o "${dest_file}" "${url}"; then
                ((SUCCESS_COUNT++))
            else
                ((FAIL_COUNT++))
            fi
        fi
    fi
done

if [ $FAIL_COUNT -gt 0 ]; then
    echo -e "${RED}エラー: ${FAIL_COUNT} ファイルのダウンロードに失敗${NC}"
    exit 1
fi
echo -e "${GREEN}✓${NC} ${SUCCESS_COUNT} ファイルをダウンロード"

# --- ファイル配置 ---

echo "配置中..."
declare -A DEPLOYED_DIRS

# JSONマージ関数
merge_json_files() {
    local base_file="$1"
    local new_file="$2"
    local output_file="$3"

    # jqがインストールされているかチェック
    if ! command -v jq &> /dev/null; then
        echo -e "  ${YELLOW}注意: jqがインストールされていないため、JSONマージをスキップ（上書き）${NC}"
        return 1
    fi

    # JSONC（コメント付きJSON）からコメントを削除してマージ
    # 行コメント（//）とブロックコメント（/* */）を削除
    local base_clean=$(mktemp)
    local new_clean=$(mktemp)

    # コメントを削除（簡易的な処理）
    sed 's|//.*||g' "${base_file}" | grep -v '^\s*$' > "${base_clean}"
    sed 's|//.*||g' "${new_file}" | grep -v '^\s*$' > "${new_clean}"

    # JSONファイルをマージ（深い階層まで統合）
    if jq -s '.[0] * .[1]' "${base_clean}" "${new_clean}" > "${output_file}" 2>/dev/null; then
        rm -f "${base_clean}" "${new_clean}"
        return 0
    else
        # マージ失敗時は新しいファイルで上書き
        rm -f "${base_clean}" "${new_clean}"
        return 1
    fi
}

merge_yaml_files() {
    local base_file="$1"
    local new_file="$2"
    local output_file="$3"

    # yqがインストールされているかチェック
    if ! command -v yq &> /dev/null; then
        echo -e "  ${YELLOW}注意: yqがインストールされていないため、YAMLマージをスキップ（上書き）${NC}"
        return 1
    fi

    # YAMLファイルをマージ（深い階層まで統合）
    # yq eval-all '. as $item ireduce ({}; . * $item)' で複数ファイルをマージ
    if yq eval-all '. as $item ireduce ({}; . * $item)' "${base_file}" "${new_file}" > "${output_file}" 2>/dev/null; then
        return 0
    else
        echo -e "  ${YELLOW}注意: YAMLマージに失敗（上書き）${NC}"
        return 1
    fi
}

merge_toml_files() {
    local base_file="$1"
    local new_file="$2"
    local output_file="$3"

    # toml-cliまたはdaselがインストールされているかチェック
    if command -v dasel &> /dev/null; then
        # daselを使用してTOMLをマージ
        if dasel -f "${base_file}" -r toml -w toml > "${output_file}" 2>/dev/null && \
           dasel -f "${new_file}" -r toml | dasel -f "${output_file}" -r toml -w toml put -t string -v - 2>/dev/null; then
            return 0
        fi
    fi
    
    echo -e "  ${YELLOW}注意: daselがインストールされていないため、TOMLマージをスキップ（上書き）${NC}"
    return 1
}

merge_xml_files() {
    local base_file="$1"
    local new_file="$2"
    local output_file="$3"

    # xmlstarletがインストールされているかチェック
    if ! command -v xmlstarlet &> /dev/null; then
        echo -e "  ${YELLOW}注意: xmlstarletがインストールされていないため、XMLマージをスキップ（上書き）${NC}"
        return 1
    fi

    # XMLファイルを単純に結合（ルート要素の子要素をマージ）
    # より高度なマージが必要な場合はカスタマイズが必要
    if cp "${base_file}" "${output_file}" 2>/dev/null; then
        echo -e "  ${YELLOW}注意: XMLマージは基本的な実装のみ（上書き）${NC}"
        return 1
    fi
    
    return 1
}

# ファイル形式に応じたマージ関数を呼び出す
merge_structured_file() {
    local base_file="$1"
    local new_file="$2"
    local output_file="$3"
    local filename=$(basename "${new_file}")

    # ファイル拡張子に基づいてマージ関数を選択
    case "${filename}" in
        *.json|*.code-snippets)
            merge_json_files "${base_file}" "${new_file}" "${output_file}"
            ;;
        *.yaml|*.yml)
            merge_yaml_files "${base_file}" "${new_file}" "${output_file}"
            ;;
        *.toml)
            merge_toml_files "${base_file}" "${new_file}" "${output_file}"
            ;;
        *.xml)
            merge_xml_files "${base_file}" "${new_file}" "${output_file}"
            ;;
        *)
            echo -e "  ${YELLOW}注意: 不明なファイル形式（上書き）${NC}"
            return 1
            ;;
    esac
}


for i in "${!FILES[@]}"; do
    file="${FILES[$i]}"
    subfolder="${FILE_DESTINATIONS[$i]}"
    template_name="${FILE_TEMPLATES[$i]}"
    filename=$(basename "${file}")
    source_path="${TEMP_DIR}/${file}"

    # まずファイル名による個別マッピングをチェック
    if custom_dest=$(get_file_destination "${template_name}" "${filename}") && [ -n "$custom_dest" ]; then
        # 個別マッピングが存在
        dest_base="$custom_dest"
        mapping_type="[個別設定]"
    else
        # フォルダマッピングを使用（各ファイルのテンプレートから動的に取得）
        dest_base=""
        template_mapping=$(get_template_folder_mapping "${template_name}")
        while IFS=: read -r map_subfolder map_dest; do
            if [ "$map_subfolder" = "$subfolder" ]; then
                dest_base="$map_dest"
                break
            fi
        done <<< "$template_mapping"
        mapping_type=""
    fi

    if [ -z "$dest_base" ]; then
        echo -e "  ${RED}✗${NC} ${subfolder} のマッピングが見つかりません"
        continue
    fi

    # 配置先ディレクトリを決定
    if [ "$dest_base" = "." ]; then
        dest_dir="${PROJECT_DIR}"
        display_dir="プロジェクトルート"
    else
        dest_dir="${PROJECT_DIR}/${dest_base}"
        display_dir="${dest_base}"
    fi

    # ディレクトリを作成
    mkdir -p "${dest_dir}"

    if [ -f "${source_path}" ]; then
        dest_file="${dest_dir}/${filename}"

        # マージ設定に一致するファイルで既存ファイルがある場合はマージを試みる
        if should_merge_file "${filename}" && [ -f "${dest_file}" ]; then
            BACKUP_FILE="${dest_file}.backup.$(date +%Y%m%d_%H%M%S)"
            cp "${dest_file}" "${BACKUP_FILE}"

            # 構造化ファイルマージを試行
            TEMP_MERGED="${dest_file}.merged.tmp"
            if merge_structured_file "${dest_file}" "${source_path}" "${TEMP_MERGED}"; then
                mv "${TEMP_MERGED}" "${dest_file}"
                echo -e "  ${GREEN}✓${NC} ${filename} → ${display_dir}/ ${YELLOW}[マージ]${NC} ${mapping_type}"
            else
                # マージ失敗時は通常の上書き
                cp "${source_path}" "${dest_file}"
                echo -e "  ${GREEN}✓${NC} ${filename} → ${display_dir}/ ${YELLOW}[上書き]${NC} ${mapping_type}"
            fi

            echo -e "    バックアップ: $(basename "${BACKUP_FILE}")"
        # 既存ファイルがある場合（JSON以外）はバックアップして上書き
        elif [ -f "${dest_file}" ]; then
            BACKUP_FILE="${dest_file}.backup.$(date +%Y%m%d_%H%M%S)"
            cp "${dest_file}" "${BACKUP_FILE}"
            cp "${source_path}" "${dest_file}"
            echo -e "  ${YELLOW}!${NC} 既存の${filename}をバックアップ: $(basename "${BACKUP_FILE}")"
            echo -e "  ${GREEN}✓${NC} ${filename} → ${display_dir}/ ${mapping_type}"
        else
            # 新規ファイルはそのままコピー
            cp "${source_path}" "${dest_file}"
            echo -e "  ${GREEN}✓${NC} ${filename} → ${display_dir}/ ${mapping_type}"
        fi

        # 配置先を記録
        DEPLOYED_DIRS["${dest_base}"]=1
    fi
done

echo -e "${GREEN}✓${NC} セットアップ完了 (${TEMPLATE_TYPES[*]})"
