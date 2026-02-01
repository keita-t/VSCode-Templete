#!/bin/bash

# ============================================================================
# ローカル環境での手動統合テスト
# ============================================================================
# GitHub APIを使わずにローカルのtempleteフォルダから直接テストします
#
# 【目的】
# - テンプレートファイルの実際の配置確認
# - ファイルコピー動作の検証
# - エンドツーエンドでの動作確認
#
# 【実行方法】
# ./test/manual/test-local.sh
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

# テストディレクトリを作成
TEST_DIR="/tmp/vscode-test-project-$(date +%s)"
mkdir -p "${TEST_DIR}"

echo -e "${GREEN}テストプロジェクトを作成: ${TEST_DIR}${NC}"

# 既存のsettings.jsonを作成（マージテスト用）
mkdir -p "${TEST_DIR}/.vscode"
cat > "${TEST_DIR}/.vscode/settings.json" << 'EOF'
{
  "editor.fontSize": 14,
  "editor.tabSize": 2,
  "files.autoSave": "afterDelay",
  "existing.setting": "should-be-preserved"
}
EOF

echo -e "${YELLOW}既存settings.jsonを作成（マージテスト用）${NC}"
cat "${TEST_DIR}/.vscode/settings.json"
echo ""

# テンプレートを適用
cd "${TEST_DIR}"

echo -e "${BLUE}=== baseテンプレートをコピー ===${NC}"
cp -r "$(dirname "$0")/templete/base/git/.gitignore" ./
cp -r "$(dirname "$0")/templete/base/vscode/"* .vscode/

echo -e "${GREEN}✓ baseテンプレート適用完了${NC}"
echo ""

echo -e "${BLUE}=== マージ後のsettings.json ===${NC}"
cat "${TEST_DIR}/.vscode/settings.json"
echo ""

echo -e "${BLUE}=== .gitignore ===${NC}"
head -20 "${TEST_DIR}/.gitignore"
echo ""

echo -e "${GREEN}テスト完了！${NC}"
echo "テストディレクトリ: ${TEST_DIR}"
echo ""
echo "確認コマンド:"
echo "  cd ${TEST_DIR}"
echo "  ls -la"
echo "  cat .vscode/settings.json"
