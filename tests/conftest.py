"""pytest設定とフィクスチャ"""
import os
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
def shared_venv(tmp_path_factory) -> Path:
    """セッション全体で共有する.venv環境を作成"""
    venv_dir = tmp_path_factory.mktemp("shared-venv")

    # .venvを作成
    subprocess.run(
        ["python3", "-m", "venv", str(venv_dir)],
        check=True,
        capture_output=True
    )

    # 必要なパッケージをインストール
    pip = venv_dir / "bin" / "pip"
    subprocess.run(
        [str(pip), "install", "-q", "pyyaml", "tomli", "tomli-w"],
        check=True,
        capture_output=True
    )

    return venv_dir


@pytest.fixture
def test_dir(shared_venv: Path) -> Generator[Path, None, None]:
    """一時テストディレクトリを作成"""
    tmpdir = Path(tempfile.mkdtemp(prefix="pytest-template-"))

    # 共有venvへのシンボリックリンクを作成
    venv_link = tmpdir / ".venv"
    venv_link.symlink_to(shared_venv, target_is_directory=True)

    yield tmpdir

    # クリーンアップ
    if tmpdir.exists():
        shutil.rmtree(tmpdir)


@pytest.fixture(autouse=True)
def skip_auto_install():
    """パッケージの自動インストールをスキップ（共有venvを使用）"""
    old_value = os.environ.get('AUTO_INSTALL_DEPS')
    os.environ['AUTO_INSTALL_DEPS'] = 'skip'
    yield
    if old_value is None:
        os.environ.pop('AUTO_INSTALL_DEPS', None)
    else:
        os.environ['AUTO_INSTALL_DEPS'] = old_value


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
