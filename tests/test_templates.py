"""VSCode Project Template Setup - 包括的テストスイート

テスト構成:
1. 基本機能テスト: 単一テンプレート適用、ファイル配置確認
2. 階層的テンプレートテスト: スラッシュ区切りテンプレート
3. マージ機能テスト: JSON/YAML/TOML/Code-snippetsのマージ
4. 複数テンプレートテスト: テンプレートの組み合わせと優先順位
5. エラーハンドリングテスト: 不正な入力への対応
"""
import json
import subprocess
import sys
from pathlib import Path
import pytest


def run_setup(setup_script: Path, test_dir: Path, local_path: Path,
              template_types: list[str], expect_success: bool = True) -> tuple[int, str, str]:
    """テンプレートセットアップを実行

    Args:
        setup_script: セットアップスクリプトのパス
        test_dir: テスト対象ディレクトリ
        local_path: ローカルテンプレートのルートパス
        template_types: 適用するテンプレート名のリスト
        expect_success: 成功を期待する場合True

    Returns:
        (exit_code, stdout, stderr)
    """
    cmd = [sys.executable, str(setup_script), "-l", str(local_path)] + template_types

    result = subprocess.run(cmd, cwd=test_dir, capture_output=True, text=True)

    if expect_success and result.returncode != 0:
        pytest.fail(f"実行失敗 (exit={result.returncode}):\nSTDOUT:\n{result.stdout}\nSTDERR:\n{result.stderr}")

    return result.returncode, result.stdout, result.stderr


# ============================================================================
# 1. 基本機能テスト
# ============================================================================

class TestBasicFunctionality:
    """基本的なテンプレート適用機能のテスト"""

    def test_default_base_template(self, setup_script: Path, test_dir: Path, template_dir: Path):
        """default/base: VSCode基本設定の適用"""
        run_setup(setup_script, test_dir, template_dir.parent, ["default/base"])

        # ファイル存在確認
        assert (test_dir / ".vscode" / "settings.json").exists()
        assert (test_dir / ".gitignore").exists()

        # 内容確認
        settings = (test_dir / ".vscode" / "settings.json").read_text()
        assert "editor.fontSize" in settings

    def test_default_lightweight_template(self, setup_script: Path, test_dir: Path, template_dir: Path):
        """default/lightweight: 軽量設定の適用"""
        run_setup(setup_script, test_dir, template_dir.parent, ["default/lightweight"])

        assert (test_dir / ".vscode" / "settings.json").exists()
        settings = (test_dir / ".vscode" / "settings.json").read_text()
        assert len(settings) > 0

    def test_python_base_template(self, setup_script: Path, test_dir: Path, template_dir: Path):
        """python/base: Python開発環境の適用"""
        run_setup(setup_script, test_dir, template_dir.parent, ["python/base"])

        assert (test_dir / ".vscode" / "settings.json").exists()
        assert (test_dir / ".vscode" / "python.code-snippets").exists()

    def test_python_pylance_lw_template(self, setup_script: Path, test_dir: Path, template_dir: Path):
        """python/pylance-lw: Pylance軽量設定の適用"""
        run_setup(setup_script, test_dir, template_dir.parent, ["python/pylance-lw"])

        assert (test_dir / ".vscode" / "settings.json").exists()
        settings = (test_dir / ".vscode" / "settings.json").read_text()
        assert "python.analysis" in settings

    def test_docker_base_template(self, setup_script: Path, test_dir: Path, template_dir: Path):
        """docker/base: Docker環境の適用"""
        run_setup(setup_script, test_dir, template_dir.parent, ["docker/base"])

        assert (test_dir / ".vscode" / "settings.json").exists()
        assert (test_dir / "Dockerfile").exists()
        assert (test_dir / "docker-compose.yml").exists()
        assert (test_dir / ".dockerignore").exists()


# ============================================================================
# 2. 階層的テンプレートテスト
# ============================================================================

class TestHierarchicalTemplates:
    """スラッシュ区切りテンプレートのテスト"""

    def test_slash_separated_template_name(self, setup_script: Path, test_dir: Path, template_dir: Path):
        """スラッシュ区切りテンプレート名が正しく解釈される"""
        run_setup(setup_script, test_dir, template_dir.parent, ["default/base"])

        assert (test_dir / ".vscode" / "settings.json").exists()

    def test_category_folder_structure(self, setup_script: Path, test_dir: Path, template_dir: Path):
        """カテゴリフォルダ構造が正しく処理される"""
        # templates/default/base/vscode/settings.json が正しく読み込まれる
        run_setup(setup_script, test_dir, template_dir.parent, ["default/base"])

        settings_path = test_dir / ".vscode" / "settings.json"
        assert settings_path.exists()
        assert settings_path.stat().st_size > 0


# ============================================================================
# 3. マージ機能テスト
# ============================================================================

class TestMergeFunctionality:
    """構造化ファイルのマージ機能のテスト"""

    def test_json_merge_preserves_existing(self, setup_script: Path, test_dir: Path, template_dir: Path):
        """JSONファイルのマージで既存設定が保持される"""
        # 既存のsettings.jsonを作成
        vscode_dir = test_dir / ".vscode"
        vscode_dir.mkdir(parents=True)
        existing_settings = {
            "editor.tabSize": 2,  # テンプレートで上書きされる
            "editor.fontSize": 14,  # テンプレートにない設定（保持される）
            "files.autoSave": "afterDelay"  # テンプレートにない設定（保持される）
        }
        with open(vscode_dir / "settings.json", "w") as f:
            json.dump(existing_settings, f, indent=2)

        # マージテンプレートを適用
        run_setup(setup_script, test_dir, template_dir.parent, ["test/merge-json"])

        # マージ結果を確認
        with open(vscode_dir / "settings.json") as f:
            merged = json.load(f)

        # テンプレートからの新設定が追加される
        assert merged["newSetting"] == "from-template"
        assert merged["python.linting.enabled"] is True
        assert merged["python.formatting.provider"] == "black"

        # 上書きされる設定
        assert merged["editor.tabSize"] == 4

        # 既存の設定が保持される
        assert merged["editor.fontSize"] == 14
        assert merged["files.autoSave"] == "afterDelay"

    def test_yaml_merge_preserves_existing(self, setup_script: Path, test_dir: Path, template_dir: Path):
        """YAMLファイルのマージで既存設定が保持される"""
        # 既存のdocker-compose.ymlを作成
        existing_compose = """version: '3.8'

services:
  web:
    image: nginx:latest
    ports:
      - "80:80"
  db:
    image: postgres:14
    environment:
      - POSTGRES_DB=mydb
"""
        with open(test_dir / "docker-compose.yml", "w") as f:
            f.write(existing_compose)

        # マージテンプレートを適用
        run_setup(setup_script, test_dir, template_dir.parent, ["test/merge-yaml"])

        # マージ結果を確認
        with open(test_dir / "docker-compose.yml") as f:
            import yaml
            merged = yaml.safe_load(f)

        # テンプレートからwebサービスが更新される
        assert merged["services"]["web"]["image"] == "nginx:alpine"
        assert "8080:80" in merged["services"]["web"]["ports"]
        assert merged["services"]["web"]["environment"][0] == "NODE_ENV=development"

        # 既存のdbサービスが保持される
        assert "db" in merged["services"]
        assert merged["services"]["db"]["image"] == "postgres:14"
        assert merged["services"]["db"]["environment"][0] == "POSTGRES_DB=mydb"

    def test_toml_merge_preserves_existing(self, setup_script: Path, test_dir: Path, template_dir: Path):
        """TOMLファイルのマージで既存設定が保持される"""
        # 既存のpyproject.tomlを作成
        existing_toml = """[tool.poetry]
name = "existing-project"
version = "1.0.0"
description = "My existing project"

[tool.poetry.dependencies]
python = "^3.11"
numpy = "^1.24.0"

[tool.black]
line-length = 100
"""
        with open(test_dir / "pyproject.toml", "w") as f:
            f.write(existing_toml)

        # マージテンプレートを適用
        run_setup(setup_script, test_dir, template_dir.parent, ["test/merge-toml"])

        # マージ結果を確認
        with open(test_dir / "pyproject.toml", "rb") as f:
            import tomli
            merged = tomli.load(f)

        # テンプレートから設定が更新される
        assert merged["tool"]["poetry"]["name"] == "test-project"
        assert merged["tool"]["poetry"]["version"] == "0.1.0"

        # テンプレートから新しい依存関係が追加される
        assert "requests" in merged["tool"]["poetry"]["dependencies"]
        assert merged["tool"]["poetry"]["dependencies"]["requests"] == "^2.28.0"

        # テンプレートのpython依存関係が既存を上書き
        assert merged["tool"]["poetry"]["dependencies"]["python"] == "^3.9"

        # 既存の設定が保持される
        assert merged["tool"]["poetry"]["description"] == "My existing project"
        assert merged["tool"]["poetry"]["dependencies"]["numpy"] == "^1.24.0"
        assert merged["tool"]["black"]["line-length"] == 100
        assert merged["build-system"]["requires"] == ["poetry-core"]

    def test_line_text_merge_removes_duplicates(self, setup_script: Path, test_dir: Path, template_dir: Path):
        """行単位テキストファイルのマージで重複が排除される"""
        # 既存の.gitignoreを作成
        existing_gitignore = """# Python
__pycache__/
*.py[cod]
.venv/

# IDE
.vscode/
.idea/

# OS
.DS_Store
"""
        with open(test_dir / ".gitignore", "w") as f:
            f.write(existing_gitignore)

        # マージテンプレートを適用（templates/test/merge-line-text/config/.gitignoreを使用）
        run_setup(setup_script, test_dir, template_dir.parent, ["test/merge-line-text"])

        # マージ結果を確認
        with open(test_dir / ".gitignore") as f:
            merged_lines = f.readlines()

        merged_text = ''.join(merged_lines)

        # 既存の行が保持される
        assert "__pycache__/" in merged_text
        assert ".venv/" in merged_text
        assert ".vscode/" in merged_text
        assert ".DS_Store" in merged_text

        # テンプレートから新しい行が追加される
        assert "*.egg-info/" in merged_text
        assert "dist/" in merged_text
        assert ".pytest_cache/" in merged_text
        assert ".coverage" in merged_text

        # 重複行は1回だけ（*.py[cod]は既存にあるので追加されない）
        assert merged_text.count("*.py[cod]") == 1
        assert merged_text.count("# Python") == 1


# ============================================================================
# 4. 複数テンプレート適用テスト
# ============================================================================

class TestMultipleTemplates:
    """複数テンプレートの組み合わせテスト"""

    def test_multiple_templates_applied_sequentially(self, setup_script: Path, test_dir: Path, template_dir: Path):
        """複数テンプレートが順番に適用される"""
        run_setup(setup_script, test_dir, template_dir.parent, ["default/base", "python/base"])

        # 両方のテンプレートのファイルが存在
        assert (test_dir / ".gitignore").exists()  # default/base
        assert (test_dir / ".vscode" / "python.code-snippets").exists()  # python/base

    def test_three_way_combination(self, setup_script: Path, test_dir: Path, template_dir: Path):
        """3つのテンプレート組み合わせ"""
        # default/baseが最後に適用されるため、Pylance設定は上書きされる
        run_setup(setup_script, test_dir, template_dir.parent,
                 ["python/base", "python/pylance-lw", "default/base"])

        assert (test_dir / ".gitignore").exists()
        assert (test_dir / ".vscode" / "python.code-snippets").exists()

    def test_docker_and_default_combination(self, setup_script: Path, test_dir: Path, template_dir: Path):
        """Docker + デフォルト設定の組み合わせ"""
        run_setup(setup_script, test_dir, template_dir.parent, ["default/base", "docker/base"])

        assert (test_dir / ".gitignore").exists()  # default
        assert (test_dir / "Dockerfile").exists()  # docker
        assert (test_dir / "docker-compose.yml").exists()  # docker


# ============================================================================
# 5. エラーハンドリングテスト
# ============================================================================

class TestErrorHandling:
    """エラーハンドリングのテスト"""

    def test_nonexistent_template(self, setup_script: Path, test_dir: Path, template_dir: Path):
        """存在しないテンプレートを指定した場合"""
        exit_code, stdout, stderr = run_setup(
            setup_script, test_dir, template_dir.parent,
            ["nonexistent/template"], expect_success=False
        )

        assert exit_code != 0

    def test_empty_template_list(self, setup_script: Path, test_dir: Path, template_dir: Path):
        """テンプレートを指定しない場合"""
        cmd = [sys.executable, str(setup_script), "-l", str(template_dir.parent)]
        result = subprocess.run(cmd, cwd=test_dir, capture_output=True, text=True)

        assert result.returncode != 0


# ============================================================================
# 7. GitHub接続テスト
# ============================================================================

class TestGitHubIntegration:
    """
    GitHub接続テスト

    - モックテスト: デフォルトで実行（外部依存なし）
    - 実接続テスト: `pytest -m github` で実行（ネットワーク必要）
    """

    def test_github_download_with_mock(self, setup_script: Path, template_dir: Path):
        """モックを使用したGitHub関連クラスのテスト"""
        import importlib.util
        from pathlib import Path

        # スクリプトをモジュールとしてロード
        spec = importlib.util.spec_from_file_location("vscode_startup", setup_script)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)

        # Configクラスをテスト
        config = module.Config()
        assert config.github_user
        assert config.repo_name
        assert config.branch

        # TemplateSourceクラスをテスト（ローカルモード）
        source = module.TemplateSource(config=config, local_path=template_dir.parent)
        assert source.is_local is True

        # ファイル取得をテスト
        content = source.get_file_content("templates/default/base/vscode/settings.json")
        assert content is not None
        assert len(content) > 0

    def test_github_url_format(self, mocker):
        """
GitHub URLフォーマットのテスト"""
        from pathlib import Path
        import sys
        sys.path.insert(0, str(Path(__file__).parent.parent))

        # Configをインポート（スクリプトから）
        import importlib.util
        spec = importlib.util.spec_from_file_location(
            "vscode_startup",
            Path(__file__).parent.parent / "vscode-project-startup.py"
        )
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)

        config = module.Config()

        # GitHub URLのフォーマット確認
        expected_base = f"https://raw.githubusercontent.com/{config.github_user}/{config.repo_name}/{config.branch}"
        assert config.github_user
        assert config.repo_name
        assert config.branch

        # テンプレートパスの構築確認
        template_path = "templates/default/base/vscode/settings.json"
        expected_url = f"{expected_base}/{template_path}"
        assert "https://" in expected_url
        assert ".com/" in expected_url

    @pytest.mark.github
    def test_github_actual_connection(self, setup_script: Path, test_dir: Path):
        """
        実GitHub接続テスト（オプショナル）

        実行方法: pytest -m github
        """
        # GitHubモードで実際にダウンロード
        result = subprocess.run(
            [sys.executable, str(setup_script), 'default/base'],
            cwd=test_dir,
            capture_output=True,
            text=True,
            timeout=30  # 30秒タイムアウト
        )

        # 成功するか、ネットワークエラーのいずれか
        # (ファイルが見つからない場合は404エラー)
        if result.returncode == 0:
            # 成功: ファイルが作成されているか確認
            assert (test_dir / ".vscode" / "settings.json").exists() or \
                   (test_dir / ".gitignore").exists(), \
                   "ダウンロードされたファイルが存在するべき"
        else:
            # 失敗: URLエラーまたはHTTPエラーが含まれているか確認
            assert "HTTP" in result.stderr or "URL" in result.stderr or "エラー" in result.stderr, \
                   f"予期されるエラーメッセージがない: {result.stderr}"

class TestPrerequisites:
    """実行環境の前提条件テスト"""

    def test_setup_script_exists(self, setup_script: Path):
        """セットアップスクリプトが存在する"""
        assert setup_script.exists()
        assert setup_script.is_file()

    def test_template_directory_exists(self, template_dir: Path):
        """テンプレートディレクトリが存在する"""
        assert template_dir.exists()
        assert template_dir.is_dir()

    def test_default_templates_exist(self, template_dir: Path):
        """デフォルトテンプレートが存在する"""
        assert (template_dir / "default" / "base").exists()
        assert (template_dir / "default" / "lightweight").exists()

    def test_python_templates_exist(self, template_dir: Path):
        """Pythonテンプレートが存在する"""
        assert (template_dir / "python" / "base").exists()
        assert (template_dir / "python" / "pylance-lw").exists()

    def test_docker_templates_exist(self, template_dir: Path):
        """Dockerテンプレートが存在する"""
        assert (template_dir / "docker" / "base").exists()

class TestCommentStripping:
    """コメント除去機能のテスト"""

    def test_json_with_single_line_comments(self, setup_script: Path, test_dir: Path, template_dir: Path):
        """JSONファイルの単一行コメントを除去してマージ"""
        # コメント付きJSONファイルを作成
        vscode_dir = test_dir / ".vscode"
        vscode_dir.mkdir(parents=True)
        existing_settings = """{
    // エディタ設定
    "editor.tabSize": 2,
    "editor.fontSize": 14,  // フォントサイズ
    "files.autoSave": "afterDelay"  // 自動保存
}"""
        with open(vscode_dir / "settings.json", "w") as f:
            f.write(existing_settings)

        # マージテンプレートを適用
        run_setup(setup_script, test_dir, template_dir.parent, ["test/merge-json"])

        # マージ結果を確認
        with open(vscode_dir / "settings.json") as f:
            merged = json.load(f)

        # 既存の設定が保持されている
        assert merged["editor.fontSize"] == 14
        assert merged["files.autoSave"] == "afterDelay"
        # テンプレートからの新設定が追加される
        assert merged["newSetting"] == "from-template"

    def test_json_with_multi_line_comments(self, setup_script: Path, test_dir: Path, template_dir: Path):
        """JSONファイルの複数行コメントを除去してマージ"""
        # コメント付きJSONファイルを作成
        vscode_dir = test_dir / ".vscode"
        vscode_dir.mkdir(parents=True)
        existing_settings = """{
    /* これは複数行コメント
       エディタ設定について
       説明します */
    "editor.tabSize": 2,
    "editor.fontSize": 14,
    /* このコメントも除去される */
    "files.autoSave": "afterDelay"
}"""
        with open(vscode_dir / "settings.json", "w") as f:
            f.write(existing_settings)

        # マージテンプレートを適用
        run_setup(setup_script, test_dir, template_dir.parent, ["test/merge-json"])

        # マージ結果を確認
        with open(vscode_dir / "settings.json") as f:
            merged = json.load(f)

        # 既存の設定が保持されている
        assert merged["editor.fontSize"] == 14
        assert merged["files.autoSave"] == "afterDelay"
        # テンプレートからの新設定が追加される
        assert merged["newSetting"] == "from-template"

    def test_yaml_with_comments(self, setup_script: Path, test_dir: Path, template_dir: Path):
        """YAMLファイルのコメントを適切に処理してマージ"""
        # コメント付きYAMLファイルを作成
        existing_compose = """# Docker Compose設定
version: '3.8'

services:
  web:
    image: nginx:latest  # Nginxイメージ
    ports:
      - "80:80"  # ポート設定
  # データベース設定
  db:
    image: postgres:14
    environment:
      - POSTGRES_DB=mydb  # データベース名
"""
        with open(test_dir / "docker-compose.yml", "w") as f:
            f.write(existing_compose)

        # マージテンプレートを適用
        run_setup(setup_script, test_dir, template_dir.parent, ["test/merge-yaml"])

        # マージ結果を確認（エラーなく読み込めることを確認）
        with open(test_dir / "docker-compose.yml") as f:
            import yaml
            merged = yaml.safe_load(f)

        # 既存のdbサービスが保持される
        assert "db" in merged["services"]
        assert merged["services"]["db"]["image"] == "postgres:14"

    def test_toml_with_comments(self, setup_script: Path, test_dir: Path, template_dir: Path):
        """TOMLファイルのコメントを適切に処理してマージ"""
        # コメント付きTOMLファイルを作成
        existing_toml = """# プロジェクト設定
[tool.poetry]
name = "existing-project"  # プロジェクト名
version = "1.0.0"
description = "My existing project"

# 依存関係
[tool.poetry.dependencies]
python = "^3.11"  # Python バージョン
numpy = "^1.24.0"  # 数値計算ライブラリ

# コードフォーマッター設定
[tool.black]
line-length = 100  # 行の長さ
"""
        with open(test_dir / "pyproject.toml", "w") as f:
            f.write(existing_toml)

        # マージテンプレートを適用
        run_setup(setup_script, test_dir, template_dir.parent, ["test/merge-toml"])

        # マージ結果を確認（エラーなく読み込めることを確認）
        with open(test_dir / "pyproject.toml", "rb") as f:
            import tomli
            merged = tomli.load(f)

        # 既存の設定が保持される
        assert merged["tool"]["poetry"]["description"] == "My existing project"
        assert merged["tool"]["poetry"]["dependencies"]["numpy"] == "^1.24.0"
        assert merged["tool"]["black"]["line-length"] == 100
