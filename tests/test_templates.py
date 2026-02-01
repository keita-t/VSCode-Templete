"""テンプレート機能のテスト"""
import json
import subprocess
from pathlib import Path
import pytest


def run_template_setup(setup_script: Path, test_dir: Path, template_dir: Path,
                       template_types: list[str]) -> tuple[int, str, str]:
    """テンプレートセットアップを実行"""
    cmd = [
        "python3",
        str(setup_script),
        "-l", str(template_dir),
        "-d", "test"
    ] + template_types

    result = subprocess.run(
        cmd,
        cwd=test_dir,
        capture_output=True,
        text=True
    )

    return result.returncode, result.stdout, result.stderr


def test_simple_template(setup_script: Path, test_dir: Path, template_dir: Path):
    """テスト1: simpleテンプレート配置"""
    # テンプレートを適用
    exit_code, stdout, stderr = run_template_setup(
        setup_script, test_dir, template_dir, ["simple"]
    )

    # 実行成功を確認
    assert exit_code == 0, f"実行失敗:\nSTDOUT:\n{stdout}\nSTDERR:\n{stderr}"

    # ファイルが作成されたことを確認
    assert (test_dir / ".vscode" / "settings.json").exists()
    assert (test_dir / ".gitignore").exists()
    assert (test_dir / ".editorconfig").exists()

    # settings.jsonの内容を確認
    with open(test_dir / ".vscode" / "settings.json") as f:
        settings = json.load(f)
    assert settings.get("editor.fontSize") == 14


def test_advanced_template(setup_script: Path, test_dir: Path, template_dir: Path):
    """テスト2: advancedテンプレート配置"""
    exit_code, stdout, stderr = run_template_setup(
        setup_script, test_dir, template_dir, ["advanced"]
    )

    assert exit_code == 0, f"実行失敗: {stderr}"
    assert (test_dir / ".vscode" / "settings.json").exists()

    with open(test_dir / ".vscode" / "settings.json") as f:
        settings = json.load(f)
    assert settings.get("editor.fontSize") == 16


def test_multiple_templates(setup_script: Path, test_dir: Path, template_dir: Path):
    """テスト3: 複数テンプレート（simple → advanced）"""
    exit_code, stdout, stderr = run_template_setup(
        setup_script, test_dir, template_dir, ["simple", "advanced"]
    )

    assert exit_code == 0, f"実行失敗: {stderr}"
    assert (test_dir / ".vscode" / "settings.json").exists()

    # 後から適用したadvancedの値（16）が優先されるべき
    with open(test_dir / ".vscode" / "settings.json") as f:
        settings = json.load(f)
    assert settings.get("editor.fontSize") == 16


def test_clean_project(setup_script: Path, test_dir: Path, template_dir: Path):
    """テスト4: クリーンプロジェクトへの適用"""
    exit_code, stdout, stderr = run_template_setup(
        setup_script, test_dir, template_dir, ["simple"]
    )

    assert exit_code == 0, f"実行失敗: {stderr}"
    assert (test_dir / ".vscode" / "settings.json").exists()
    assert (test_dir / ".gitignore").exists()


def test_directory_structure(setup_script: Path, test_dir: Path, template_dir: Path):
    """テスト5: ディレクトリ構造の確認"""
    exit_code, stdout, stderr = run_template_setup(
        setup_script, test_dir, template_dir, ["simple"]
    )

    assert exit_code == 0, f"実行失敗: {stderr}"

    # .vscodeディレクトリが正しく作成されているか
    assert (test_dir / ".vscode").is_dir()
    assert (test_dir / ".vscode" / "settings.json").exists()


def test_json_merge(setup_script: Path, test_dir: Path, template_dir: Path):
    """テスト6: JSONマージ機能"""
    # 既存のsettings.jsonを作成
    vscode_dir = test_dir / ".vscode"
    vscode_dir.mkdir(parents=True)

    existing_settings = {
        "editor.fontSize": 20,
        "existingSetting": "should-be-preserved",
        "editor.tabSize": 4
    }

    with open(vscode_dir / "settings.json", "w") as f:
        json.dump(existing_settings, f, indent=2)

    # テンプレートを適用（マージが発生するはず）
    exit_code, stdout, stderr = run_template_setup(
        setup_script, test_dir, template_dir, ["simple"]
    )

    # 2回目の適用でマージテンプレートを使用
    exit_code, stdout, stderr = run_template_setup(
        setup_script, test_dir, template_dir, ["merge-json"]
    )

    assert exit_code == 0, f"実行失敗: {stderr}"

    # マージ後の内容を確認
    with open(vscode_dir / "settings.json") as f:
        merged_settings = json.load(f)

    # 既存設定が保持され、新しい設定も追加されているか確認
    assert merged_settings.get("existingSetting") == "should-be-preserved"
    assert merged_settings.get("newSetting") == "from-template"


def test_yaml_merge(setup_script: Path, test_dir: Path, template_dir: Path):
    """テスト7: YAMLマージ機能"""
    try:
        import yaml
    except ImportError:
        pytest.skip("pyyaml not installed")

    # 既存のdocker-compose.ymlを作成
    existing_yaml = """version: '3.8'
services:
  existing-service:
    image: nginx:latest
    ports:
      - "8080:80"
"""

    with open(test_dir / "docker-compose.yml", "w") as f:
        f.write(existing_yaml)

    # テンプレートを適用（マージが発生するはず）
    exit_code, stdout, stderr = run_template_setup(
        setup_script, test_dir, template_dir, ["merge-yaml"]
    )

    assert exit_code == 0, f"実行失敗: {stderr}"

    # マージ後の内容を確認
    with open(test_dir / "docker-compose.yml") as f:
        content = f.read()

    # 既存サービスと新規サービスの両方が存在するか確認
    assert "existing-service" in content
    assert "web" in content


def test_toml_merge(setup_script: Path, test_dir: Path, template_dir: Path):
    """テスト8: TOMLマージ機能"""
    try:
        import tomli_w
    except ImportError:
        pytest.skip("tomli-w not installed")

    # 既存のpyproject.tomlを作成
    existing_toml = """[project]
name = "existing-project"
version = "1.0.0"

[project.dependencies]
python = "^3.8"
"""

    with open(test_dir / "pyproject.toml", "w") as f:
        f.write(existing_toml)

    # テンプレートを適用（マージが発生するはず）
    exit_code, stdout, stderr = run_template_setup(
        setup_script, test_dir, template_dir, ["merge-toml"]
    )

    assert exit_code == 0, f"実行失敗: {stderr}"

    # マージ後の内容を確認
    with open(test_dir / "pyproject.toml") as f:
        content = f.read()

    # 既存設定と新規設定の両方が存在するか確認
    assert "existing-project" in content
    assert "requests" in content


def test_script_exists(setup_script: Path):
    """前提条件: スクリプトが存在する"""
    assert setup_script.exists(), f"スクリプトが見つかりません: {setup_script}"


def test_template_dir_exists(template_dir: Path):
    """前提条件: テンプレートディレクトリが存在する"""
    assert (template_dir / "test").exists(), f"テンプレートディレクトリが見つかりません: {template_dir}/test"
