#!/usr/bin/env bash
# Scrubs personal info out of options.nix before committing to the public mirror:
# server.domain becomes my_domain.com, name and email get placeholders, and sshHosts is emptied. The
# ssh keys plus any hashedPassword / hashedPasswordFile line are removed. It also
# points REPO_URL in scripts/install.sh at the public mirror.
# Override the placeholders with --name <user> and --email <email>.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OPTIONS_FILE="$REPO_DIR/options.nix"
INSTALL_FILE="$REPO_DIR/scripts/install.sh"
MIRROR_URL="https://github.com/lehtlau/nixos"

NAME="user"
EMAIL="user@example.com"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --name) NAME="${2:?--name needs a value}"; shift 2 ;;
    --email) EMAIL="${2:?--email needs a value}"; shift 2 ;;
    *)
      echo "Unknown argument: $1 (only --name <user> and --email <email>)" >&2
      exit 1
      ;;
  esac
done

if [[ ! "$NAME" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
  echo "Error: invalid username '$NAME': use lowercase letters, digits, - and _, starting with a letter." >&2
  exit 1
fi

for f in "$OPTIONS_FILE" "$INSTALL_FILE"; do
  if [[ ! -f "$f" ]]; then
    echo "Error: $f not found" >&2
    exit 1
  fi
done

# escape a value for use inside a Nix "double quoted" string
nix_str() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//\$\{/\\\$\{}"
  printf '"%s"' "$s"
}

TMP_FILE="$(mktemp)"
trap 'rm -f "$TMP_FILE"' EXIT

# --- rewrite options.nix ---
# name and email get the given values, sshHosts is emptied, and the keys
# and password lines are dropped. comments and everything outside the user
# block are left as they are, except server.domain. The values go through the environment so awk
# doesn't eat their backslashes.

NAME_LINE="    name = $(nix_str "$NAME");" \
EMAIL_LINE="    email = $(nix_str "$EMAIL");" \
awk '
  BEGIN {
    name_line = ENVIRON["NAME_LINE"]
    email_line = ENVIRON["EMAIL_LINE"]
  }
  !in_user && ssh_skipping { if (/\];[ \t]*$/) ssh_skipping = 0; next }
  !in_user && /^  sshHosts = / {
    print "  sshHosts = [];"
    if ($0 !~ /\];[ \t]*$/) ssh_skipping = 1
    seen_ssh = 1
    next
  }
  /^  server = \{/ { in_server = 1; print; next }
  in_server && /^  \};/ { in_server = 0; print; next }
  in_server && /^    lanIp = / {
    print "    lanIp = \"192.168.1.100\";"
    seen_lan_ip = 1
    next
  }
  in_server && /^    domain = / {
    print "    domain = \"my_domain.com\";"
    seen_domain = 1
    next
  }
  /^  user = \{/ { in_user = 1; print; next }
  in_user && /^  \};/ { in_user = 0; print; next }
  in_user && skipping { if (/^    \];/) skipping = 0; next }
  in_user && /^    name = / { print name_line; seen_name = 1; next }
  in_user && /^    email = / { print email_line; seen_email = 1; next }
  in_user && /^[[:space:]]*hashedPassword(File)?[[:space:]]*=/ { next }
  in_user && /^    keys = \[/ {
    print "    keys = [];"
    if ($0 !~ /\];[ \t]*$/) skipping = 1
    seen_keys = 1
    next
  }
  { print }
  END { if (!(seen_ssh && seen_domain && seen_lan_ip && seen_name && seen_email && seen_keys)) exit 1 }
' "$OPTIONS_FILE" >"$TMP_FILE" || {
  echo "Error: couldn't find sshHosts, server.domain, server.lanIp, or name, email and keys in the 'user = { ... };' block, in $OPTIONS_FILE" >&2
  exit 1
}

cat "$TMP_FILE" >"$OPTIONS_FILE"

echo "==> Scrubbed $OPTIONS_FILE:"
sed -n '/^  sshHosts = /p;/^  server = {/,/^  };/p;/^  user = {/,/^  };/p' "$OPTIONS_FILE"

# --- point install.sh at the public mirror ---

REPO_LINE="REPO_URL=\"$MIRROR_URL\"" \
awk '
  BEGIN { repo_line = ENVIRON["REPO_LINE"] }
  !seen && /^REPO_URL=/ { print repo_line; seen = 1; next }
  { print }
  END { if (!seen) exit 1 }
' "$INSTALL_FILE" >"$TMP_FILE" || {
  echo "Error: couldn't find the REPO_URL line in $INSTALL_FILE" >&2
  exit 1
}

cat "$TMP_FILE" >"$INSTALL_FILE"

echo "==> Set the repo url in $INSTALL_FILE:"
grep -m1 '^REPO_URL=' "$INSTALL_FILE"
