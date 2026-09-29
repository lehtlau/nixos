#!/usr/bin/env bash
# check-fix.sh — lint/format helper for a NixOS flake directory
#
# Mirrors a "check:fix" workflow (lint + auto-format) but for Nix code:
#   - alejandra   : formats *.nix files (drop-in for nixpkgs-fmt, more opinionated)
#   - statix      : lints & auto-fixes common antipatterns
#   - deadnix     : finds & removes unused bindings/imports
#   - nix flake check : validates the flake still evaluates after fixes
#
# Usage:
#   ./check-fix.sh              # fix mode (default) — formats and auto-fixes in place
#   ./check-fix.sh --check      # check-only mode — fails (non-zero exit) if anything needs fixing, no writes
#   ./check-fix.sh --all-hosts  # also evaluate every nixosConfigurations.* host, not just the current one
#
# By default only the CURRENT machine's nixosConfigurations.<hostname> is evaluated,
# since `nix flake check` evaluates ALL hosts in the flake and will fail if another
# host's config (e.g. one with packages/inputs not present on this machine) is broken.
 
set -euo pipefail
 
# Re-exec ourselves inside a nix-shell with all required tools, unless we're
# already inside one (guarded by CHECK_FIX_IN_SHELL to avoid re-entering).
if [[ -z "${CHECK_FIX_IN_SHELL:-}" ]]; then
  exec nix-shell -p alejandra statix deadnix --run \
    "CHECK_FIX_IN_SHELL=1 $0 $*"
fi
 
MODE="fix"
ALL_HOSTS="false"
for arg in "$@"; do
  case "$arg" in
    --check) MODE="check" ;;
    --all-hosts) ALL_HOSTS="true" ;;
  esac
done
 
FLAKE_DIR="$(pwd)"
echo "==> Running in: $FLAKE_DIR (mode: $MODE)"
 
run_tool() {
  local name="$1"
  shift
  "$name" "$@"
}
 
echo "--- Formatting (alejandra) ---"
if [[ "$MODE" == "check" ]]; then
  run_tool alejandra --check .
else
  run_tool alejandra .
fi
 
echo "--- Linting (statix) ---"
if [[ "$MODE" == "check" ]]; then
  run_tool statix check .
else
  run_tool statix fix .
fi
 
echo "--- Dead code (deadnix) ---"
if [[ "$MODE" == "check" ]]; then
  run_tool deadnix --fail .
else
  run_tool deadnix --edit .
fi
 
echo "--- Flake sanity check ---"
if [[ "$ALL_HOSTS" == "true" ]]; then
  echo "==> Checking ALL nixosConfigurations hosts"
  nix flake check "$FLAKE_DIR" --no-build
else
  HOST="$(hostname)"
  echo "==> Checking only current host: $HOST"
  echo "    (use --all-hosts to evaluate every nixosConfigurations.* entry)"
  nix build "$FLAKE_DIR#nixosConfigurations.$HOST.config.system.build.toplevel" \
    --no-link --show-trace
fi
 
echo "==> Done. Flake looks good."