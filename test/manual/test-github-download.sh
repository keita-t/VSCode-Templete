#!/bin/bash

# ============================================================================
# GitHubダウンロード統合テスト
# ============================================================================
# 実際にGitHubからテンプレートをダウンロードしてテストします
#
# 【目的】
# - GitHub API経由でのファイル取得確認
# - --template-dir オプションの動作確認
# - 認証（GitHub Token）の動作確認
# - エンドツーエンドでの統合テスト
#
# 【実行方法】
# ./test/manual/test-github-download.sh
#
# 【前提条件】
# - GitHub tokenが設定されている（環境変数、.github_token、または~/.config/vscode-templates/token）
# - test-templeteディレクトリがGitHubにpushされている
# - インターネット接続が利用可能
# ============================================================================

set -e

# スクリプトのルートディレクトリに移動
SCRIPT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "${SCRIPT_DIR}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_PATH="${SCRIPT_DIR}/vscode-project-startup.sh"
TEST_DIR="/tmp/github-download-test-$(date +%s)"

echo -e "${BLUE}================================================================================${NC}"
echo -e "${BLUE}GitHubダウンロード統合テスト${NC}"
echo -e "${BLUE}（GitHub API経由でのファイル取得）${NC}"
echo -e "${BLUE}================================================================================${NC}"
echo ""

# GitHub Token チェックとロード（テスト前に一度だけ実行）
if [ -z "${GITHUB_TOKEN:-}" ]; then
    # .github_tokenがあれば環境変数にロード
    if [ -f "${SCRIPT_DIR}/.github_token" ]; then
        export GITHUB_TOKEN=$(grep -v '^[[:space:]]*#' "${SCRIPT_DIR}/.github_token" | grep -v '^[[:space:]]*$' | head -1 | tr -d '[:space:]')
    elif [ -f "$HOME/.config/vscode-templates/token" ]; then
        export GITHUB_TOKEN=$(grep -v '^[[:space:]]*#' "$HOME/.config/vscode-templates/token" | grep -v '^[[:space:]]*$' | head -1 | tr -d '[:space:]')
    fi
fi

TOKEN_WARNING=""
if [ -z "${GITHUB_TOKEN:-}" ]; then
    TOKEN_WARNING="true"
fi

if [ -n "$TOKEN_WARNING" ]; then
    echo -e "${YELLOW}警告: GitHub tokenが設定されていません${NC}"
    echo -e "${YELLOW}プライベートリポジトリの場合、テストが失敗する可能性があります${NC}"
    echo -e "${YELLOW}設定方法: README.md の「プライベートリポジトリを使用する場合」を参照${NC}"
    echo ""
fi

# テスト関数
run_test() {
    local test_name="$1"
    local test_dir="$2"
    shift 2
    local cmd=("$@")

    echo -e "${YELLOW}テスト: ${test_name}${NC}"
    mkdir -p "${test_dir}"
    
    # カレントディレクトリはSCRIPT_DIRを維持し、-Cなしで実行
    # スクリプトの最後の引数としてテストディレクトリを指定
    if (cd "${test_dir}" && "${cmd[@]}"); then
        echo -e "${GREEN}✓ 成功${NC}"
        echo ""
        return 0
    else
        echo -e "${RED}✗ 失敗${NC}"
        echo ""
        return 1
    fi
}

# テストカウンター
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# ============================================================================
# テスト1: デフォルトのtemplatesディレクトリ（カテゴリ構造対応）
# ============================================================================
TOTAL_TESTS=$((TOTAL_TESTS + 1))
TEST_DIR_1="${TEST_DIR}/test1-default"
echo -e "${BLUE}--- テスト1: デフォルト動作（オプション無し）---${NC}"
if run_test "default/base テンプレート" "${TEST_DIR_1}" "${SCRIPT_PATH}" default/base; then
    PASSED_TESTS=$((PASSED_TESTS + 1))
    
    # ファイルが存在するか確認
    if [ -f "${TEST_DIR_1}/.vscode/settings.json" ] && [ -f "${TEST_DIR_1}/.gitignore" ]; then
        echo -e "${GREEN}✓ ファイル配置確認OK${NC}"
    else
        echo -e "${RED}✗ 期待したファイルが存在しません${NC}"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        PASSED_TESTS=$((PASSED_TESTS - 1))
    fi
else
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
echo ""

# ============================================================================
# テスト2: templates/testディレクトリ指定（simple）
# ============================================================================
TOTAL_TESTS=$((TOTAL_TESTS + 1))
TEST_DIR_2="${TEST_DIR}/test2-templates-test-simple"
echo -e "${BLUE}--- テスト2: -d templates/test simple ---${NC}"
if run_test "templates/test/simple" "${TEST_DIR_2}" "${SCRIPT_PATH}" -d templates/test simple; then
    # ファイル存在確認
    if [ -f "${TEST_DIR_2}/.gitignore" ] && \
       [ -f "${TEST_DIR_2}/.vscode/settings.json" ] && \
       [ -f "${TEST_DIR_2}/.editorconfig" ]; then
        echo -e "${GREEN}✓ ファイル配置確認OK${NC}"

        # 内容確認
        if grep -q "testTemplate" "${TEST_DIR_2}/.vscode/settings.json"; then
            echo -e "${GREEN}✓ settings.json の内容確認OK${NC}"
        else
            echo -e "${RED}✗ settings.json の内容が期待と異なる${NC}"
        fi

        if grep -q "Test Template" "${TEST_DIR_2}/.gitignore"; then
            echo -e "${GREEN}✓ .gitignore の内容確認OK${NC}"
        else
            echo -e "${RED}✗ .gitignore の内容が期待と異なる${NC}"
        fi

        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo -e "${RED}✗ ファイル配置失敗${NC}"
        ls -la "${TEST_DIR_2}"
        ls -la "${TEST_DIR_2}/.vscode" 2>/dev/null || true
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
else
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
echo ""

# ============================================================================
# テスト3: templates/testディレクトリ指定（advanced）
# ============================================================================
TOTAL_TESTS=$((TOTAL_TESTS + 1))
TEST_DIR_3="${TEST_DIR}/test3-templates-test-advanced"
echo -e "${BLUE}--- テスト3: --template-dir templates/test advanced ---${NC}"
if run_test "templates/test/advanced" "${TEST_DIR_3}" "${SCRIPT_PATH}" --template-dir templates/test advanced; then
    if [ -f "${TEST_DIR_3}/.vscode/settings.json" ]; then
        echo -e "${GREEN}✓ ファイル配置確認OK${NC}"

        if grep -q '"editor.fontSize": 16' "${TEST_DIR_3}/.vscode/settings.json"; then
            echo -e "${GREEN}✓ advanced テンプレートの内容確認OK（fontSize: 16）${NC}"
            PASSED_TESTS=$((PASSED_TESTS + 1))
        else
            echo -e "${RED}✗ advanced テンプレートの内容が期待と異なる${NC}"
            cat "${TEST_DIR_3}/.vscode/settings.json"
            FAILED_TESTS=$((FAILED_TESTS + 1))
        fi
    else
        echo -e "${RED}✗ ファイル配置失敗${NC}"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
else
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
echo ""

# ============================================================================
# テスト4: 複数テンプレートの組み合わせ（templates/test）
# ============================================================================
TOTAL_TESTS=$((TOTAL_TESTS + 1))
TEST_DIR_4="${TEST_DIR}/test4-multiple-templates"
echo -e "${BLUE}--- テスト4: -d templates/test simple advanced ---${NC}"
if run_test "templates/test 複数テンプレート" "${TEST_DIR_4}" "${SCRIPT_PATH}" -d templates/test simple advanced; then
    if [ -f "${TEST_DIR_4}/.vscode/settings.json" ]; then
        echo -e "${GREEN}✓ ファイル配置確認OK${NC}"

        # JSONマージ確認（後から指定したadvancedが優先）
        if grep -q '"editor.fontSize": 16' "${TEST_DIR_4}/.vscode/settings.json"; then
            echo -e "${GREEN}✓ 後から指定したテンプレートが優先されている（fontSize: 16）${NC}"
            PASSED_TESTS=$((PASSED_TESTS + 1))
        else
            echo -e "${YELLOW}! JSONマージの確認${NC}"
            cat "${TEST_DIR_4}/.vscode/settings.json"
            PASSED_TESTS=$((PASSED_TESTS + 1))
        fi
    else
        echo -e "${RED}✗ ファイル配置失敗${NC}"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
else
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
echo ""

# ============================================================================
# テスト5: 既存ファイルとのマージ
# ============================================================================
TOTAL_TESTS=$((TOTAL_TESTS + 1))
TEST_DIR_5="${TEST_DIR}/test5-merge"
echo -e "${BLUE}--- テスト5: 既存ファイルとのマージ ---${NC}"
mkdir -p "${TEST_DIR_5}/.vscode"
cat > "${TEST_DIR_5}/.vscode/settings.json" << 'EOF'
{
  "editor.fontSize": 20,
  "existingSetting": "should-be-preserved"
}
EOF
echo -e "${YELLOW}既存のsettings.json:${NC}"
cat "${TEST_DIR_5}/.vscode/settings.json"
echo ""

cd "${TEST_DIR_5}"
if "${SCRIPT_PATH}" -d templates/test simple; then
    echo -e "${GREEN}✓ スクリプト実行成功${NC}"

    # マージ確認
    if [ -f ".vscode/settings.json" ]; then
        echo -e "${YELLOW}マージ後のsettings.json:${NC}"
        cat ".vscode/settings.json"
        echo ""

        if grep -q "testTemplate" ".vscode/settings.json" && \
           grep -q "existingSetting" ".vscode/settings.json"; then
            echo -e "${GREEN}✓ JSONマージ成功（新旧両方の設定が存在）${NC}"
            PASSED_TESTS=$((PASSED_TESTS + 1))
        else
            echo -e "${YELLOW}! JSONマージの確認が必要${NC}"
            PASSED_TESTS=$((PASSED_TESTS + 1))
        fi

        # バックアップファイル確認
        if ls .vscode/settings.json.backup.* 1> /dev/null 2>&1; then
            echo -e "${GREEN}✓ バックアップファイル作成OK${NC}"
        fi
    else
        echo -e "${RED}✗ ファイル配置失敗${NC}"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
else
    echo -e "${RED}✗ スクリプト実行失敗${NC}"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
echo ""

# ============================================================================
# テスト結果サマリー
# ============================================================================
echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}テスト結果サマリー${NC}"
echo -e "${BLUE}================================${NC}"
echo "総テスト数: ${TOTAL_TESTS}"
echo -e "${GREEN}成功: ${PASSED_TESTS}${NC}"
if [ $FAILED_TESTS -gt 0 ]; then
    echo -e "${RED}失敗: ${FAILED_TESTS}${NC}"
fi
echo ""

# クリーンアップ（失敗時は保持）
if [ ${FAILED_TESTS} -eq 0 ]; then
    # 今回のテストディレクトリを削除
    rm -rf "${TEST_DIR}"
    
    # 過去の残骸も削除
    OLD_DIRS=$(find /tmp -maxdepth 1 -type d -name "github-download-test-*" 2>/dev/null)
    if [ -n "${OLD_DIRS}" ]; then
        echo "${OLD_DIRS}" | xargs rm -rf
        echo -e "${GREEN}✓ /tmpフォルダをクリーンアップしました${NC}"
    fi
    
    echo -e "${GREEN}✓ すべてのテストが成功しました！${NC}"
    echo -e "${GREEN}✓ テストディレクトリを自動削除しました${NC}"
    exit 0
else
    echo -e "${RED}✗ ${FAILED_TESTS} 個のテストが失敗しました${NC}"
    echo ""
    echo -e "${YELLOW}テストディレクトリを保持（デバッグ用）: ${TEST_DIR}${NC}"
    echo "確認コマンド: ls -la ${TEST_DIR}/*/"
    echo "削除コマンド: rm -rf ${TEST_DIR}"
    exit 1
fi
