#!/usr/bin/env python3
"""
VSCode プロジェクトテンプレート セットアップスクリプト (Python版)

GitHubリポジトリまたはローカルからテンプレートを取得し、プロジェクトに配置します。
JSON/YAML/TOML/XMLファイルのマージをサポート。
"""

import argparse
import json
import os
import shutil
import sys
import tempfile
from pathlib import Path
from typing import Dict, List, Optional, Set, Tuple
from urllib import request
from urllib.error import HTTPError, URLError

# 構造化ファイル処理用ライブラリ（遅延インポート）
try:
    import yaml
    HAS_YAML = True
except ImportError:
    HAS_YAML = False

try:
    import tomli
    import tomli_w
    HAS_TOML = True
except ImportError:
    try:
        import tomllib as tomli  # Python 3.11+
        import tomli_w
        HAS_TOML = True
    except ImportError:
        HAS_TOML = False

try:
    from xml.etree import ElementTree as ET
    HAS_XML = True
except ImportError:
    HAS_XML = False


# カラーコード
class Colors:
    RED = '\033[0;31m'
    GREEN = '\033[0;32m'
    YELLOW = '\033[1;33m'
    BLUE = '\033[0;34m'
    NC = '\033[0m'  # No Color


# ============================================================================
# 設定管理
# ============================================================================

class Config:
    """設定管理クラス"""

    def __init__(self, config_path: Optional[Path] = None):
        """
        設定を読み込む

        Args:
            config_path: 設定ファイルのパス（指定しない場合はデフォルトを使用）
        """
        self.config_path = config_path or Path(__file__).parent / "config.json"
        self._config = self._load_config()

    def _load_config(self) -> dict:
        """設定ファイルを読み込む"""
        if not self.config_path.exists():
            print_error(f"設定ファイルが見つかりません: {self.config_path}")
            print_error("config.json を作成してください。")
            sys.exit(1)
        
        try:
            with self.config_path.open('r', encoding='utf-8') as f:
                return json.load(f)
        except json.JSONDecodeError as e:
            print_error(f"設定ファイルのJSON形式が不正です: {e}")
            sys.exit(1)
        except Exception as e:
            print_error(f"設定ファイル読み込みエラー: {e}")
            sys.exit(1)

    @property
    def github_user(self) -> str:
        return self._config["github"]["user"]

    @property
    def repo_name(self) -> str:
        return self._config["github"]["repo"]

    @property
    def branch(self) -> str:
        return self._config["github"]["branch"]

    @property
    def folder_mapping(self) -> Dict[str, str]:
        return self._config["folder_mapping"]

    @property
    def file_mapping(self) -> Dict[str, str]:
        return self._config["file_mapping"]

    @property
    def merge_patterns(self) -> List[str]:
        return self._config["merge_patterns"]

    def get_template_folder_mapping(self, template_name: str) -> Dict[str, str]:
        """テンプレート固有のフォルダマッピングを取得"""
        templates = self._config.get("templates", {})
        template_config = templates.get(template_name, {})
        return template_config.get("folder_mapping", {})

    def get_template_file_mapping(self, template_name: str) -> Dict[str, str]:
        """テンプレート固有のファイルマッピングを取得"""
        templates = self._config.get("templates", {})
        template_config = templates.get(template_name, {})
        return template_config.get("file_mapping", {})


# ============================================================================
# ユーティリティ関数
# ============================================================================

def print_error(message: str) -> None:
    """エラーメッセージを表示"""
    print(f"{Colors.RED}エラー: {message}{Colors.NC}", file=sys.stderr)


def print_success(message: str) -> None:
    """成功メッセージを表示"""
    print(f"{Colors.GREEN}✓{Colors.NC} {message}")


def print_info(message: str) -> None:
    """情報メッセージを表示"""
    print(f"{Colors.BLUE}{message}{Colors.NC}")


def load_github_token() -> Optional[str]:
    """GitHubトークンを読み込む（環境変数 > .github_token > ~/.config/...）"""
    # 1. 環境変数
    token = os.environ.get("GITHUB_TOKEN")
    if token:
        return token

    # 2. プロジェクトローカル
    local_token_file = Path(".github_token")
    if local_token_file.exists():
        return local_token_file.read_text().strip()

    # 3. グローバル設定
    global_token_file = Path.home() / ".config" / "vscode-templates" / "token"
    if global_token_file.exists():
        return global_token_file.read_text().strip()

    return None


def should_merge_file(filename: str, merge_patterns: List[str]) -> bool:
    """ファイルがマージ対象かどうかを判定"""
    from fnmatch import fnmatch
    return any(fnmatch(filename, pattern) for pattern in merge_patterns)


# ============================================================================
# マージ関数
# ============================================================================

def merge_json(existing_data: dict, new_data: dict) -> dict:
    """JSONデータを深くマージ"""
    result = existing_data.copy()

    for key, value in new_data.items():
        if key in result and isinstance(result[key], dict) and isinstance(value, dict):
            result[key] = merge_json(result[key], value)
        else:
            result[key] = value

    return result


def merge_json_files(existing_file: Path, new_file: Path, output_file: Path) -> bool:
    """JSONファイルをマージ"""
    try:
        with existing_file.open('r', encoding='utf-8') as f:
            existing_data = json.load(f)

        with new_file.open('r', encoding='utf-8') as f:
            new_data = json.load(f)

        merged_data = merge_json(existing_data, new_data)

        with output_file.open('w', encoding='utf-8') as f:
            json.dump(merged_data, f, indent=2, ensure_ascii=False)
            f.write('\n')

        return True
    except Exception as e:
        print_error(f"JSON マージエラー: {e}")
        return False


def merge_yaml_files(existing_file: Path, new_file: Path, output_file: Path) -> bool:
    """YAMLファイルをマージ"""
    if not HAS_YAML:
        print_error("PyYAML がインストールされていません: pip install pyyaml")
        return False

    try:
        with existing_file.open('r', encoding='utf-8') as f:
            existing_data = yaml.safe_load(f) or {}

        with new_file.open('r', encoding='utf-8') as f:
            new_data = yaml.safe_load(f) or {}

        merged_data = merge_json(existing_data, new_data)

        with output_file.open('w', encoding='utf-8') as f:
            yaml.dump(merged_data, f, default_flow_style=False, allow_unicode=True)

        return True
    except Exception as e:
        print_error(f"YAML マージエラー: {e}")
        return False


def merge_toml_files(existing_file: Path, new_file: Path, output_file: Path) -> bool:
    """TOMLファイルをマージ"""
    if not HAS_TOML:
        print_error("tomli/tomli_w がインストールされていません: pip install tomli tomli-w")
        return False

    try:
        with existing_file.open('rb') as f:
            existing_data = tomli.load(f)

        with new_file.open('rb') as f:
            new_data = tomli.load(f)

        merged_data = merge_json(existing_data, new_data)

        with output_file.open('wb') as f:
            tomli_w.dump(merged_data, f)

        return True
    except Exception as e:
        print_error(f"TOML マージエラー: {e}")
        return False


def merge_xml_files(existing_file: Path, new_file: Path, output_file: Path) -> bool:
    """XMLファイルをマージ（基本的な実装）"""
    if not HAS_XML:
        print_error("XML サポートが利用できません")
        return False

    try:
        existing_tree = ET.parse(existing_file)
        new_tree = ET.parse(new_file)

        existing_root = existing_tree.getroot()
        new_root = new_tree.getroot()

        # 新しい要素を追加（単純な追加のみ、深いマージはなし）
        for child in new_root:
            existing_root.append(child)

        existing_tree.write(output_file, encoding='utf-8', xml_declaration=True)
        return True
    except Exception as e:
        print_error(f"XML マージエラー: {e}")
        return False


def merge_structured_file(existing_file: Path, new_file: Path, output_file: Path) -> bool:
    """構造化ファイルを拡張子に応じてマージ"""
    ext = existing_file.suffix.lower()

    if ext == '.json' or ext == '.code-snippets':
        return merge_json_files(existing_file, new_file, output_file)
    elif ext in ['.yaml', '.yml']:
        return merge_yaml_files(existing_file, new_file, output_file)
    elif ext == '.toml':
        return merge_toml_files(existing_file, new_file, output_file)
    elif ext == '.xml':
        return merge_xml_files(existing_file, new_file, output_file)
    else:
        print_error(f"未対応の拡張子: {ext}")
        return False


# ============================================================================
# テンプレート取得
# ============================================================================

class TemplateSource:
    """テンプレートソース（GitHub または ローカル）"""

    def __init__(self, config: Config, local_path: Optional[Path] = None, token: Optional[str] = None):
        self.config = config
        self.local_path = local_path
        self.token = token
        self.is_local = local_path is not None

    def get_file_content(self, template_path: str) -> Optional[bytes]:
        """ファイル内容を取得"""
        if self.is_local and self.local_path:
            file_path = self.local_path / template_path
            if file_path.exists():
                return file_path.read_bytes()
            return None
        else:
            return self._download_from_github(template_path)

    def _download_from_github(self, template_path: str) -> Optional[bytes]:
        """GitHubからファイルをダウンロード"""
        url = f"https://raw.githubusercontent.com/{self.config.github_user}/{self.config.repo_name}/{self.config.branch}/{template_path}"

        req = request.Request(url)
        if self.token:
            req.add_header("Authorization", f"token {self.token}")

        try:
            with request.urlopen(req) as response:
                return response.read()
        except HTTPError as e:
            if e.code == 404:
                return None
            print_error(f"HTTP エラー {e.code}: {url}")
            return None
        except URLError as e:
            print_error(f"URL エラー: {e.reason}")
            return None

    def list_template_files(self, template_dir: str, template_name: str, subfolder: str) -> List[str]:
        """テンプレート内のファイルをリスト"""
        base_path = f"{template_dir}/{template_name}/{subfolder}"

        if self.is_local:
            return self._list_local_files(base_path)
        else:
            # GitHubの場合、実際にファイルを探索するのは困難なため
            # 既知のパターンを試行する簡易実装
            # より堅牢な実装はGitHub APIを使用する必要がある
            return self._list_github_files_simple(base_path)

    def _list_local_files(self, base_path: str) -> List[str]:
        """ローカルファイルをリスト"""
        if not self.local_path:
            return []

        full_path = self.local_path / base_path
        if not full_path.exists():
            return []

        files = []
        for item in full_path.rglob('*'):
            if item.is_file():
                rel_path = item.relative_to(full_path)
                files.append(str(rel_path))
        return files

    def _list_github_files_simple(self, base_path: str) -> List[str]:
        """GitHubファイルを簡易リスト（既知のパターンを試行）"""
        # 注: これは簡易実装。実際のGitHub API実装が必要
        # 現時点ではシェルスクリプトと同様に、既知のファイルパターンを試行
        common_patterns = [
            "settings.json",
            "extensions.json",
            "launch.json",
            "tasks.json",
            ".gitignore",
            "Dockerfile",
            "docker-compose.yml",
            "pyproject.toml",
            "requirements.txt",
        ]

        found_files = []
        for pattern in common_patterns:
            test_path = f"{base_path}/{pattern}"
            if self.get_file_content(test_path):
                found_files.append(pattern)

        return found_files


# ============================================================================
# メイン処理
# ============================================================================

class TemplateSetup:
    """テンプレートセットアップ処理"""

    def __init__(self, template_types: List[str],
                 config: Optional[Config] = None,
                 template_dir: str = "templates",
                 local_path: Optional[Path] = None,
                 merge_patterns: Optional[List[str]] = None):
        self.template_types = template_types
        self.template_dir = template_dir
        self.config = config or Config()
        self.merge_patterns = merge_patterns or self.config.merge_patterns
        self.project_dir = Path.cwd()

        # テンプレートソース
        token = load_github_token()
        self.source = TemplateSource(config=self.config, local_path=local_path, token=token)

        # 処理するファイルリスト
        self.files_to_process: List[Tuple[str, Path, str]] = []  # (template_path, dest_path, template_name)

    def run(self) -> bool:
        """セットアップ実行"""
        print_info("プロジェクトテンプレート セットアップ")
        print(f"適用テンプレート: {', '.join(self.template_types)}")
        print(f"テンプレートディレクトリ: {self.template_dir}")
        print(f"対象ディレクトリ: {self.project_dir}")
        print()

        # ファイルリストを収集
        if not self._collect_files():
            return False

        print_success(f"合計 {len(self.files_to_process)} 個のファイルを検出")
        print()

        # ファイルを処理
        return self._process_files()

    def _collect_files(self) -> bool:
        """処理対象ファイルを収集"""
        for template_name in self.template_types:
            # Configから設定を取得（デフォルト + テンプレート固有）
            folder_mapping = self.config.folder_mapping.copy()
            folder_mapping.update(self.config.get_template_folder_mapping(template_name))

            file_mapping = self.config.file_mapping.copy()
            file_mapping.update(self.config.get_template_file_mapping(template_name))

            # フォルダベースのファイル
            for subfolder, dest_dir in folder_mapping.items():
                files = self.source.list_template_files(
                    self.template_dir, template_name, subfolder
                )

                for file in files:
                    template_path = f"{self.template_dir}/{template_name}/{subfolder}/{file}"
                    dest_path = self.project_dir / dest_dir / file
                    self.files_to_process.append((template_path, dest_path, template_name))

            # 個別ファイルマッピング
            for filename, dest_dir in file_mapping.items():
                template_path = f"{self.template_dir}/{template_name}/{filename}"
                dest_path = self.project_dir / dest_dir / filename

                # ファイルが存在するか確認
                if self.source.get_file_content(template_path):
                    self.files_to_process.append((template_path, dest_path, template_name))

        return len(self.files_to_process) > 0

    def _process_files(self) -> bool:
        """ファイルを処理（ダウンロード・マージ・配置）"""
        success_count = 0
        merge_count = 0
        overwrite_count = 0

        with tempfile.TemporaryDirectory() as temp_dir:
            temp_path = Path(temp_dir)

            for template_path, dest_path, template_name in self.files_to_process:
                # ファイル内容を取得
                content = self.source.get_file_content(template_path)
                if content is None:
                    print_error(f"取得失敗: {template_path}")
                    continue

                # 一時ファイルに保存
                temp_file = temp_path / dest_path.name
                temp_file.write_bytes(content)

                # 配置先ディレクトリを作成
                dest_path.parent.mkdir(parents=True, exist_ok=True)

                # マージまたはコピー
                if dest_path.exists() and should_merge_file(dest_path.name, self.merge_patterns):
                    # マージ
                    merged_file = temp_path / f"{dest_path.name}.merged"
                    if merge_structured_file(dest_path, temp_file, merged_file):
                        shutil.copy2(merged_file, dest_path)
                        print(f"  [マージ] {dest_path.relative_to(self.project_dir)}")
                        merge_count += 1
                        success_count += 1
                    else:
                        print_error(f"マージ失敗: {dest_path}")
                else:
                    # コピー（上書き）
                    shutil.copy2(temp_file, dest_path)
                    action = "上書き" if dest_path.exists() else "作成"
                    print(f"  [{action}] {dest_path.relative_to(self.project_dir)}")
                    if dest_path.exists():
                        overwrite_count += 1
                    success_count += 1

        print()
        print_success(f"完了: {success_count}/{len(self.files_to_process)} ファイル処理")
        if merge_count > 0:
            print(f"  - マージ: {merge_count} ファイル")
        if overwrite_count > 0:
            print(f"  - 上書き: {overwrite_count} ファイル")

        return success_count > 0


def main():
    """メイン関数"""
    parser = argparse.ArgumentParser(
        description="VSCode プロジェクトテンプレート セットアップ",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
使用例:
  %(prog)s base                    # 基本設定
  %(prog)s base python             # 基本 + Python
  %(prog)s -d test base            # testディレクトリから取得
  %(prog)s -l ./templates base     # ローカルテンプレート使用

プライベートリポジトリの場合:
  export GITHUB_TOKEN='your_token' してから実行
        """
    )

    parser.add_argument(
        'template_types',
        nargs='+',
        help='適用するテンプレート名'
    )

    parser.add_argument(
        '-d', '--template-dir',
        default='templates',
        help='テンプレートディレクトリ (デフォルト: templates)'
    )

    parser.add_argument(
        '-l', '--local',
        type=Path,
        help='ローカルテンプレートディレクトリのパス'
    )

    args = parser.parse_args()

    # セットアップ実行
    setup = TemplateSetup(
        template_types=args.template_types,
        template_dir=args.template_dir,
        local_path=args.local
    )

    success = setup.run()
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
