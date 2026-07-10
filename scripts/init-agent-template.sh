#!/usr/bin/env bash
set -euo pipefail

TEMPLATE_REPO_DEFAULT="https://github.com/stephanemalho/multi-harness-agent-template.git"
TEMPLATE_REPO="${TEMPLATE_REPO:-${TEMPLATE_REPO_DEFAULT}}"

# Paths copied into the target project. LICENSE-*, README.md, and .git stay in
# the template repository.
INCLUDE_PATHS=(
  "AGENTS.md"
  "CLAUDE.md"
  "GEMINI.md"
  ".env.example"
  "agent-template.yml"
  ".codex"
  ".claude"
  ".gemini"
  ".agents"
  "docs"
  "scripts"
  ".github"
)

# Local-only files that must never be copied even if present in the source.
EXCLUDE_BASENAMES=(
  "settings.local.json"
  ".DS_Store"
)

usage() {
  cat <<'EOF'
usage: init-agent-template.sh [target-dir] [--force] [--no-prompt] [--repo <url>]

Install the multi-harness agent template into a new or existing project.

  target-dir    directory to install into (default: current directory)
  --force       overwrite files that already exist in the target
  --no-prompt   skip interactive placeholder replacement
  --repo <url>  template repository to clone when not running from a checkout
                (also configurable via the TEMPLATE_REPO environment variable)

From a checkout of the template:
  scripts/init-agent-template.sh ../my-project

From any directory, without cloning first:
  curl -fsSL https://raw.githubusercontent.com/stephanemalho/multi-harness-agent-template/main/scripts/init-agent-template.sh | bash -s -- .
EOF
}

TARGET_DIR=""
FORCE=0
NO_PROMPT=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --force) FORCE=1; shift ;;
    --no-prompt) NO_PROMPT=1; shift ;;
    --repo)
      [[ $# -ge 2 ]] || { echo "error: --repo requires a url" >&2; exit 1; }
      TEMPLATE_REPO="$2"; shift 2 ;;
    -*)
      echo "error: unknown option: $1" >&2; usage >&2; exit 1 ;;
    *)
      [[ -z "${TARGET_DIR}" ]] || { echo "error: multiple target dirs given" >&2; exit 1; }
      TARGET_DIR="$1"; shift ;;
  esac
done

TARGET_DIR="${TARGET_DIR:-.}"
mkdir -p "${TARGET_DIR}"
TARGET_DIR="$(cd "${TARGET_DIR}" && pwd)"

# Resolve the template source: the surrounding checkout when this script runs
# from scripts/, otherwise a shallow clone (curl | bash case).
SOURCE_DIR=""
TMP_CLONE=""
cleanup() { [[ -n "${TMP_CLONE}" ]] && rm -rf "${TMP_CLONE}"; }
trap cleanup EXIT

SCRIPT_SOURCE="${BASH_SOURCE[0]:-}"
if [[ -n "${SCRIPT_SOURCE}" && -f "${SCRIPT_SOURCE}" ]]; then
  CANDIDATE="$(cd "$(dirname "${SCRIPT_SOURCE}")/.." && pwd)"
  if [[ -f "${CANDIDATE}/agent-template.yml" && -f "${CANDIDATE}/AGENTS.md" ]]; then
    SOURCE_DIR="${CANDIDATE}"
  fi
fi

if [[ -z "${SOURCE_DIR}" ]]; then
  command -v git >/dev/null || { echo "error: git is required to fetch the template" >&2; exit 1; }
  TMP_CLONE="$(mktemp -d)"
  echo "fetching template from ${TEMPLATE_REPO}"
  git clone --depth 1 --quiet "${TEMPLATE_REPO}" "${TMP_CLONE}/template"
  SOURCE_DIR="${TMP_CLONE}/template"
fi

if [[ "${SOURCE_DIR}" == "${TARGET_DIR}" ]]; then
  echo "error: target directory is the template checkout itself" >&2
  exit 1
fi

is_excluded() {
  local base
  base="$(basename "$1")"
  for excluded in "${EXCLUDE_BASENAMES[@]}"; do
    [[ "${base}" == "${excluded}" ]] && return 0
  done
  return 1
}

COPIED=0
SKIPPED=0
copy_file() {
  local rel="$1"
  is_excluded "${rel}" && return 0
  if [[ -e "${TARGET_DIR}/${rel}" && "${FORCE}" != "1" ]]; then
    echo "skip (exists): ${rel}"
    SKIPPED=$((SKIPPED + 1))
    return 0
  fi
  mkdir -p "$(dirname "${TARGET_DIR}/${rel}")"
  cp "${SOURCE_DIR}/${rel}" "${TARGET_DIR}/${rel}"
  COPIED=$((COPIED + 1))
}

for path in "${INCLUDE_PATHS[@]}"; do
  if [[ -f "${SOURCE_DIR}/${path}" ]]; then
    copy_file "${path}"
  elif [[ -d "${SOURCE_DIR}/${path}" ]]; then
    while IFS= read -r file; do
      copy_file "${file#"${SOURCE_DIR}/"}"
    done < <(find "${SOURCE_DIR}/${path}" -type f | sort)
  else
    echo "warning: template path not found, skipped: ${path}" >&2
  fi
done

chmod +x "${TARGET_DIR}/scripts/"*.sh 2>/dev/null || true
echo "copied ${COPIED} files, skipped ${SKIPPED} existing files"

# Interactive placeholder replacement. Only project-identity placeholders are
# prompted; content placeholders inside docs/agent-rules/*.template.md are
# meant to be filled while writing the real rules.
PLACEHOLDER_KEYS=(
  "PROJECT_NAME_REPLACE_ME"
  "PROJECT_TYPE_REPLACE_ME"
  "STACK_REPLACE_ME"
  "RUNTIME_REPLACE_ME"
  "OWNER_REPLACE_ME"
  "PROJECT_LINT_COMMAND_REPLACE_ME"
  "PROJECT_TEST_COMMAND_REPLACE_ME"
  "PROJECT_BUILD_COMMAND_REPLACE_ME"
)
PLACEHOLDER_LABELS=(
  "Project name"
  "Project type (api, webapp, cli, library, ...)"
  "Primary stack (language, framework)"
  "Runtime / package manager (node+pnpm, python+uv, ...)"
  "Human maintainer (name or GitHub handle)"
  "Lint command"
  "Test command"
  "Build command"
)

replace_placeholder() {
  local key="$1" value="$2"
  KEY="${key}" VALUE="${value}" TARGET="${TARGET_DIR}" python3 - <<'PY'
import os, pathlib

key = os.environ["KEY"]
value = os.environ["VALUE"]
root = pathlib.Path(os.environ["TARGET"])
skip_dirs = {".git", "node_modules"}
# The installed copy of this script lists the placeholder tokens; rewriting it
# would corrupt its own replacement table.
skip_files = {"init-agent-template.sh"}

for path in root.rglob("*"):
    if not path.is_file() or path.name in skip_files or skip_dirs & set(path.parts):
        continue
    try:
        text = path.read_text(encoding="utf-8")
    except (UnicodeDecodeError, OSError):
        continue
    if key in text:
        path.write_text(text.replace(key, value), encoding="utf-8")
PY
}

if [[ "${NO_PROMPT}" != "1" && -r /dev/tty ]]; then
  echo ""
  echo "Fill the project identity (leave empty to keep the placeholder):"
  for i in "${!PLACEHOLDER_KEYS[@]}"; do
    printf "  %s: " "${PLACEHOLDER_LABELS[$i]}" > /dev/tty
    IFS= read -r answer < /dev/tty || answer=""
    [[ -n "${answer}" ]] && replace_placeholder "${PLACEHOLDER_KEYS[$i]}" "${answer}"
  done
else
  echo "skipping placeholder prompts (no tty or --no-prompt); fill *_REPLACE_ME tokens manually"
fi

if ! git -C "${TARGET_DIR}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git init --quiet "${TARGET_DIR}"
  echo "initialized empty git repository in ${TARGET_DIR}"
fi

echo ""
if (cd "${TARGET_DIR}" && scripts/validate-agent-template.sh); then
  :
else
  echo "warning: template validation failed; review the output above" >&2
fi

cat <<EOF

template installed in: ${TARGET_DIR}
next steps:
  1. Review docs/FILL-ME-FIRST.md and fill the remaining *_REPLACE_ME tokens.
  2. Replace placeholder rules in docs/agent-rules/*.template.md.
  3. Commit, push, and enable branch protection on main (.github/branch-protection.md).
EOF
