#!/bin/bash

# ============================================================================
# ローカルテンプレートテスト（Python版）
# ============================================================================
# Python版スクリプトを使用して、ローカルのtemplates/testディレクトリをテストします
#
# 【実行方法】
# ./test/manual/test-local-templates.sh
#
# 【前提条件】
# - templates/testディレクトリがローカルに存在すること
# - Python 3.7+ がインストールされていること
# - pyyaml, tomli, tomli-w がインストールされていること
# ============================================================================

set -e

# スクリプトのルートディレクトリに移動
SCRIPT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "${SCRIPT_DIR}"

# Python版スクリプトを使用
SETUP_SCRIPT="${SCRIPT_DIR}/vscode-project-startup.py"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

TEST_TEMPLATE_DIR="${SCRIPT_DIR}/templates"
TEST_DIR="/tmp/local-template-test-$(date +%s)"

echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}Python版テンプレートテスト${NC}"
echo -e "${BLUE}（ローカルテンプレート使用）${NC}"
echo -e "${BLUE}================================${NC}"
echo ""

# Python スクリプトの存在確認
if [ ! -f "${SETUP_SCRIPT}" ]; then
    echo -e "${RED}エラー: ${SETUP_SCRIPT} が見つかりません${NC}"
    exit 1
fi

# templates/testディレクトリの存在確認
if [ ! -d "${TEST_TEMPLATE_DIR}/test" ]; then
    echo -e "${RED}エラー: templates/testディレクトリが見つかりません${NC}"
    echo "場所: ${TEST_TEMPLATE_DIR}/test"
    exit 1
fi

echo -e "${GREEN}✓ Python スクリプト: ${SETUP_SCRIPT}${NC}"
echo -e "${GREEN}✓ テンプレートディレクトリ: ${TEST_TEMPLATE_DIR}${NC}"
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
    cd "${test_dir}"
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
        echo "実際の内容:"
        cat "$file" | head -20
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
run_test "1" "simple テンプレート配置" "${TEST_DIR_1}"

python3 "${SETUP_SCRIPT}" -l "${TEST_TEMPLATE_DIR}" -d test simple

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
run_test "2" "advanced テンプレート配置" "${TEST_DIR_2}"

python3 "${SETUP_SCRIPT}" -l "${TEST_TEMPLATE_DIR}" -d test advanced

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
run_test "3" "複数テンプレート（simple → advanced）" "${TEST_DIR_3}"

python3 "${SETUP_SCRIPT}" -l "${TEST_TEMPLATE_DIR}" -d test simple advanced

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
# テスト4: 既存ファイルが存在しない場合のセットアップ
# ============================================================================
TOTAL_TESTS=$((TOTAL_TESTS + 1))
TEST_DIR_4="${TEST_DIR}/test4-fresh"
run_test "4" "クリーンプロジェクトへの適用" "${TEST_DIR_4}"

python3 "${SETUP_SCRIPT}" -l "${TEST_TEMPLATE_DIR}" -d test simple

if verify_file_exists "${TEST_DIR_4}/.vscode/settings.json" && \
   verify_file_exists "${TEST_DIR_4}/.gitignore"; then
    echo -e "${GREEN}[SUCCESS] テスト 4 完了${NC}"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${RED}[FAILED] テスト 4 失敗${NC}"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
echo ""

# ============================================================================
# テスト5: ディレクトリ構造の確認
# ============================================================================
TOTAL_TESTS=$((TOTAL_TESTS + 1))
TEST_DIR_5="${TEST_DIR}/test5-structure"
run_test "5" "ディレクトリ構造の確認" "${TEST_DIR_5}"

python3 "${SETUP_SCRIPT}" -l "${TEST_TEMPLATE_DIR}" -d test simple

# .vscodeディレクトリが正しく作成されているか
if [ -d "${TEST_DIR_5}/.vscode" ] && \
   verify_file_exists "${TEST_DIR_5}/.vscode/settings.json"; then
    echo -e "${GREEN}[SUCCESS] テスト 5 完了${NC}"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${RED}[FAILED] テスト 5 失敗${NC}"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
echo ""

# ============================================================================
# テスト6: JSONマージ機能
# ============================================================================
TOTAL_TESTS=$((TOTAL_TESTS + 1))
TEST_DIR_6="${TEST_DIR}/test6-json-merge"
run_test "6" "JSONマージ機能" "${TEST_DIR_6}"

# 既存のsettings.jsonを作成
mkdir -p "${TEST_DIR_6}/.vscode"
cat > "${TEST_DIR_6}/.vscode/settings.json" << 'EOF'
{
  "editor.fontSize": 20,
  "existingSetting": "should-be-preserved",
  "editor.tabSize": 4
}
EOF

echo "既存のsettings.json:"
cat "${TEST_DIR_6}/.vscode/settings.json"
echo ""

# テンプレートを適用（マージが発生するはず）
python3 "${SETUP_SCRIPT}" -l "${TEST_TEMPLATE_DIR}" -d test merge-json

echo "マージ後のsettings.json:"
cat "${TEST_DIR_6}/.vscode/settings.json"
echo ""

# 既存設定が保持され、新しい設定も追加されているか確認
if verify_file_content "${TEST_DIR_6}/.vscode/settings.json" '"existingSetting": "should-be-preserved"' && \
   verify_file_content "${TEST_DIR_6}/.vscode/settings.json" '"newSetting": "from-template"'; then
    echo -e "${GREEN}[SUCCESS] テスト 6 完了（JSONマージ成功）${NC}"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${RED}[FAILED] テスト 6 失敗${NC}"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
echo ""

# ============================================================================
# テスト7: YAMLマージ機能
# ============================================================================
TOTAL_TESTS=$((TOTAL_TESTS + 1))
TEST_DIR_7="${TEST_DIR}/test7-yaml-merge"
run_test "7" "YAMLマージ機能" "${TEST_DIR_7}"

# PyYAML がインストールされているか確認
if python3 -c "import yaml" 2>/dev/null; then
    # 既存のdocker-compose.ymlを作成
    mkdir -p "${TEST_DIR_7}"
    cat > "${TEST_DIR_7}/docker-compose.yml" << 'EOF'
version: '3.8'
services:
  existing-service:
    image: nginx:latest
    ports:
      - "8080:80"
EOF

    echo "既存のdocker-compose.yml:"
    cat "${TEST_DIR_7}/docker-compose.yml"
    echo ""

    # テンプレートを適用（マージが発生するはず）
    python3 "${SETUP_SCRIPT}" -l "${TEST_TEMPLATE_DIR}" -d test merge-yaml

    echo "マージ後のdocker-compose.yml:"
    cat "${TEST_DIR_7}/docker-compose.yml"
    echo ""

    # 既存サービスと新規サービスの両方が存在するか確認
    if verify_file_content "${TEST_DIR_7}/docker-compose.yml" "existing-service" && \
       verify_file_content "${TEST_DIR_7}/docker-compose.yml" "web"; then
        echo -e "${GREEN}[SUCCESS] テスト 7 完了（YAMLマージ成功）${NC}"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo -e "${RED}[FAILED] テスト 7 失敗${NC}"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
else
    echo -e "${YELLOW}[SKIPPED] PyYAML がインストールされていません: pip install pyyaml${NC}"
    TOTAL_TESTS=$((TOTAL_TESTS - 1))
fi
echo ""

# ============================================================================
# テスト8: TOMLマージ機能
# ============================================================================
TOTAL_TESTS=$((TOTAL_TESTS + 1))
TEST_DIR_8="${TEST_DIR}/test8-toml-merge"
run_test "8" "TOMLマージ機能" "${TEST_DIR_8}"

# tomli がインストールされているか確認
if python3 -c "import tomli, tomli_w" 2>/dev/null || python3 -c "import tomllib" 2>/dev/null; then
    # 既存のpyproject.tomlを作成
    mkdir -p "${TEST_DIR_8}"
    cat > "${TEST_DIR_8}/pyproject.toml" << 'EOF'
[project]
name = "existing-project"
version = "1.0.0"

[project.dependencies]
python = "^3.8"
EOF

    echo "既存のpyproject.toml:"
    cat "${TEST_DIR_8}/pyproject.toml"
    echo ""

    # テンプレートを適用（マージが発生するはず）
    # set -e を一時的に無効化（マージ失敗時もテストを継続）
    set +e
    python3 "${SETUP_SCRIPT}" -l "${TEST_TEMPLATE_DIR}" -d test merge-toml
    set -e

    echo "マージ後のpyproject.toml:"
    cat "${TEST_DIR_8}/pyproject.toml" 2>/dev/null || echo "(ファイルが存在しないか、マージ失敗)"
    echo ""

    # 既存設定と新規設定の両方が存在するか確認
    # マージが成功した場合のみチェック
    if [ -f "${TEST_DIR_8}/pyproject.toml" ] && \
       verify_file_content "${TEST_DIR_8}/pyproject.toml" "existing-project" && \
       verify_file_content "${TEST_DIR_8}/pyproject.toml" "requests"; then
        echo -e "${GREEN}[SUCCESS] テスト 8 完了（TOMLマージ成功）${NC}"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        # tomli がインストールされていない場合はスキップとして扱う
        if ! python3 -c "import tomli, tomli_w" 2>/dev/null; then
            echo -e "${YELLOW}[SKIPPED] テスト 8: tomli/tomli_w がインストールされていません${NC}"
            TOTAL_TESTS=$((TOTAL_TESTS - 1))
        else
            echo -e "${RED}[FAILED] テスト 8 失敗${NC}"
            FAILED_TESTS=$((FAILED_TESTS + 1))
        fi
    fi
else
    echo -e "${YELLOW}[SKIPPED] tomli/tomli_w がインストールされていません: pip install tomli tomli-w${NC}"
    TOTAL_TESTS=$((TOTAL_TESTS - 1))
fi
echo ""

# ============================================================================
# テスト結果まとめ
# ============================================================================
echo -e "${BLUE}================================================================================${NC}"
echo -e "${BLUE}テスト結果まとめ${NC}"
echo -e "${BLUE}================================================================================${NC}"
echo ""
echo "合計: ${TOTAL_TESTS} テスト"
echo -e "${GREEN}成功: ${PASSED_TESTS}${NC}"
if [ ${FAILED_TESTS} -gt 0 ]; then
    echo -e "${RED}失敗: ${FAILED_TESTS}${NC}"
else
    echo "失敗: ${FAILED_TESTS}"
fi
echo ""

if [ ${FAILED_TESTS} -eq 0 ]; then
    echo -e "${GREEN}✓ すべてのテストが成功しました！${NC}"
    exit 0
else
    echo -e "${RED}✗ 一部のテストが失敗しました${NC}"
    exit 1
fi
