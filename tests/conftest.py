"""pytest設定とフィクスチャ"""
import json
import os
import shutil
import tempfile
from pathlib import Path
from typing import Generator
import pytest


@pytest.fixture(scope="session")
def project_root() -> Path:
    """プロジェクトのルートディレクトリ"""
    return Path(__file__).parent.parent


@pytest.fixture(scope="session")
def setup_script(project_root: Path) -> Path:
    """セットアップスクリプトのパス"""
    return project_root / "vscode-project-startup.py"


@pytest.fixture(scope="session")
def template_dir(project_root: Path) -> Path:
    """テンプレートディレクトリのパス"""
    return project_root / "templates"


@pytest.fixture(scope="session")
def test_config(tmp_path_factory, project_root: Path) -> Path:
    """テスト用のconfig.jsonを作成"""
    # 元のconfig.jsonを読み込み
    with open(project_root / "config.json") as f:
        config = json.load(f)

    # テスト用のマージテンプレート設定を追加
    config["templates"]["test/merge-yaml"] = {
        "file_match_patterns": ["docker-compose.yml"]
    }
    config["templates"]["test/merge-toml"] = {
        "file_match_patterns": ["pyproject.toml"]
    }
    config["templates"]["test/merge-json"] = {
        "file_match_patterns": ["settings.json"]
    }
    config["templates"]["test/merge-line-text"] = {
        "file_match_patterns": [".gitignore"]
    }

    # 一時ディレクトリに保存
    config_dir = tmp_path_factory.mktemp("config")
    config_file = config_dir / "config.json"
    with open(config_file, "w") as f:
        json.dump(config, f, indent=2)

    return config_file


@pytest.fixture(autouse=True)
def use_test_config(test_config: Path):
    """全テストでテスト用config.jsonを使用"""
    old_value = os.environ.get("VSCODE_TEMPLATE_CONFIG")
    os.environ["VSCODE_TEMPLATE_CONFIG"] = str(test_config)
    yield
    if old_value is None:
        os.environ.pop("VSCODE_TEMPLATE_CONFIG", None)
    else:
        os.environ["VSCODE_TEMPLATE_CONFIG"] = old_value


@pytest.fixture
def test_dir() -> Generator[Path, None, None]:
    """一時テストディレクトリを作成"""
    tmpdir = Path(tempfile.mkdtemp(prefix="pytest-template-"))
    yield tmpdir

    # クリーンアップ
    if tmpdir.exists():
        shutil.rmtree(tmpdir)


def run_setup_script(setup_script: Path, test_dir: Path, template_dir: Path,
                      template_types: list[str]) -> tuple[int, str, str]:
    """セットアップスクリプトを実行

    Returns:
        (exit_code, stdout, stderr)
    """
    import subprocess

    cmd = [
        "python3",
        str(setup_script),
        "-l", str(template_dir / "test"),
        "-d", "test"
    ] + template_types

    result = subprocess.run(
        cmd,
        cwd=test_dir,
        capture_output=True,
        text=True
    )

    return result.returncode, result.stdout, result.stderr
