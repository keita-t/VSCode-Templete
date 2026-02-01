#!/bin/bash

# ============================================================================
# ローカルテンプレートテスト
# ============================================================================
# ローカルのtemplates/testディレクトリを直接使用してテストします
# GitHubアクセス不要で高速にテストできます
#
# 【目的】
# - スクリプトのコアロジックをテスト（ファイル配置、マージなど）
# - GitHub APIに依存しない開発中のテスト
# - CI/CDでのオフラインテスト
#
# 【実行方法】
# ./test/manual/test-local-templates.sh
#
# 【前提条件】
# - templates/testディレクトリがローカルに存在すること
# - GitHubアクセス不要（完全オフラインで実行可能）
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

TEST_TEMPLETE_DIR="${SCRIPT_DIR}/templates/test"
TEST_DIR="/tmp/local-template-test-$(date +%s)"

echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}ローカルテンプレートテスト${NC}"
echo -e "${BLUE}（GitHubアクセス不要）${NC}"
echo -e "${BLUE}================================${NC}"
echo ""

# templates/testディレクトリの存在確認
if [ ! -d "${TEST_TEMPLETE_DIR}" ]; then
    echo -e "${RED}エラー: templates/testディレクトリが見つかりません${NC}"
    echo "場所: ${TEST_TEMPLETE_DIR}"
    exit 1
fi

echo -e "${GREEN}✓ templates/testディレクトリを確認: ${TEST_TEMPLETE_DIR}${NC}"
echo ""

# テスト関数
run_test() {
    local test_num="$1"
    local test_name="$2"
    local test_dir="$3"
    
    echo -e "${BLUE}================================================================================${NC}"
    echo -e "${BLUE}テスト ${test_num}: ${test_name}${NC}"
    echo -e "${BLUE}================================================================================${NC}"
    
    mkdir -p "${test_dir}"
    return 0
}

verify_file_exists() {
    local file="$1"
    if [ -f "$file" ]; then
        echo -e "${GREEN}  ✓ ファイル存在: $(basename "$file")${NC}"
        return 0
    else
        echo -e "${RED}  ✗ ファイル不在: $(basename "$file")${NC}"
        return 1
    fi
}

verify_file_content() {
    local file="$1"
    local expected="$2"
    if grep -q "$expected" "$file" 2>/dev/null; then
        echo -e "${GREEN}  ✓ 内容確認OK: $expected${NC}"
        return 0
    else
        echo -e "${RED}  ✗ 内容不一致: $expected が見つかりません${NC}"
        return 1
    fi
}

# テストカウンター
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# ============================================================================
# テスト1: simple テンプレートの配置
# ============================================================================
TOTAL_TESTS=$((TOTAL_TESTS + 1))
TEST_DIR_1="${TEST_DIR}/test1-simple"
run_test "1/5" "simple テンプレート配置" "${TEST_DIR_1}"

echo "ローカルテンプレートをコピー..."
# test-templete/simpleから直接コピー（ドットファイルも含む）
if [ -d "${TEST_TEMPLETE_DIR}/simple/vscode" ]; then
    mkdir -p "${TEST_DIR_1}/.vscode"
    cp "${TEST_TEMPLETE_DIR}/simple/vscode/"* "${TEST_DIR_1}/.vscode/" 2>/dev/null || true
fi
if [ -d "${TEST_TEMPLETE_DIR}/simple/git" ]; then
    shopt -s dotglob
    cp "${TEST_TEMPLETE_DIR}/simple/git/"* "${TEST_DIR_1}/" 2>/dev/null || true
    shopt -u dotglob
fi
if [ -d "${TEST_TEMPLETE_DIR}/simple/config" ]; then
    shopt -s dotglob
    cp "${TEST_TEMPLETE_DIR}/simple/config/"* "${TEST_DIR_1}/" 2>/dev/null || true
    shopt -u dotglob
fi

if verify_file_exists "${TEST_DIR_1}/.vscode/settings.json" && \
   verify_file_exists "${TEST_DIR_1}/.gitignore" && \
   verify_file_exists "${TEST_DIR_1}/.editorconfig" && \
   verify_file_content "${TEST_DIR_1}/.vscode/settings.json" '"editor.fontSize": 14'; then
    echo -e "${GREEN}[SUCCESS] テスト 1 完了${NC}"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${RED}[FAILED] テスト 1 失敗${NC}"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
echo ""

# ============================================================================
# テスト2: advanced テンプレートの配置
# ============================================================================
TOTAL_TESTS=$((TOTAL_TESTS + 1))
TEST_DIR_2="${TEST_DIR}/test2-advanced"
run_test "2/5" "advanced テンプレート配置" "${TEST_DIR_2}"

echo "ローカルテンプレートをコピー..."
if [ -d "${TEST_TEMPLETE_DIR}/advanced/vscode" ]; then
    mkdir -p "${TEST_DIR_2}/.vscode"
    cp "${TEST_TEMPLETE_DIR}/advanced/vscode/"* "${TEST_DIR_2}/.vscode/" 2>/dev/null || true
fi

if verify_file_exists "${TEST_DIR_2}/.vscode/settings.json" && \
   verify_file_content "${TEST_DIR_2}/.vscode/settings.json" '"editor.fontSize": 16'; then
    echo -e "${GREEN}[SUCCESS] テスト 2 完了${NC}"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${RED}[FAILED] テスト 2 失敗${NC}"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
echo ""

# ============================================================================
# テスト3: 複数テンプレートの適用順序
# ============================================================================
TOTAL_TESTS=$((TOTAL_TESTS + 1))
TEST_DIR_3="${TEST_DIR}/test3-multiple"
run_test "3/5" "複数テンプレート（simple → advanced）" "${TEST_DIR_3}"

echo "simpleテンプレートを適用..."
if [ -d "${TEST_TEMPLETE_DIR}/simple/vscode" ]; then
    mkdir -p "${TEST_DIR_3}/.vscode"
    cp "${TEST_TEMPLETE_DIR}/simple/vscode/"* "${TEST_DIR_3}/.vscode/" 2>/dev/null || true
fi

echo "advancedテンプレートを上書き適用..."
if [ -d "${TEST_TEMPLETE_DIR}/advanced/vscode" ]; then
    cp "${TEST_TEMPLETE_DIR}/advanced/vscode/"* "${TEST_DIR_3}/.vscode/" 2>/dev/null || true
fi

# 後から適用したadvancedの値（16）が優先されるべき
if verify_file_exists "${TEST_DIR_3}/.vscode/settings.json" && \
   verify_file_content "${TEST_DIR_3}/.vscode/settings.json" '"editor.fontSize": 16'; then
    echo -e "${GREEN}[SUCCESS] テスト 3 完了（後から適用したテンプレートが優先）${NC}"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${RED}[FAILED] テスト 3 失敗${NC}"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
echo ""

# ============================================================================
# テスト4: JSONマージ（jq使用）
# ============================================================================
TOTAL_TESTS=$((TOTAL_TESTS + 1))
TEST_DIR_4="${TEST_DIR}/test4-merge"
run_test "4/5" "JSONマージ機能" "${TEST_DIR_4}"

# 既存のsettings.jsonを作成
mkdir -p "${TEST_DIR_4}/.vscode"
cat > "${TEST_DIR_4}/.vscode/settings.json" << 'EOF'
{
  "editor.fontSize": 20,
  "existingSetting": "should-be-preserved",
  "editor.tabSize": 4
}
EOF

echo "既存のsettings.json:"
cat "${TEST_DIR_4}/.vscode/settings.json"
echo ""

# jqが利用可能な場合のみマージテスト
if command -v jq &> /dev/null; then
    echo "jq利用可能、マージを実行..."
    
    # simpleテンプレートのsettings.jsonとマージ
    if [ -f "${TEST_TEMPLETE_DIR}/simple/vscode/settings.json" ]; then
        # バックアップ作成
        cp "${TEST_DIR_4}/.vscode/settings.json" "${TEST_DIR_4}/.vscode/settings.json.backup"
        
        # jqでマージ（右側が優先）
        jq -s '.[0] * .[1]' \
            "${TEST_DIR_4}/.vscode/settings.json.backup" \
            "${TEST_TEMPLETE_DIR}/simple/vscode/settings.json" \
            > "${TEST_DIR_4}/.vscode/settings.json.tmp"
        mv "${TEST_DIR_4}/.vscode/settings.json.tmp" "${TEST_DIR_4}/.vscode/settings.json"
        
        echo "マージ後のsettings.json:"
        cat "${TEST_DIR_4}/.vscode/settings.json"
        echo ""
        
        # 検証: 既存設定が保持され、新しい設定が追加されている
        if verify_file_content "${TEST_DIR_4}/.vscode/settings.json" '"existingSetting": "should-be-preserved"' && \
           verify_file_content "${TEST_DIR_4}/.vscode/settings.json" '"editor.fontSize": 14' && \
           verify_file_exists "${TEST_DIR_4}/.vscode/settings.json.backup"; then
            echo -e "${GREEN}[SUCCESS] テスト 4 完了（JSONマージ成功）${NC}"
            PASSED_TESTS=$((PASSED_TESTS + 1))
        else
            echo -e "${RED}[FAILED] テスト 4 失敗${NC}"
            FAILED_TESTS=$((FAILED_TESTS + 1))
        fi
    else
        echo -e "${YELLOW}[SKIPPED] simpleテンプレートのsettings.jsonが見つかりません${NC}"
        TOTAL_TESTS=$((TOTAL_TESTS - 1))
    fi
else
    echo -e "${YELLOW}[SKIPPED] jqがインストールされていません${NC}"
    echo "インストール: brew install jq または apt-get install jq"
    TOTAL_TESTS=$((TOTAL_TESTS - 1))
fi
echo ""

# ============================================================================
# テスト5: ファイル構造の検証
# ============================================================================
TOTAL_TESTS=$((TOTAL_TESTS + 1))
TEST_DIR_5="${TEST_DIR}/test5-structure"
run_test "5/5" "ディレクトリ構造の検証" "${TEST_DIR_5}"

echo "完全な構造をコピー..."
if [ -d "${TEST_TEMPLETE_DIR}/simple" ]; then
    # vscode/
    if [ -d "${TEST_TEMPLETE_DIR}/simple/vscode" ]; then
        mkdir -p "${TEST_DIR_5}/.vscode"
        cp "${TEST_TEMPLETE_DIR}/simple/vscode/"* "${TEST_DIR_5}/.vscode/" 2>/dev/null || true
    fi
    # git/ (ドットファイル含む)
    if [ -d "${TEST_TEMPLETE_DIR}/simple/git" ]; then
        shopt -s dotglob
        cp "${TEST_TEMPLETE_DIR}/simple/git/"* "${TEST_DIR_5}/" 2>/dev/null || true
        shopt -u dotglob
    fi
    # config/ (ドットファイル含む)
    if [ -d "${TEST_TEMPLETE_DIR}/simple/config" ]; then
        shopt -s dotglob
        cp "${TEST_TEMPLETE_DIR}/simple/config/"* "${TEST_DIR_5}/" 2>/dev/null || true
        shopt -u dotglob
    fi
fi

echo "ディレクトリ構造:"
tree -a "${TEST_DIR_5}" 2>/dev/null || ls -laR "${TEST_DIR_5}"
echo ""

# 期待されるファイルがすべて存在するか確認
FILES_OK=true
for file in .vscode/settings.json .gitignore .editorconfig; do
    if [ ! -f "${TEST_DIR_5}/${file}" ]; then
        FILES_OK=false
        echo -e "${RED}  ✗ 不足: ${file}${NC}"
    fi
done

if [ "$FILES_OK" = true ]; then
    echo -e "${GREEN}[SUCCESS] テスト 5 完了（すべてのファイルが正しく配置）${NC}"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${RED}[FAILED] テスト 5 失敗${NC}"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
echo ""

# ============================================================================
# テスト結果サマリー
# ============================================================================
echo -e "${BLUE}================================================================================${NC}"
echo -e "${BLUE}テスト結果サマリー${NC}"
echo -e "${BLUE}================================================================================${NC}"
echo "総テスト数: ${TOTAL_TESTS}"
echo -e "${GREEN}成功: ${PASSED_TESTS}${NC}"
echo -e "${RED}失敗: ${FAILED_TESTS}${NC}"
echo ""

# クリーンアップ（失敗時は保持）
if [ ${FAILED_TESTS} -eq 0 ]; then
    rm -rf "${TEST_DIR}"
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
