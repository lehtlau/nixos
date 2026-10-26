#!/usr/bin/env bash
# Usage: scripts/check-fix.sh [--check] [--all-hosts]
set -euo pipefail

if [[ -z "${CHECK_FIX_IN_SHELL:-}" ]]; then
  printf -v command 'CHECK_FIX_IN_SHELL=1 bash %q' "$0"
  arguments=""
  if [[ $# -gt 0 ]]; then
    printf -v arguments ' %q' "$@"
  fi
  exec nix-shell -p alejandra statix deadnix --run "$command$arguments"
fi

MODE="fix"
ALL_HOSTS="false"
for arg in "$@"; do
  case "$arg" in
    --check) MODE="check" ;;
    --all-hosts) ALL_HOSTS="true" ;;
    *) echo "Unknown argument: $arg" >&2; exit 1 ;;
  esac
done

FLAKE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$FLAKE_DIR"
echo "==> Running in: $FLAKE_DIR (mode: $MODE)"

echo "--- Linting (statix) ---"
if [[ "$MODE" == "check" ]]; then
  statix check .
else
  statix fix .
fi

echo "--- Dead code (deadnix) ---"
if [[ "$MODE" == "check" ]]; then
  deadnix --fail .
else
  deadnix --edit .
fi

echo "--- Formatting (alejandra) ---"
if [[ "$MODE" == "check" ]]; then
  alejandra --check .
else
  alejandra .
fi

echo "--- Flake sanity check ---"
if [[ "$ALL_HOSTS" == "true" ]]; then
  nix flake check "$FLAKE_DIR" --no-build --no-update-lock-file
else
  HOST="$(hostname)"
  echo "==> Checking current host: $HOST"
  nix eval --raw "$FLAKE_DIR#nixosConfigurations.$HOST.config.system.build.toplevel.drvPath" \
    --no-update-lock-file --show-trace >/dev/null
fi

echo "==> Done. Flake looks good."
