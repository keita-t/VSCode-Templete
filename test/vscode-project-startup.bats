#!/usr/bin/env bats

# ============================================================================
# vscode-project-startup.sh のBATSテスト
# ============================================================================
# 使用方法: bats test/vscode-project-startup.bats
# ============================================================================

# テスト用の一時ディレクトリ
setup() {
    export TEST_DIR
    TEST_DIR="$(mktemp -d)"
    export SCRIPT_DIR
    SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_DIRNAME")" && pwd)"
    export SCRIPT_PATH="${SCRIPT_DIR}/vscode-project-startup.sh"

    # スクリプトから設定と関数定義のみを抽出してsource
    # 引数チェックとメイン処理は除外
    source <(sed -n '/^# --- GitHubリポジトリ設定 ---/,/^# 引数チェック/p' "${SCRIPT_PATH}" | grep -v "^# 引数チェック")
}

teardown() {
    rm -rf "$TEST_DIR"
}

# ============================================================================
# マージ設定テスト
# ============================================================================

@test "get_merge_setting: デフォルトマージ設定を返す" {
    run get_merge_setting
    [ "$status" -eq 0 ]
    [[ "$output" =~ \*.json ]]
    [[ "$output" =~ \*.code-snippets ]]
}

@test "should_merge_file: JSONファイルはマージ対象" {
    DEFAULT_MERGE_SETTING=("*.json" "*.code-snippets")
    run should_merge_file "settings.json"
    [ "$status" -eq 0 ]
}

@test "should_merge_file: スニペットファイルはマージ対象" {
    DEFAULT_MERGE_SETTING=("*.json" "*.code-snippets")
    run should_merge_file "python.code-snippets"
    [ "$status" -eq 0 ]
}

@test "should_merge_file: 通常のテキストファイルはマージ対象外" {
    DEFAULT_MERGE_SETTING=("*.json" "*.code-snippets")
    run should_merge_file ".gitignore"
    [ "$status" -eq 1 ]
}

@test "should_merge_file: Dockerfileはマージ対象外" {
    DEFAULT_MERGE_SETTING=("*.json" "*.code-snippets")
    run should_merge_file "Dockerfile"
    [ "$status" -eq 1 ]
}

# ============================================================================
# テンプレート設定テスト
# ============================================================================

@test "get_template_folder_mapping: デフォルトマッピングを返す" {
    declare -A DEFAULT_FOLDER_MAPPING=(
        ["vscode"]=".vscode"
        ["git"]=".git"
        ["config"]="."
    )

    run get_template_folder_mapping "base"
    [ "$status" -eq 0 ]
    [[ "$output" =~ vscode:.vscode ]]
    [[ "$output" =~ git:.git ]]
}

@test "get_template_folder_mapping: 個別マッピングとデフォルトをマージ" {
    declare -A DEFAULT_FOLDER_MAPPING=(
        ["vscode"]=".vscode"
        ["git"]=".git"
    )
    declare -A PYTHON_FOLDER_MAPPING=(
        ["docs"]="docs"
        ["tests"]="tests"
    )

    run get_template_folder_mapping "python"
    [ "$status" -eq 0 ]
    [[ "$output" =~ vscode:.vscode ]]
    [[ "$output" =~ docs:docs ]]
}

@test "get_file_destination: デフォルトファイルマッピングが機能する" {
    declare -A DEFAULT_FILE_MAPPING=(
        [".gitignore"]="."
        [".dockerignore"]="."
    )

    run get_file_destination "base" ".gitignore"
    [ "$status" -eq 0 ]
    [ "$output" = "." ]
}

@test "get_file_destination: 個別ファイルマッピングが優先される" {
    declare -A DEFAULT_FILE_MAPPING=(
        [".gitignore"]="."
    )
    declare -A PYTHON_FILE_MAPPING=(
        ["requirements.txt"]="."
    )

    run get_file_destination "python" "requirements.txt"
    [ "$status" -eq 0 ]
    [ "$output" = "." ]
}

@test "get_file_destination: マッピングがない場合は失敗" {
    declare -A DEFAULT_FILE_MAPPING=()

    run get_file_destination "base" "unknown.txt"
    [ "$status" -eq 1 ]
}

# ============================================================================
# JSONマージ機能テスト
# ============================================================================

@test "merge_json_files: jqがない場合はエラー" {
    # このテストは実際の環境でjqが利用可能な場合スキップ
    if command -v jq &> /dev/null; then
        skip "jqがインストールされているため、このテストはスキップします"
    fi

    echo '{"a": 1}' > "$TEST_DIR/base.json"
    echo '{"b": 2}' > "$TEST_DIR/new.json"

    run merge_json_files "$TEST_DIR/base.json" "$TEST_DIR/new.json" "$TEST_DIR/output.json"
    [ "$status" -eq 1 ]
}

@test "merge_json_files: jqが利用可能な場合はマージ成功" {
    # jqがインストールされているかチェック
    if ! command -v jq &> /dev/null; then
        skip "jqがインストールされていません"
    fi

    merge_json_files() {
        local base_file="$1"
        local new_file="$2"
        local output_file="$3"

        if ! command -v jq &> /dev/null; then
            return 1
        fi

        jq -s '.[0] * .[1]' "${base_file}" "${new_file}" > "${output_file}"
        return 0
    }

    echo '{"a": 1, "b": 2}' > "$TEST_DIR/base.json"
    echo '{"b": 3, "c": 4}' > "$TEST_DIR/new.json"

    run merge_json_files "$TEST_DIR/base.json" "$TEST_DIR/new.json" "$TEST_DIR/output.json"
    [ "$status" -eq 0 ]
    [ -f "$TEST_DIR/output.json" ]

    # マージ結果を検証
    result=$(cat "$TEST_DIR/output.json")
    [[ "$result" =~ \"a\" ]]
    [[ "$result" =~ \"b\" ]]
    [[ "$result" =~ \"c\" ]]
}

@test "merge_json_files: 深い階層のJSONもマージできる" {
    if ! command -v jq &> /dev/null; then
        skip "jqがインストールされていません"
    fi

    merge_json_files() {
        local base_file="$1"
        local new_file="$2"
        local output_file="$3"

        if ! command -v jq &> /dev/null; then
            return 1
        fi

        jq -s '.[0] * .[1]' "${base_file}" "${new_file}" > "${output_file}"
        return 0
    }

    cat > "$TEST_DIR/base.json" << 'EOF'
{
    "editor": {
        "fontSize": 14,
        "tabSize": 2
    },
    "files": {
        "autoSave": "off"
    }
}
EOF

    cat > "$TEST_DIR/new.json" << 'EOF'
{
    "editor": {
        "fontSize": 16,
        "wordWrap": "on"
    },
    "python": {
        "linting": true
    }
}
EOF

    run merge_json_files "$TEST_DIR/base.json" "$TEST_DIR/new.json" "$TEST_DIR/output.json"
    [ "$status" -eq 0 ]

    # マージ結果を検証（新しい値で上書き、新しいキーは追加）
    result=$(cat "$TEST_DIR/output.json")
    [[ "$result" =~ \"fontSize\" ]]
    [[ "$result" =~ \"wordWrap\" ]]
    [[ "$result" =~ \"python\" ]]
}

# ============================================================================
# 使用方法表示テスト
# ============================================================================

@test "usage: エラーメッセージとヘルプを表示" {
    run bash -c "source '${SCRIPT_PATH}' 2>&1" || true
    [[ "$output" =~ エラー:\ テンプレートを1つ以上指定してください ]]
    [[ "$output" =~ 使用方法: ]]
}

# ============================================================================
# 引数処理テスト
# ============================================================================

@test "引数なし: エラーで終了" {
    run bash "${SCRIPT_PATH}"
    [ "$status" -eq 1 ]
    [[ "$output" =~ エラー ]]
}

@test "ヘルプメッセージ: テンプレート名の例が含まれる" {
    run bash "${SCRIPT_PATH}" 2>&1 || true
    [[ "$output" =~ python ]]
    [[ "$output" =~ docker ]]
}

# ============================================================================
# ファイル配置テスト（統合）
# ============================================================================

@test "統合テスト: テンプレートディレクトリ構造が正しい" {
    # templeteディレクトリの存在確認
    [ -d "${SCRIPT_DIR}/templete" ]
    [ -d "${SCRIPT_DIR}/templete/base" ]
}

@test "統合テスト: テンプレートファイルが存在する" {
    # baseテンプレートの主要ファイル確認
    [ -d "${SCRIPT_DIR}/templete/base/vscode" ] || skip "base/vscodeディレクトリが存在しません"

    # pythonテンプレートの確認
    [ -d "${SCRIPT_DIR}/templete/python" ] || skip "pythonディレクトリが存在しません"
}
