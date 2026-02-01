# VSCode Project Template Setup - AI Coding Assistant Instructions

## Project Overview

This is a **template distribution system** that downloads VSCode project configurations from GitHub and applies them to any project directory. Think of it as a "dotfiles manager" specifically for VSCode project settings.

**Core Concept**: Users run `./vscode-project-startup.sh <template-name>` to download and merge template files (settings.json, .gitignore, etc.) from the `templete/` directory into their project.

## Architecture & Key Components

### Main Script: vscode-project-startup.sh

**Configuration-Driven Design**: The script is highly extensible through Bash associative arrays. New templates work automatically with default mappings, and custom mappings are added by declaring `<TEMPLATE>_FOLDER_MAPPING` arrays.

**Critical Mappings** (lines 31-63):
- `DEFAULT_FOLDER_MAPPING`: Maps template subdirs to project locations
  - `vscode/` → `.vscode/` (VSCode settings)
  - `git/` → `.` (project root, for .gitignore)
  - `config/` → `.` (for .editorconfig, etc.)
- `DEFAULT_MERGE_SETTING`: Patterns for files to merge (not overwrite): `*.json`, `*.code-snippets`
- Template-specific mappings: e.g., `PYTHON_FOLDER_MAPPING` adds `docs/` and `tests/` directories

**JSON Merge Strategy** (lines 368-383): Uses `jq` to deep-merge JSON files when updating existing projects. This allows incremental updates without losing existing settings. Falls back to simple overwrite if `jq` unavailable.

### Template Structure

```
templete/
├── base/           # Generic settings for any project
├── python/         # Python-specific extensions to base
└── docker/         # Docker-specific configurations
```

**Layering Pattern**: Templates are designed to be composed. Run `./vscode-project-startup.sh base python` to apply base first, then Python-specific overrides. Later templates override earlier ones.

## Development Workflows

### Testing

**Two-tier test strategy**:

1. **BATS Unit Tests** (primary): `bats test/vscode-project-startup.bats`
   - Tests individual functions in isolation
   - Run via VS Code task: "Run BATS Tests" (default test task)
   - Filter specific tests: `bats --filter "merge"` or use "Run BATS Tests (Filter)" task
   - **Coverage**: Mapping resolution, JSON merge logic, file destination calculation

2. **Manual Integration Tests**: `./test/manual/test-local.sh` and `test-merge.sh`
   - Full end-to-end validation with real file operations
   - Use for visual verification of file placement and merging

### Adding New Templates

1. Create `templete/<name>/` directory with standard subdirs (vscode/, git/, config/)
2. Add files in appropriate subdirectories
3. (Optional) Add custom mappings in script if defaults don't fit:
   ```bash
   declare -A MYTEMPLATE_FOLDER_MAPPING=(["special"]="custom/path")
   ```
4. Test with `./vscode-project-startup.sh mytemplate` in a temporary directory

## Project-Specific Conventions

### Configuration Over Code

- **No hardcoded paths**: All file placement is driven by mapping arrays
- **Default-first design**: New templates work immediately without configuration
- **Bash associative arrays**: Used extensively for flexible configuration (requires Bash 4+)

### File Naming Patterns

- Templates use subdirectory names (`vscode/`, `git/`) to indicate destination
- Individual files can override via `<TEMPLATE>_FILE_MAPPING` (e.g., `requirements.txt` → project root)

### Color-Coded Output

- Green (✓): Success
- Yellow (!): Warning or merge operation
- Red (✗): Error
- Blue: Informational headers

Uses ANSI color codes defined at top of script (lines 14-17).

### JSON Merging Details

When a target file exists and matches `DEFAULT_MERGE_SETTING` patterns:
1. Creates timestamped backup: `filename.backup.20260201_123045`
2. Uses `jq -s '.[0] * .[1]'` for deep merge (right side wins on conflicts)
3. Falls back to overwrite if `jq` missing (with warning)

## Integration Points

- **GitHub API**: Uses `https://api.github.com/repos/${GITHUB_USER}/${REPO_NAME}/contents/` to list files
- **GitHub Raw**: Downloads via `https://raw.githubusercontent.com/${GITHUB_USER}/${REPO_NAME}/${BRANCH}/`
- **Dependencies**:
  - `curl` (required): Download files
  - `jq` (optional): JSON merging
  - `bats` (development): Unit testing

## Critical Configuration

**MUST SET** in script before first use (line 37):
```bash
GITHUB_USER="YOUR_GITHUB_USERNAME"  # Change to your actual username
```

Without this, GitHub API calls fail (repo not found).

## Common Pitfalls

1. **Case sensitivity**: Template names are case-sensitive but converted to uppercase for variable lookup (`python` → `PYTHON_FOLDER_MAPPING`)
2. **Mapping precedence**: File mappings override folder mappings for specific files
3. **Multiple templates**: Order matters - later templates override earlier ones
4. **Bash version**: Requires Bash 4+ for associative arrays (check with `bash --version`)
5. **JSON merge requires jq**: Install with `brew install jq` or `apt-get install jq` for merge functionality

## When Modifying

- **Adding template support**: Edit configuration section (lines 20-91), main logic rarely needs changes
- **Testing is mandatory**: Run BATS tests after any changes to mapping logic
- **Preserve backward compatibility**: Default mappings should work for existing templates
