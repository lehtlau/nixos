#!/usr/bin/env bash
# Rewrites the `my.user = { ... };` block in modules/system/users/default.nix, 
# Remove any personal info before committing to the mirror.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
USERS_FILE="$REPO_DIR/modules/system/users/default.nix"

NAME=""
EMAIL=""
KEYS=()
no_keys="true"

usage() {
  sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --name) NAME="${2:?--name needs a value}"; shift 2 ;;
    --email) EMAIL="${2:?--email needs a value}"; shift 2 ;;
    --key) KEYS+=("${2:?--key needs a value}"); shift 2 ;;
    --no-keys) NO_KEYS="true"; shift ;;
    -h | --help) usage ;;
    *) echo "Unknown argument: $1" >&2; usage 1 ;;
  esac
done

if [[ ! -f "$USERS_FILE" ]]; then
  echo "Error: $USERS_FILE not found" >&2
  exit 1
fi

# --- ask for anything not given as a flag ---

while [[ ! "$NAME" =~ ^[a-z_][a-z0-9_-]*$ ]]; do
  [[ -n "$NAME" ]] && echo "Invalid username '$NAME': use lowercase letters, digits, - and _, starting with a letter." >&2
  read -rp "Username: " NAME
done

while [[ -z "$EMAIL" ]]; do
  read -rp "Email (used for git): " EMAIL
done

if [[ ${#KEYS[@]} -eq 0 && "$NO_KEYS" == "false" ]]; then
  echo "SSH public keys allowed to log in as $NAME, one per line. Empty line to finish."
  while read -rp "key> " key && [[ -n "$key" ]]; do
    KEYS+=("$key")
  done
fi

for key in "${KEYS[@]}"; do
  if [[ ! "$key" =~ ^(ssh-|ecdsa-|sk-) ]]; then
    echo "Error: doesn't look like an ssh public key: $key" >&2
    exit 1
  fi
done

# --- build the new block ---

# escape a value for use inside a Nix "double quoted" string
nix_str() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//\$\{/\\\$\{}"
  printf '"%s"' "$s"
}

NEW_BLOCK="$(mktemp)"
TMP_FILE="$(mktemp)"
trap 'rm -f "$NEW_BLOCK" "$TMP_FILE"' EXIT

{
  echo "  my.user = {"
  echo "    name = $(nix_str "$NAME");"
  echo "    email = $(nix_str "$EMAIL");"
  if [[ ${#KEYS[@]} -eq 0 ]]; then
    echo "    keys = [];"
  else
    echo "    keys = ["
    for key in "${KEYS[@]}"; do
      echo "      $(nix_str "$key")"
    done
    echo "    ];"
  fi
  echo "  };"
} >"$NEW_BLOCK"

# --- replace the old block: from "  my.user = {" up to its closing "  };" ---

awk -v block="$NEW_BLOCK" '
  !done && /^  my\.user = \{/ {
    while ((getline line < block) > 0) print line
    skipping = 1
    next
  }
  skipping {
    if (/^  \};/) { skipping = 0; done = 1 }
    next
  }
  { print }
  END { if (!done) exit 1 }
' "$USERS_FILE" >"$TMP_FILE" || {
  echo "Error: couldn't find the 'my.user = { ... };' block in $USERS_FILE" >&2
  exit 1
}

cat "$TMP_FILE" >"$USERS_FILE"

echo "==> Updated my.user in $USERS_FILE:"
cat "$NEW_BLOCK"
