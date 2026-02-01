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
# 1. templete/<テンプレート名>/ フォルダを作成
# 2. 以下の命名規則で設定を追加（オプション）:
#    - <テンプレート名を大文字>_FOLDER_MAPPING
#    - <テンプレート名を大文字>_FILE_MAPPING
# 3. 設定がない場合は、デフォルト設定のみが自動適用されます
#
# 【例】
#   templete/rust/ の場合:
#     declare -A RUST_FOLDER_MAPPING=(["cargo"]="." ["src"]="src")
#     declare -A RUST_FILE_MAPPING=(["Cargo.toml"]=".")
#
# ----------------------------------------------------------------------------

# --- GitHubリポジトリ設定 ---
# テンプレートを取得するGitHubリポジトリの情報
GITHUB_USER="keita-t"  # ← 【必須】実際のGitHubユーザー名に変更してください
REPO_NAME="VSCode-Templete"         # リポジトリ名
BRANCH="main"                       # ブランチ名（mainまたはmaster）

# --- 認証設定（プライベートリポジトリの場合に必要） ---
# GitHub Personal Access Token（環境変数GITHUB_TOKENから自動取得）
# トークンが設定されていない場合は公開リポジトリとしてアクセス
GITHUB_TOKEN="${GITHUB_TOKEN:-}"

# --- デフォルト設定（全テンプレート共通） ---
# すべてのテンプレートに自動適用される基本マッピング
declare -A DEFAULT_FOLDER_MAPPING=(
    ["vscode"]=".vscode"    # VSCode設定ファイル
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
# 必要に応じて他の形式（YAML、TOMLなど）も追加可能です
DEFAULT_MERGE_SETTING=(
    "*.json"          # JSONファイル（settings.json, package.jsonなど）
    "*.code-snippets" # VSCodeスニペットファイル
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

    # テンプレート名を大文字に変換して変数名を構築
    local mapping_var="${template_type^^}_FOLDER_MAPPING"

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

    # テンプレート名を大文字に変換して変数名を構築
    local mapping_var="${template_type^^}_FILE_MAPPING"

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
    local api_url="https://api.github.com/repos/${GITHUB_USER}/${REPO_NAME}/contents/templete/${template_type}/${subfolder}?ref=${BRANCH}"

    # GitHub APIでファイルリストを取得
    local response
    if [ -n "$GITHUB_TOKEN" ]; then
        response=$(curl -s -H "Authorization: token $GITHUB_TOKEN" "${api_url}")
    else
        response=$(curl -s "${api_url}")
    fi

    # ファイル名を抽出
    local files
    files=$(echo "${response}" | grep -o '"name":"[^"]*"' | cut -d'"' -f4)

    # ファイルパスの配列を追加
    while IFS= read -r filename; do
        if [ -n "$filename" ]; then
            ALL_FILES+=("templete/${template_type}/${subfolder}/${filename}")
            ALL_FILE_DESTINATIONS+=("${subfolder}")
            ALL_FILE_TEMPLATES+=("${template_type}")
        fi
    done <<< "$files"
}

# 使用方法を表示
usage() {
    echo -e "${BLUE}使用方法:${NC}"
    echo "  $0 <template_folder_name> [<template_folder_name2> ...]"
    echo ""
    echo -e "${BLUE}テンプレートフォルダ名:${NC}"
    echo "  - GitHubリポジトリの templete/ 直下にあるフォルダ名を指定します"
    echo "  - 任意のフォルダ名でテンプレートを作成・使用できます"
    echo "  - 複数指定した場合、順番に適用されます（後の設定が優先）"
    echo ""
    echo -e "${BLUE}例:${NC}"
    echo "  単一テンプレート:"
    echo "    $0 python"
    echo ""
    echo "  複数テンプレート（組み合わせ）:"
    echo "    $0 python docker        # Python環境 + Docker設定"
    echo "    $0 react-native ios     # React Native + iOS固有設定"
    echo "    $0 base-config my-team  # 基本設定 + チーム固有設定"
    echo ""
    echo -e "${BLUE}仕組み:${NC}"
    echo "  1. 指定したフォルダ内のファイルをGitHubからダウンロード"
    echo "  2. デフォルト設定（vscode→.vscode, git→. など）で自動配置"
    echo "  3. カスタム設定がある場合は、それを優先して適用"
    echo "  4. 複数テンプレートの場合、後から指定したものが優先"
    echo ""
    echo -e "${BLUE}テンプレートの作成手順:${NC}"
    echo "  1. GitHubリポジトリに templete/<好きな名前>/ フォルダを作成"
    echo "  2. その中に vscode/, git/, config/ などのサブフォルダを作成"
    echo "  3. 必要なファイルを配置（settings.json, .gitignore など）"
    echo "  4. このスクリプトで指定して実行"
    echo ""
    echo -e "${BLUE}カスタム設定（オプション）:${NC}"
    echo "  デフォルトと異なる配置が必要な場合、スクリプト内に設定を追加:"
    echo "    declare -A MY_TEMPLATE_FOLDER_MAPPING=([\"特殊フォルダ\"]=\"配置先\")"
    echo "    declare -A MY_TEMPLATE_FILE_MAPPING=([\"特殊ファイル\"]=\"配置先\")"    echo ""
    echo -e "${BLUE}プライベートリポジトリの場合:${NC}"
    echo "  環境変数GITHUB_TOKENにPersonal Access Tokenを設定してください:"
    echo "    export GITHUB_TOKEN='your_token_here'"
    echo "    $0 python"
    echo "  トークンの作成: GitHub Settings → Developer settings → Personal access tokens"
    echo "  必要な権限: repo (Full control of private repositories)"    exit 1
}

# ----------------------------------------------------------------------------
# メイン処理
# ----------------------------------------------------------------------------

# 引数チェック
if [ $# -eq 0 ]; then
    echo -e "${RED}エラー: テンプレートを1つ以上指定してください${NC}"
    echo ""
    usage
fi

# 内部変数（変更不要）
BASE_URL="https://raw.githubusercontent.com/${GITHUB_USER}/${REPO_NAME}/${BRANCH}"
PROJECT_DIR=$(pwd)

# 全テンプレート名を配列に格納
TEMPLATE_TYPES=("$@")

# --- セットアップ開始 ---

echo -e "${GREEN}プロジェクトテンプレート セットアップ${NC}"
echo "適用テンプレート: ${TEMPLATE_TYPES[*]}"
echo "対象ディレクトリ: ${PROJECT_DIR}"
echo ""

# 全テンプレートのファイルリストを取得
declare -a ALL_FILES=()
declare -a ALL_FILE_DESTINATIONS=()
declare -a ALL_FILE_TEMPLATES=()

for TEMPLATE_TYPE in "${TEMPLATE_TYPES[@]}"; do
    echo -e "${YELLOW}テンプレート '${TEMPLATE_TYPE}' を処理中...${NC}"

    # テンプレートマッピングを検証
    MAPPING_LIST=$(get_template_folder_mapping "${TEMPLATE_TYPE}")
    if [ -z "$MAPPING_LIST" ]; then
        echo -e "${RED}エラー: テンプレート '${TEMPLATE_TYPE}' の設定が見つかりません${NC}"
        exit 1
    fi

    # このテンプレートのファイルリストを取得
    while IFS=: read -r subfolder dest_dir; do
        echo "  ${subfolder}/ を検索中..."
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
echo -e "${YELLOW}一時ディレクトリを作成: ${TEMP_DIR}${NC}"

# クリーンアップ関数
cleanup() {
    echo -e "${YELLOW}一時ファイルをクリーンアップ中...${NC}"
    rm -rf "${TEMP_DIR}"
}

# スクリプト終了時にクリーンアップ
trap cleanup EXIT

# --- ファイルダウンロード ---

# ファイルをダウンロード
echo -e "${YELLOW}GitHubからファイルをダウンロード中...${NC}"
SUCCESS_COUNT=0
FAIL_COUNT=0

for file in "${FILES[@]}"; do
    # ダウンロードURL
    url="${BASE_URL}/${file}"

    # 保存先パス
    dest_file="${TEMP_DIR}/${file}"

    # ディレクトリを作成
    mkdir -p "$(dirname "${dest_file}")"

    # ファイルをダウンロード
    echo "  ダウンロード中: ${file}"
    if [ -n "$GITHUB_TOKEN" ]; then
        # トークン認証付きでダウンロード
        if curl -s -f -H "Authorization: token $GITHUB_TOKEN" -o "${dest_file}" "${url}"; then
            echo -e "    ${GREEN}✓ 成功${NC}"
            ((SUCCESS_COUNT++))
        else
            echo -e "    ${RED}✗ 失敗${NC}"
            ((FAIL_COUNT++))
        fi
    else
        # 認証なしでダウンロード（公開リポジトリ）
        if curl -s -f -o "${dest_file}" "${url}"; then
            echo -e "    ${GREEN}✓ 成功${NC}"
            ((SUCCESS_COUNT++))
        else
            echo -e "    ${RED}✗ 失敗${NC}"
            ((FAIL_COUNT++))
        fi
    fi
done

echo ""
echo "ダウンロード結果: 成功=${SUCCESS_COUNT}, 失敗=${FAIL_COUNT}"

if [ $SUCCESS_COUNT -eq 0 ]; then
    echo -e "${RED}エラー: ファイルのダウンロードに失敗しました${NC}"
    echo "GitHubユーザー名、リポジトリ名、ブランチ名を確認してください"
    exit 1
fi

# --- ファイル配置 ---

# マッピング情報を連想配列に格納
declare -A FOLDER_MAPPING
while IFS=: read -r subfolder dest_dir; do
    FOLDER_MAPPING["${subfolder}"]="${dest_dir}"
done <<< "$MAPPING_LIST"

# ファイルを配置
echo -e "${YELLOW}ファイルを配置中...${NC}"

# 配置先ディレクトリを保存（表示用）
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

    # JSONファイルをマージ（深い階層まで統合）
    jq -s '.[0] * .[1]' "${base_file}" "${new_file}" > "${output_file}"
    return 0
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
        # フォルダマッピングを使用
        dest_base="${FOLDER_MAPPING[$subfolder]}"
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

            # JSONマージを試行
            TEMP_MERGED="${dest_file}.merged.tmp"
            if merge_json_files "${dest_file}" "${source_path}" "${TEMP_MERGED}"; then
                mv "${TEMP_MERGED}" "${dest_file}"
                echo -e "  ${GREEN}✓${NC} ${filename} → ${display_dir}/ ${YELLOW}[JSON統合]${NC} ${mapping_type}"
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

echo ""
echo -e "${GREEN}セットアップが完了しました！${NC}"
echo "適用テンプレート: ${TEMPLATE_TYPES[*]}"
echo ""
echo "配置先:"
for dest in "${!DEPLOYED_DIRS[@]}"; do
    if [ "$dest" = "." ]; then
        echo "  - プロジェクトルート"
    else
        echo "  - ${dest}/"
    fi
done
echo ""
echo "次のステップ:"
echo "1. エディタ/IDEでプロジェクトを開く"
echo "2. 必要な依存関係やツールをインストール"
echo "3. 設定ファイルの内容を確認・カスタマイズ"
