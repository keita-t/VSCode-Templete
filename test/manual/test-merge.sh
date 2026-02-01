#!/bin/bash

# ============================================================================
# JSONマージ機能の手動統合テスト
# ============================================================================
#
# 【目的】
# - JSONマージ機能の詳細な動作確認
# - マージ前後のファイル内容を視覚的に比較
# - jqコマンドの動作検証
#
# 【実行方法】
# ./test/manual/test-merge.sh
#
# 【依存関係】
# - jq: JSONプロセッサ（マージ機能に必要）
#
# 【注意】
# - このテストは自動ユニットテスト（BATS）ではありません
# - CI/CDではなく、手動での検証用です
# - 自動テストは test/vscode-project-startup.bats を使用してください
# ============================================================================

cd "$(dirname "$0")"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# マージ設定
DEFAULT_MERGE_SETTING=(
    "*.json"
    "*.code-snippets"
)

# should_merge_file関数
should_merge_file() {
    local filename="$1"

    for pattern in "${DEFAULT_MERGE_SETTING[@]}"; do
        if [[ "$filename" == $pattern ]]; then
            return 0
        fi
    done

    return 1
}

# merge_json_files関数
merge_json_files() {
    local base_file="$1"
    local new_file="$2"
    local output_file="$3"

    if ! command -v jq &> /dev/null; then
        echo -e "  ${YELLOW}注意: jqがインストールされていないため、JSONマージをスキップ（上書き）${NC}"
        return 1
    fi

    jq -s '.[0] * .[1]' "${base_file}" "${new_file}" > "${output_file}"
    return 0
}

# テストディレクトリ作成
TEST_DIR="/tmp/json-merge-test-$(date +%s)"
mkdir -p "${TEST_DIR}/.vscode"

echo -e "${GREEN}=== JSONマージ機能テスト ===${NC}"
echo "テストディレクトリ: ${TEST_DIR}"
echo ""

# 既存ファイルを作成
cat > "${TEST_DIR}/.vscode/settings.json" << 'EOF'
{
  "editor.fontSize": 14,
  "editor.tabSize": 2,
  "files.autoSave": "afterDelay",
  "existing.setting": "should-be-preserved",
  "existing.object": {
    "key1": "value1",
    "key2": "value2"
  }
}
EOF

echo -e "${BLUE}1. 既存settings.json:${NC}"
cat "${TEST_DIR}/.vscode/settings.json"
echo ""

# 新しいファイルを作成（base/vscode/settings.jsonの一部）
cat > "${TEST_DIR}/.vscode/new_settings.json" << 'EOF'
{
  "editor.fontSize": 16,
  "editor.formatOnSave": true,
  "files.exclude": {
    "**/.git": true,
    "**/__pycache__": true
  },
  "new.setting": "should-be-added",
  "existing.object": {
    "key2": "updated-value2",
    "key3": "value3"
  }
}
EOF

echo -e "${BLUE}2. 新しいsettings.json (テンプレートから):${NC}"
cat "${TEST_DIR}/.vscode/new_settings.json"
echo ""

# マージテスト
filename="settings.json"
dest_file="${TEST_DIR}/.vscode/settings.json"
source_file="${TEST_DIR}/.vscode/new_settings.json"

echo -e "${YELLOW}3. マージ処理実行中...${NC}"

if should_merge_file "${filename}"; then
    echo -e "  ${GREEN}✓${NC} settings.json はマージ対象です"

    # バックアップ作成
    BACKUP_FILE="${dest_file}.backup.$(date +%Y%m%d_%H%M%S)"
    cp "${dest_file}" "${BACKUP_FILE}"
    echo -e "  ${GREEN}✓${NC} バックアップ作成: $(basename ${BACKUP_FILE})"

    # マージ実行
    TEMP_MERGED="${dest_file}.merged.tmp"
    if merge_json_files "${dest_file}" "${source_file}" "${TEMP_MERGED}"; then
        mv "${TEMP_MERGED}" "${dest_file}"
        echo -e "  ${GREEN}✓${NC} JSONマージ成功"
    else
        echo -e "  ${RED}✗${NC} JSONマージ失敗（上書きモードにフォールバック）"
        cp "${source_file}" "${dest_file}"
    fi
else
    echo -e "  ${YELLOW}!${NC} settings.json はマージ対象外（上書き）"
    cp "${source_file}" "${dest_file}"
fi

echo ""
echo -e "${BLUE}4. マージ後のsettings.json:${NC}"
cat "${TEST_DIR}/.vscode/settings.json"
echo ""

echo -e "${GREEN}=== 検証結果 ===${NC}"
echo "期待される動作:"
echo "  ✓ editor.fontSize: 14 → 16 (新しい値で上書き)"
echo "  ✓ editor.tabSize: 2 (既存値を保持)"
echo "  ✓ files.autoSave: afterDelay (既存値を保持)"
echo "  ✓ existing.setting: should-be-preserved (既存値を保持)"
echo "  ✓ existing.object.key1: value1 (既存値を保持)"
echo "  ✓ existing.object.key2: value2 → updated-value2 (新しい値で上書き)"
echo "  ✓ existing.object.key3: value3 (新しい値を追加)"
echo "  ✓ editor.formatOnSave: true (新しい値を追加)"
echo "  ✓ files.exclude: {...} (新しい値を追加)"
echo "  ✓ new.setting: should-be-added (新しい値を追加)"
echo ""

# バックアップファイルを確認
echo -e "${BLUE}5. バックアップファイル:${NC}"
cat "${BACKUP_FILE}"
echo ""

echo -e "${GREEN}テスト完了！${NC}"
echo "テストディレクトリ: ${TEST_DIR}"
