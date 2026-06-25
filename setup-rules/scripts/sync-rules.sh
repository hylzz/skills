#!/usr/bin/env bash
# Copy global Cursor rule templates into a project's .cursor/rules/
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: sync-rules.sh [OPTIONS] [PROJECT_ROOT]

Copy .mdc rule templates from ~/.cursor/rules into PROJECT_ROOT/.cursor/rules/.
Default PROJECT_ROOT is the current directory.

Options:
  --force     Overwrite existing .mdc files in the project
  --dry-run   Print actions without copying
  -h, --help  Show this help

Environment:
  CURSOR_RULES_SRC  Override global rules source (default: ~/.cursor/rules)
EOF
}

resolve_rules_src() {
  if [[ -n "${CURSOR_RULES_SRC:-}" ]]; then
    echo "$CURSOR_RULES_SRC"
    return
  fi
  echo "$HOME/.cursor/rules"
}

FORCE=0
DRY_RUN=0
PROJECT_ROOT="."

while [[ $# -gt 0 ]]; do
  case "$1" in
    --force) FORCE=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    -*) echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
    *) PROJECT_ROOT="$1"; shift ;;
  esac
done

RULES_SRC="$(resolve_rules_src)"
if [[ ! -d "$RULES_SRC" ]]; then
  echo "Global rules directory not found: $RULES_SRC" >&2
  echo "Manually install .mdc files: mkdir -p ~/.cursor/rules && cp your-rule.mdc ~/.cursor/rules/" >&2
  exit 1
fi

DEST="$(cd "$PROJECT_ROOT" && pwd)/.cursor/rules"
shopt -s nullglob
mdc_files=("$RULES_SRC"/*.mdc)
shopt -u nullglob

if [[ ${#mdc_files[@]} -eq 0 ]]; then
  echo "No .mdc files in: $RULES_SRC" >&2
  echo "Manually install rules you want to reuse globally, then run sync again." >&2
  exit 1
fi

if [[ "$DRY_RUN" -eq 0 ]]; then
  mkdir -p "$DEST"
fi

copied=0
skipped=0

for src in "${mdc_files[@]}"; do
  base="$(basename "$src")"
  target="$DEST/$base"
  if [[ -f "$target" && "$FORCE" -eq 0 ]]; then
    echo "SKIP (exists): $base"
    skipped=$((skipped + 1))
    continue
  fi
  if [[ "$DRY_RUN" -eq 1 ]]; then
    if [[ -f "$target" && "$FORCE" -eq 1 ]]; then
      echo "WOULD OVERWRITE: $base"
    else
      echo "WOULD COPY: $base"
    fi
    copied=$((copied + 1))
    continue
  fi
  cp "$src" "$target"
  echo "COPIED: $base"
  copied=$((copied + 1))
done

echo ""
echo "Source:  $RULES_SRC"
echo "Target:  $DEST"
echo "Copied:  $copied  Skipped: $skipped"
