"""pytest設定とフィクスチャ"""
import shutil
import subprocess
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
def install_test_packages():
    """テストに必要なパッケージをインストール（一度だけ）"""
    try:
        subprocess.run(
            ["pip", "install", "-q", "pyyaml", "tomli", "tomli-w"],
            check=True,
            capture_output=True
        )
    except subprocess.CalledProcessError:
        pytest.skip("パッケージのインストールに失敗しました")


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
