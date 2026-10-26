#!/usr/bin/env bash
# install.sh — install NixOS from this flake onto a fresh drive, from the NixOS minimal install ISO
#
# Asks for your user info, wipes the chosen drive and sets it up as described in install.md:
#   p1  2G    EFI System, vfat, label NixOS-Boot                -> /mnt/boot
#   p2  rest  optionally LUKS2, label NixOS-Encrypted, opened as cryptroot
#             └─ LVM volume group lvmroot
#                ├─ swap  (optional) label NixOS-Swap             -> swapon
#                └─ root  ext4 | btrfs | xfs, label NixOS-Root     -> /mnt
# then clones the repo to /mnt/home/<user>/nixos, writes your user info into its options.nix, generates the
# hardware-configuration.nix for every host with optional LUKS unlock, runs nixos-install and sets your password.
#
# Usage (on the ISO, after connecting to the internet):
#   sudo su
#   bash <(curl -sL https://raw.githubusercontent.com/lehtlau/nixos/main/scripts/install.sh)
#
# Flags:
#   --name <user> --email <email>     skip the username and email prompts
#   --ssh | --no-ssh                  run an ssh server on the installed host, or not, without asking
#   --key "<ssh public key>"          allow this key to log in (implies --ssh)
#   --keep-keys                       don't ask for keys, leave the ones in options.nix alone
#   --host <host>                     install this host instead of asking
#   --branch <branch>                 clone another branch
#   --partition-only                  stop after partitioning, cloning and writing the user info
#   --do-not-partition                skip partitioning, continue on an already prepared /mnt
#   --plain                           use plain terminal prompts instead of the TUI
#   --preview                         preview the interface without installing anything
#
# Use --do-not-partition to continue with an existing mounted installation.
#
# Each flag skips its own prompt, so --name --email --host and --ssh|--no-ssh (plus --key
# or --keep-keys) leaves only the disk setup to answer.

set -euo pipefail

REPO_URL="https://github.com/lehtlau/nixos"
BRANCH="main"

BOOT_LABEL="NixOS-Boot"
LUKS_LABEL="NixOS-Encrypted"
ROOT_LABEL="NixOS-Root"
SWAP_LABEL="NixOS-Swap"
CRYPT_NAME="cryptroot"
VG_NAME="lvmroot"
BOOT_SIZE="2GiB"

NAME=""
EMAIL=""
KEYS=()
KEEP_KEYS="false"
ENABLE_SSH=""
HOST=""
USER_PASS=""
PARTITION_ONLY="false"
DO_NOT_PARTITION="false"
ENABLE_ENCRYPTION="false"
STAGING_DIR=""
PLAIN="false"
PREVIEW="false"
TUI="false"
INSTALL_LOG=""
UI_WIDTH=68
UI_HEIGHT=24
UI_ACCENT="#89b4fa"
UI_MUTED="#9399b2"
UI_TEXT="#cdd6f4"
UI_DANGER="#f38ba8"

cleanup() {
  [[ -z "$STAGING_DIR" ]] || rm -rf -- "$STAGING_DIR"
}
trap cleanup EXIT

# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------

usage() {
  cat <<'EOF'
Install NixOS from this flake onto a fresh drive (run from the NixOS install ISO as root).

  bash <(curl -sL https://raw.githubusercontent.com/<github_user>/nixos/main/scripts/install.sh) [flags]

Flags:
  --name <user> --email <email>     skip the username and email prompts
  --ssh | --no-ssh                  run an ssh server on the installed host, or not, without being asked
  --key "<ssh public key>"          allow connecting with this key (implies --ssh)
  --keep-keys                       don't ask for keys, leave the ones already in options.nix alone
  --host <host>                     install this host instead of asking
  --branch <branch>                 clone another branch
  --partition-only                  stop after partitioning, cloning and writing the user info 
  --do-not-partition                skip partitioning, continue on an already prepared /mnt - use partition-only to create partition and clone the repo after which make changes to a host and continue to install with this flag
  --plain                           use plain terminal prompts instead of the TUI
  --preview                         preview the interface without root or disk changes

Use --do-not-partition to continue with an existing installation mounted at /mnt.
EOF
  exit "${1:-0}"
}

die() {
  if [[ "$TUI" == "true" ]]; then
    gum style --foreground "$UI_DANGER" --bold --padding "1 2" "Installation stopped" >&2
    gum style --foreground "$UI_TEXT" --width "$UI_WIDTH" --padding "0 2" "$*" >&2
    [[ -z "$INSTALL_LOG" ]] || note "Log: $INSTALL_LOG" >&2
  else
    echo "Error: $*" >&2
  fi
  exit 1
}

step() {
  if [[ "$TUI" == "true" ]]; then
    gum style --foreground "$UI_ACCENT" --padding "0 2" "› $*"
  else
    echo
    echo "==> $*"
  fi
}

run() {
  if [[ "$TUI" == "true" ]]; then
    printf '+ %s\n' "$*" >>"$INSTALL_LOG"
    if "$@" >>"$INSTALL_LOG" 2>&1; then
      return 0
    else
      tail -n 15 "$INSTALL_LOG" >&2
      die "The operation failed. See the log above for details."
    fi
  else
    echo "+ $*"
    "$@"
  fi
}

# Keep long-running work visible, with full output available in the log.
run_long() {
  local title="$1"
  shift
  if [[ "$TUI" == "true" ]]; then
    # The child shell expands its own arguments and the exported log path.
    # shellcheck disable=SC2016
    if gum spin --spinner dot --title "$title" --show-output -- \
      bash -o pipefail -c '"$@" 2>&1 | tee -a "$INSTALL_LOG"' _ "$@"; then
      return 0
    else
      tail -n 15 "$INSTALL_LOG" >&2
      die "$title failed. See $INSTALL_LOG for details."
    fi
  else
    run "$@"
  fi
}

note() {
  if [[ "$TUI" == "true" ]]; then
    gum style --foreground "$UI_MUTED" --width "$UI_WIDTH" --padding "0 2" "$*"
  else
    printf '%s\n' "$*"
  fi
}

init_ui() {
  [[ "$PLAIN" == "false" && -t 0 && -t 1 && "${TERM:-dumb}" != "dumb" ]] || return 0
  INSTALL_LOG="$(mktemp "${TMPDIR:-/tmp}/nixos-install.XXXXXX.log")"
  export INSTALL_LOG
  if ! command -v gum >/dev/null; then
    # The NixOS minimal ISO needs Gum fetched once. Failure leaves plain prompts usable.
    local gum_path
    printf 'Preparing the installer interface…\n'
    if command -v nix-build >/dev/null &&
      gum_path="$(nix-build '<nixpkgs>' -A gum --no-out-link 2>>"$INSTALL_LOG")"; then
      PATH="$gum_path/bin:$PATH"
      export PATH
    else
      printf 'Using plain terminal prompts.\n'
      return 0
    fi
  fi
  TUI="true"
  local columns
  columns="$(tput cols 2>/dev/null || printf '80')"
  UI_HEIGHT="$(tput lines 2>/dev/null || printf '24')"
  [[ "$UI_HEIGHT" =~ ^[0-9]+$ ]] || UI_HEIGHT=24
  [[ "$columns" =~ ^[0-9]+$ ]] || columns=80
  UI_WIDTH=$((columns - 8))
  [[ "$UI_WIDTH" -le 68 ]] || UI_WIDTH=68
  if [[ "$UI_WIDTH" -lt 32 ]]; then
    TUI="false"
    return 0
  fi
  export GUM_INPUT_CURSOR_FOREGROUND="$UI_ACCENT"
  export GUM_INPUT_PROMPT_FOREGROUND="$UI_ACCENT"
  export GUM_INPUT_HEADER_FOREGROUND="$UI_TEXT"
  export GUM_INPUT_PADDING="0 2"
  export GUM_CHOOSE_CURSOR_FOREGROUND="$UI_ACCENT"
  export GUM_CHOOSE_SELECTED_FOREGROUND="$UI_ACCENT"
  export GUM_CHOOSE_HEADER_FOREGROUND="$UI_TEXT"
  export GUM_CHOOSE_PADDING="0 2"
  export GUM_SPIN_SPINNER_FOREGROUND="$UI_ACCENT"
  export GUM_SPIN_TITLE_FOREGROUND="$UI_TEXT"
  export GUM_SPIN_PADDING="0 2"
}

screen() {
  local number="$1" title="$2" description="$3" i navigation=""
  if [[ "$TUI" == "true" ]]; then
    printf '\033[2J\033[H'
    if [[ "$UI_WIDTH" -ge 56 && "$UI_HEIGHT" -ge 32 ]]; then
      gum style --foreground "$UI_ACCENT" --bold --padding "0 2" \
        '██╗     ██╗       ███╗   ██╗██╗██╗  ██╗ ██████╗ ███████╗' \
        '██║     ██║       ████╗  ██║██║╚██╗██╔╝██╔═══██╗██╔════╝' \
        '██║     ██║       ██╔██╗ ██║██║ ╚███╔╝ ██║   ██║███████╗' \
        '██║     ██║       ██║╚██╗██║██║ ██╔██╗ ██║   ██║╚════██║' \
        '███████╗███████╗  ██║ ╚████║██║██╔╝ ██╗╚██████╔╝███████║' \
        '╚══════╝╚══════╝  ╚═╝  ╚═══╝╚═╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝'
      gum style --foreground "$UI_MUTED" --padding "0 2" 'LL NIXOS installer'
    else
      gum style --foreground "$UI_ACCENT" --bold --padding "0 2" 'LL NIXOS installer'
    fi
    for i in 1 2 3 4 5; do
      if [[ "$i" == "$number" ]]; then
        navigation+="[$i] "
      elif [[ "$i" -lt "$number" ]]; then
        navigation+=" ✓  "
      else
        navigation+=" $i  "
      fi
    done
    gum style --foreground "$UI_MUTED" --padding "1 2 0 2" \
      "${navigation}  $number / 5" 'Account / Host / Storage / Review / Install'
    gum style --foreground "$UI_TEXT" --bold --padding "0 2" "$title"
    note "$description"
    printf '\n'
  else
    step "$title"
    note "$description"
  fi
}

# ui_input <label> <result variable> <placeholder> [default] [secret]
# Cancellation always aborts; it must never be interpreted as an empty/default answer.
ui_input() {
  local label="$1" result_var="$2" placeholder="$3" initial="${4:-}" secret="${5:-false}" response
  if [[ "$TUI" == "true" ]]; then
    local args=(--header "$label" --placeholder "$placeholder" --value "$initial"
      --char-limit 0 --width "$UI_WIDTH" --prompt '› ')
    [[ "$secret" == "false" ]] || args+=(--password)
    response="$(gum input "${args[@]}")" || die "Cancelled."
  else
    local prompt="$label"
    [[ -z "$initial" ]] || prompt+=" [$initial]"
    if [[ "$secret" == "true" ]]; then
      read -rsp "$prompt: " response || die "Cancelled."
      echo
    else
      read -rp "$prompt: " response || die "Cancelled."
    fi
    response="${response:-$initial}"
  fi
  printf -v "$result_var" '%s' "$response"
}

require_commands() {
  local command missing=()
  for command in "$@"; do
    command -v "$command" >/dev/null || missing+=("$command")
  done
  [[ ${#missing[@]} -eq 0 ]] ||
    die "missing required commands: ${missing[*]}. Boot the NixOS installer ISO with the required tools."
}

# pick one item from a list: pick <prompt> <result var> <items...>
pick() {
  local prompt="$1" var="$2" choice
  shift 2
  if [[ "$TUI" == "true" ]]; then
    choice="$(gum choose --header "$prompt" --cursor '› ' --height 8 -- "$@")" || die "Cancelled."
    [[ -n "$choice" ]] || die "No selection made."
    printf -v "$var" '%s' "$choice"
    return 0
  fi
  PS3="$prompt> "
  select choice in "$@"; do
    [[ -n "$choice" ]] && break
    echo "Invalid choice, enter a number from the list."
  done
  [[ -n "$choice" ]] || die "Cancelled."
  printf -v "$var" '%s' "$choice"
}

# yes/no prompt: ask_yes_no <prompt> <result var> <default y|n>
ask_yes_no() {
  local prompt="$1" var="$2" default="$3" answer
  if [[ "$TUI" == "true" ]]; then
    local choices=(Yes No)
    [[ "$default" == "y" ]] || choices=(No Yes)
    answer="$(gum choose --header "$prompt" --cursor '› ' --height 2 -- "${choices[@]}")" || die "Cancelled."
    case "$answer" in
      Yes) printf -v "$var" 'true' ;;
      No) printf -v "$var" 'false' ;;
      *) die "No selection made." ;;
    esac
    return 0
  fi
  local suffix="[y/N]"
  [[ "$default" == "n" ]] || suffix="[Y/n]"
  while true; do
    read -rp "$prompt $suffix " answer || die "Cancelled."
    case "${answer:-$default}" in
      [yY] | [yY]es) printf -v "$var" 'true'; return 0 ;;
      [nN] | [nN]o) printf -v "$var" 'false'; return 0 ;;
      *) echo "Answer y or n." ;;
    esac
  done
}

# escape a value for use inside a Nix "double quoted" string
nix_str() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//\$\{/\\\$\{}"
  printf '"%s"' "$s"
}

# ---------------------------------------------------------------------------
# steps
# ---------------------------------------------------------------------------

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      # each flag skips its own prompt, pass them all for an unattended run
      --name) NAME="${2:?--name needs a value}"; shift 2 ;;
      --email) EMAIL="${2:?--email needs a value}"; shift 2 ;;
      --key) KEYS+=("${2:?--key needs a value}"); shift 2 ;;
      --keep-keys) KEEP_KEYS="true"; shift ;;
      --ssh) ENABLE_SSH="true"; shift ;;
      --no-ssh) ENABLE_SSH="false"; shift ;;
      --host) HOST="${2:?--host needs a value}"; shift 2 ;;
      --branch) BRANCH="${2:?--branch needs a value}"; shift 2 ;;
      --partition-only) PARTITION_ONLY="true"; shift ;;
      --do-not-partition) DO_NOT_PARTITION="true"; shift ;;
      --plain) PLAIN="true"; shift ;;
      --preview) PREVIEW="true"; shift ;;
      -h | --help) usage ;;
      *) echo "Unknown argument: $1" >&2; usage 1 ;;
    esac
  done

  [[ "$PARTITION_ONLY" == "true" && "$DO_NOT_PARTITION" == "true" ]] &&
    die "--partition-only and --do-not-partition are mutually exclusive"

  # keys only make sense with the ssh server on
  if [[ ${#KEYS[@]} -gt 0 ]]; then
    [[ "$ENABLE_SSH" == "false" ]] && die "--no-ssh and --key are mutually exclusive"
    [[ "$KEEP_KEYS" == "true" ]] && die "--keep-keys and --key are mutually exclusive"
    ENABLE_SSH="true"
  fi

  return 0
}

preflight() {
  [[ $EUID -eq 0 ]] || die "run as root (sudo su)"
  [[ -d /sys/firmware/efi ]] || die "not booted in UEFI mode, the flake uses grub with efiSupport"
  require_commands curl nix nix-instantiate nixos-generate-config nixos-install nixos-enter \
    lsblk blkid findmnt mountpoint swapon ip hostname awk grep sed mktemp cat cp mv mkdir rm tail tee
  if [[ "$DO_NOT_PARTITION" == "false" ]] && mountpoint -q /mnt; then
    die "/mnt is already mounted. To unmount it before reinstalling, run:
  cd / && umount -R /mnt
Then rerun the installer. To keep the existing partitions and configuration, rerun with --do-not-partition instead."
  fi
  if [[ "$DO_NOT_PARTITION" == "false" ]]; then
    require_commands wipefs parted partprobe udevadm mkfs.fat pvcreate vgcreate \
      vgs pvs vgchange vgremove lvcreate mount umount mkswap swapon swapoff
  fi

  # Keep successful connection checks silent.
  curl -sfI --max-time 10 https://github.com >/dev/null ||
    die "can't reach github.com, connect first (nmtui or: nmcli device wifi connect \"<SSID>\" password \"<PASSWORD>\")"

  # the minimal ISO doesn't ship git, pull it in once
  if ! command -v git >/dev/null; then
    step "Fetching git"
    require_commands nix-build
    PATH="$(nix-build '<nixpkgs>' -A git --no-out-link)/bin:$PATH"
    export PATH
  fi

  git ls-remote --exit-code --heads "$REPO_URL" "$BRANCH" >/dev/null ||
    die "can't read branch '$BRANCH' of $REPO_URL (private repo? wrong url?)"
}

ask_username() {
  local account account_name _password uid _rest
  while true; do
    if [[ "$NAME" =~ ^[a-z_][a-z0-9_-]*$ && ${#NAME} -le 32 &&
          ! "$NAME" =~ ^(root|nobody|nixbld[0-9]*|nixbld|systemd-.*)$ ]]; then
      account="false"
      while IFS=: read -r account_name _password uid _rest; do
        if [[ "$account_name" == "$NAME" && "$uid" -lt 1000 ]]; then
          account="true"
          break
        fi
      done </etc/passwd
      [[ "$account" == "true" ]] || return 0
    fi
    [[ -z "$NAME" ]] || note "Invalid or reserved username '$NAME'. Use up to 32 lowercase letters, digits, - or _, starting with a letter or _."
    ui_input "Username" NAME "e.g. user1"
  done
}

ask_user_info() {
  screen 1 "Make yourself at home" "Your account, Git identity, and remote access."
  ask_username

  while [[ -z "$EMAIL" ]]; do
    ui_input "Email for Git" EMAIL "you@example.com"
  done

  # no ssh server means nothing would ever read the keys, so don't ask for them
  if [[ -z "$ENABLE_SSH" ]]; then
    ask_yes_no "Allow remote access over SSH?" ENABLE_SSH n
  fi

  if [[ "$ENABLE_SSH" == "true" && ${#KEYS[@]} -eq 0 && "$KEEP_KEYS" == "false" ]]; then
    note "Add SSH public keys one at a time. Leave empty to finish."
    note "Without keys, SSH will use your account password."
    local key
    while true; do
      ui_input "SSH public key (optional)" key "ssh-ed25519 …"
      [[ -n "$key" ]] || break
      if [[ "$key" =~ ^(ssh-|ecdsa-|sk-) ]]; then
        KEYS+=("$key")
      else
        note "Doesn't look like an SSH public key, skipped."
      fi
    done
  fi

  local key
  for key in "${KEYS[@]}"; do
    [[ "$key" =~ ^(ssh-|ecdsa-|sk-) ]] || die "doesn't look like an ssh public key: $key"
  done
}

# Exclude entire disks with mounted descendants (including the live ISO's USB
# filesystem or a Ventoy backing partition). ISO9660 also catches hybrid install
# media when it is unmounted, e.g. after copying the live image into RAM.
disk_is_available() {
  local mountpoints filesystems
  mountpoints="$(lsblk -nrpo MOUNTPOINTS "$1")" || return 1
  # Unmounting filesystems does not stop swap from an interrupted installation.
  # Release it only after the user confirms erasing this disk.
  mountpoints="${mountpoints//\[SWAP\]/}"
  [[ ! "$mountpoints" =~ [^[:space:]] ]] || return 1
  filesystems="$(lsblk -nrpo FSTYPE "$1")" || return 1
  if grep -Eq '^[[:space:]]*iso9660[[:space:]]*$' <<<"$filesystems"; then
    return 1
  fi
}

ask_disk() {
  screen 3 "Choose your storage" "Select a drive, filesystem, and encryption."

  local drives=() name type
  while read -r name _ type; do
    if [[ "$type" == "disk" ]] && disk_is_available "$name"; then
      drives+=("$name")
    fi
  done < <(lsblk -dpno NAME,SIZE,TYPE)
  [[ ${#drives[@]} -gt 0 ]] || die "no available installation drives found; mounted drives and installation media are excluded"

  if [[ "$TUI" == "true" ]]; then
    local drive_choices=() drive_details
    for name in "${drives[@]}"; do
      drive_details="$(lsblk -dn -o SIZE,MODEL "$name")"
      drive_choices+=("$name  $drive_details")
    done
    note "Everything on the selected drive will be erased after confirmation."
    local selected_drive
    pick "Installation drive" selected_drive "${drive_choices[@]}"
    DRIVE="${selected_drive%% *}"
  else
    lsblk -o NAME,SIZE,TYPE,FSTYPE,LABEL,MOUNTPOINT,MODEL "${drives[@]}"
    echo
    echo "Select the drive to install NixOS on (EVERYTHING ON IT WILL BE ERASED):"
    pick drive DRIVE "${drives[@]}"
  fi

  disk_is_available "$DRIVE" || die "$DRIVE is in use or contains installation media; choose another drive"

  # nvme0n1 / mmcblk0 -> nvme0n1p1, sda -> sda1
  if [[ "$DRIVE" =~ [0-9]$ ]]; then
    BOOT_PART="${DRIVE}p1"
    LUKS_PART="${DRIVE}p2"
  else
    BOOT_PART="${DRIVE}1"
    LUKS_PART="${DRIVE}2"
  fi

  if [[ "$TUI" == "true" ]]; then
    local filesystem_choice
    pick "Root filesystem" filesystem_choice "btrfs  · Recommended · Compressed subvolumes" "ext4   · Simple and reliable"
    FS="${filesystem_choice%% *}"
  else
    echo "Select the root filesystem (btrfs recommended):"
    pick filesystem FS btrfs ext4
  fi
  case "$FS" in
    ext4) require_commands mkfs.ext4 ;;
    btrfs) require_commands mkfs.btrfs btrfs ;;
    *) die "no root filesystem selected" ;;
  esac

  # Leave 2 GiB for EFI, 1 GiB for alignment/LUKS/LVM overhead, and at
  # least 16 GiB for root. Reject impossible layouts before wiping anything.
  local disk_bytes max_swap_gb
  disk_bytes="$(lsblk -bdno SIZE "$DRIVE")"
  [[ "$disk_bytes" =~ ^[0-9]+$ ]] || die "couldn't read the size of $DRIVE"
  max_swap_gb=$((disk_bytes / 1073741824 - 2 - 1 - 16))
  [[ "$max_swap_gb" -ge 0 ]] || die "$DRIVE is too small: at least 19 GiB is required"
  local default_swap=8
  [[ "$max_swap_gb" -ge 8 ]] || default_swap=0

  while true; do
    ui_input "Swap size in GiB (0 for no swap)" SWAP_GB "$default_swap" "$default_swap"
    SWAP_GB="${SWAP_GB:-$default_swap}"
    if [[ "$SWAP_GB" =~ ^[0-9]+$ ]]; then
      SWAP_GB="${SWAP_GB#"${SWAP_GB%%[!0]*}"}"
      SWAP_GB="${SWAP_GB:-0}"
      if [[ ${#SWAP_GB} -le 9 ]] && [[ "$SWAP_GB" -le "$max_swap_gb" ]]; then
        break
      fi
    fi
    note "Enter a non-negative whole number that leaves enough disk space for the system."
  done

  ask_yes_no "Use full disk encryption? (recommended)" ENABLE_ENCRYPTION y
  [[ "$ENABLE_ENCRYPTION" == "true" ]] || return 0
  require_commands cryptsetup

  local again
  while true; do
    ui_input "Disk encryption password" LUKS_PASS "Enter a strong passphrase" "" true
    ui_input "Repeat encryption password" again "Confirm your passphrase" "" true
    if [[ -z "$LUKS_PASS" ]]; then
      note "Password can't be empty."
    elif [[ "$LUKS_PASS" != "$again" ]]; then
      note "Passwords don't match."
    else
      break
    fi
  done
}

show_summary() {
  if [[ "$TUI" == "true" ]]; then
    local encryption="Off" remote_access="Disabled" swap="None" authentication=""
    local summary_key_count="${#KEYS[@]}"
    [[ "$ENABLE_ENCRYPTION" == "false" ]] || encryption="LUKS2 · enabled"
    [[ "$SWAP_GB" == "0" ]] || swap="${SWAP_GB} GiB"
    if [[ "$ENABLE_SSH" == "true" ]]; then
      if [[ "$KEEP_KEYS" == "true" ]]; then
        summary_key_count="$(nix-instantiate --eval --strict \
          --expr '{ optionsFile }: builtins.length ((import (builtins.toPath optionsFile)).user.keys or [])' \
          --argstr optionsFile "$REPO_DIR/options.nix")"
      fi
      if [[ "$summary_key_count" -gt 0 ]]; then
        authentication="$summary_key_count SSH key(s)"
      else
        authentication="Account password"
      fi
      remote_access="Enabled · $authentication"
    fi
    gum style --border rounded --border-foreground "$UI_ACCENT" \
      --foreground "$UI_TEXT" --padding "0 2" --margin "0 2" --width "$((UI_WIDTH - 4))" \
      "Host          $HOST" \
      "Account       $NAME" \
      "Email         $EMAIL" \
      "Drive         $DRIVE" \
      "Filesystem    $FS" \
      "Encryption    $encryption" \
      "Swap          $swap" \
      "SSH           $remote_access"
    printf '\n'
    return 0
  fi
  echo "    host       $HOST"
  echo "    wipe       $DRIVE"
  echo "    boot       $BOOT_PART  $BOOT_SIZE vfat ($BOOT_LABEL)"
  if [[ "$ENABLE_ENCRYPTION" == "true" ]]; then
    echo "    encrypted  $LUKS_PART  LUKS2 ($LUKS_LABEL) -> /dev/mapper/$CRYPT_NAME -> LVM $VG_NAME"
  else
    echo "    unencrypted $LUKS_PART -> LVM $VG_NAME"
  fi
  [[ "$SWAP_GB" -gt 0 ]] && echo "    swap       ${SWAP_GB}G ($SWAP_LABEL)"
  echo "    root       rest of the disk, $FS ($ROOT_LABEL)"
  echo "    clone      $REPO_URL ($BRANCH) -> /mnt/home/$NAME/nixos"
  echo "    user       $NAME <$EMAIL>"
  if [[ "$ENABLE_SSH" == "true" ]]; then
    if [[ "$KEEP_KEYS" == "true" ]]; then
      echo "    ssh        server enabled, keeping the keys already in options.nix"
    else
      echo "    ssh        server enabled, ${#KEYS[@]} key(s) allowed"
    fi
  else
    echo "    ssh        server disabled"
  fi
}

confirm() {
  screen 4 "Ready to install" "Review your choices before making changes to the drive."
  show_summary
  if [[ "$TUI" == "true" ]]; then
    gum style --foreground "$UI_DANGER" --bold --padding "0 2" "ALL DATA ON $DRIVE WILL BE ERASED."
    note "Type the complete drive path below to confirm."
  fi
  echo
  local answer
  # A placeholder is only a hint: never prefill the destructive confirmation.
  while true; do
    ui_input "Type the drive path ($DRIVE) to confirm" answer "$DRIVE"
    [[ "$answer" == "$DRIVE" ]] && return 0
    note "Drive path does not match. Enter $DRIVE, or press Ctrl+C to cancel."
  done
}

device_is_on_install_drive() {
  local disks disk found=false
  disks="$(lsblk -snrpo NAME,TYPE "$1")" || return 1
  while read -r disk; do
    [[ -n "$disk" ]] || continue
    [[ "$disk" == "$DRIVE" ]] || return 1
    found=true
  done < <(awk '$2 == "disk" { print $1 }' <<<"$disks")
  [[ "$found" == true ]]
}

# Only called after the user confirms erasing DRIVE. Existing, unused storage
# on that drive may be replaced; never remove a same-named VG on another drive.
prepare_existing_storage() {
  local groups volumes volume swaps device existing_group=false
  local old_swap=()
  groups="$(vgs --noheadings -o vg_name)" || die "couldn't inspect existing volume groups"
  if grep -Eq "^[[:space:]]*${VG_NAME}[[:space:]]*$" <<<"$groups"; then
    existing_group=true
    volumes="$(pvs --noheadings -o pv_name --select "vg_name=$VG_NAME")" || die "couldn't inspect $VG_NAME"
    [[ -n "${volumes//[[:space:]]/}" ]] || die "couldn't find the physical volumes for $VG_NAME"
    while read -r volume; do
      [[ -n "$volume" ]] || continue
      device_is_on_install_drive "$volume" ||
        die "$VG_NAME uses storage outside $DRIVE; refusing to remove it"
    done <<<"$volumes"
  fi
  if [[ -e "/dev/mapper/$CRYPT_NAME" ]]; then
    require_commands cryptsetup
    device_is_on_install_drive "/dev/mapper/$CRYPT_NAME" ||
      die "/dev/mapper/$CRYPT_NAME belongs to another drive; refusing to close it"
  fi
  swaps="$(swapon --show=NAME --noheadings --raw)" || die "couldn't inspect active swap"
  while read -r device; do
    [[ -n "$device" ]] || continue
    if device_is_on_install_drive "$device"; then
      old_swap+=("$device")
    fi
  done <<<"$swaps"
  for device in "${old_swap[@]}"; do
    run swapoff "$device"
  done
  if [[ "$existing_group" == true ]]; then
    run vgchange --activate n "$VG_NAME"
    run vgremove --yes "$VG_NAME"
  fi
  if [[ -e "/dev/mapper/$CRYPT_NAME" ]]; then
    run cryptsetup close "$CRYPT_NAME"
  fi
}

partition() {
  # Recheck immediately before the first destructive command.
  disk_is_available "$DRIVE" || die "$DRIVE is in use or contains installation media; refusing to erase it"
  prepare_existing_storage
  step "Partitioning $DRIVE"
  run wipefs --all --force "$DRIVE"
  run parted --script "$DRIVE" \
    mklabel gpt \
    mkpart ESP fat32 1MiB "$BOOT_SIZE" \
    set 1 esp on \
    mkpart NixOS "$BOOT_SIZE" 100%
  run partprobe "$DRIVE"
  run udevadm settle

  step "Formatting boot partition"
  run mkfs.fat -F 32 -n "$BOOT_LABEL" "$BOOT_PART"

  local pv_device="$LUKS_PART"
  if [[ "$ENABLE_ENCRYPTION" == "true" ]]; then
    step "Setting up LUKS"
    printf '%s' "$LUKS_PASS" | run cryptsetup luksFormat --batch-mode --type luks2 --label="$LUKS_LABEL" --key-file=- "$LUKS_PART"
    printf '%s' "$LUKS_PASS" | run cryptsetup open --key-file=- "$LUKS_PART" "$CRYPT_NAME"
    unset LUKS_PASS
    pv_device="/dev/mapper/$CRYPT_NAME"
  fi

  step "Setting up LVM"
  # The exact-drive confirmation already authorized replacing old signatures.
  # Avoid a second, hidden prompt while command output goes to the TUI log.
  run pvcreate --yes "$pv_device"
  run vgcreate "$VG_NAME" "$pv_device"
  [[ "$SWAP_GB" -gt 0 ]] && run lvcreate --yes --size "${SWAP_GB}G" --name swap "$VG_NAME"
  run lvcreate --yes --extents 100%FREE --name root "$VG_NAME"

  local root_lv="/dev/mapper/$VG_NAME-root" swap_lv="/dev/mapper/$VG_NAME-swap"

  step "Formatting root as $FS"
  case "$FS" in
    ext4) run mkfs.ext4 -F -L "$ROOT_LABEL" "$root_lv" ;;
    xfs) run mkfs.xfs -f -L "$ROOT_LABEL" "$root_lv" ;;
    btrfs) run mkfs.btrfs -f -L "$ROOT_LABEL" "$root_lv" ;;
  esac
  [[ "$SWAP_GB" -gt 0 ]] && run mkswap -L "$SWAP_LABEL" "$swap_lv"
  run udevadm settle

  step "Mounting"
  if [[ "$FS" == "btrfs" ]]; then
    local opts="compress=zstd,noatime"
    run mount "$root_lv" /mnt
    run btrfs subvolume create /mnt/@
    run btrfs subvolume create /mnt/@home
    run btrfs subvolume create /mnt/@nix
    run umount /mnt
    run mount -o "subvol=@,$opts" "$root_lv" /mnt
    run mkdir -p /mnt/home /mnt/nix
    run mount -o "subvol=@home,$opts" "$root_lv" /mnt/home
    run mount -o "subvol=@nix,$opts" "$root_lv" /mnt/nix
  else
    run mount "$root_lv" /mnt
  fi
  run mkdir -p /mnt/boot
  run mount -o umask=077 "$BOOT_PART" /mnt/boot
  [[ "$SWAP_GB" -gt 0 ]] && run swapon "$swap_lv"
  return 0
}

prepare_repo() {
  STAGING_DIR="$(mktemp -d)"
  REPO_DIR="$STAGING_DIR/nixos"
  step "Cloning $REPO_URL for validation before partitioning"
  run_long "Preparing the configuration" git clone --depth 1 --branch "$BRANCH" "$REPO_URL" "$REPO_DIR"
}

clone_repo() {
  local target="/mnt/home/$NAME/nixos"
  step "Placing the validated repository in $target"
  mkdir -p "$(dirname "$target")"
  mv "$REPO_DIR" "$target"
  REPO_DIR="$target"
}

# Resume keeps the previously saved identity, but explicit keys replace its key list.
write_resume_keys() {
  [[ ${#KEYS[@]} -gt 0 ]] || return 0
  local options_file="$REPO_DIR/options.nix" keys_file tmp key
  keys_file="$(mktemp)"
  tmp="$(mktemp)"
  {
    echo "    keys = ["
    for key in "${KEYS[@]}"; do
      [[ "$key" =~ ^(ssh-|ecdsa-|sk-) ]] || die "doesn't look like an ssh public key: $key"
      echo "      $(nix_str "$key")"
    done
    echo "    ];"
  } >"$keys_file"
  KEYS_FILE="$keys_file" awk '
    /^  user = \{/ { in_user = 1 }
    in_user && /^  \};/ { in_user = 0 }
    in_user && skipping { if (/^    \];/) skipping = 0; next }
    in_user && /^    keys = \[/ {
      while ((getline line < ENVIRON["KEYS_FILE"]) > 0) print line
      if ($0 !~ /\];[ \t]*$/) skipping = 1
      seen = 1
      next
    }
    { print }
    END { if (!seen) exit 1 }
  ' "$options_file" >"$tmp" || die "couldn't update SSH keys in $options_file"
  cat "$tmp" >"$options_file"
  rm -f "$keys_file" "$tmp"
}

# Capture the first address exactly as reported by the installation environment.
# Resume keeps the saved address instead of replacing manually edited settings.
write_lan_ip() {
  local options_file="$REPO_DIR/options.nix" addresses lan_ip tmp
  addresses="$(hostname -I)" || die "couldn't detect the LAN IP with hostname -I"
  lan_ip="$(awk '{ for (i = 1; i <= NF; i++) { print $i; exit } }' <<<"$addresses")"
  [[ -n "$lan_ip" ]] || die "hostname -I returned no address; connect to the network before installing"
  tmp="$(mktemp)"
  LAN_IP_LINE="    lanIp = $(nix_str "$lan_ip");" \
  awk '
    /^  server = \{/ { in_server = 1 }
    in_server && /^  \};/ { in_server = 0 }
    in_server && /^    lanIp = / { print ENVIRON["LAN_IP_LINE"]; seen = 1; next }
    { print }
    END { if (!seen) exit 1 }
  ' "$options_file" >"$tmp" || die "couldn't find server.lanIp in $options_file"
  cat "$tmp" >"$options_file"
  rm -f "$tmp"
  step "Set server.lanIp to $lan_ip in $options_file"
}

# the user info lives in options.nix at the repo root, see modules/system/users
write_user_info() {
  local options_file="$REPO_DIR/options.nix"
  [[ -f "$options_file" ]] || die "$options_file not found in the cloned repo"

  # --keep-keys: no keys file, so the awk below leaves the list in place
  local keys="" tmp key
  tmp="$(mktemp)"
  if [[ "$KEEP_KEYS" == "false" ]]; then
    keys="$(mktemp)"
    {
      if [[ ${#KEYS[@]} -eq 0 ]]; then
        echo "    keys = [];"
      else
        echo "    keys = ["
        for key in "${KEYS[@]}"; do
          echo "      $(nix_str "$key")"
        done
        echo "    ];"
      fi
    } >"$keys"
  fi

  # rewrite name, email and keys inside the "user = { ... };" block, and leave
  # the rest of options.nix (comments, sshHosts, password settings) untouched.
  # the ssh server is per host, so sshHosts is written later by write_ssh_host,
  # once the host is known. the values go through the environment so awk doesn't
  # eat their backslashes.
  NAME_LINE="    name = $(nix_str "$NAME");" \
  EMAIL_LINE="    email = $(nix_str "$EMAIL");" \
  KEYS_FILE="$keys" \
  awk '
    BEGIN {
      name_line = ENVIRON["NAME_LINE"]
      email_line = ENVIRON["EMAIL_LINE"]
      keys_file = ENVIRON["KEYS_FILE"]
    }
    /^  user = \{/ { in_user = 1; print; next }
    in_user && /^  \};/ { in_user = 0; print; next }
    in_user && skipping { if (/^    \];/) skipping = 0; next }
    in_user && /^    name = / { print name_line; seen_name = 1; next }
    in_user && /^    email = / { print email_line; seen_email = 1; next }
    in_user && /^    keys = \[/ {
      if (keys_file == "") { seen_keys = 1; print; next }
      while ((getline line < keys_file) > 0) print line
      close(keys_file)
      if ($0 !~ /\];[ \t]*$/) skipping = 1
      seen_keys = 1
      next
    }
    { print }
    END { if (!(seen_name && seen_email && seen_keys)) exit 1 }
  ' "$options_file" >"$tmp" ||
    die "couldn't find name, email and keys in the 'user = { ... };' block, in $options_file"

  cat "$tmp" >"$options_file"
  rm -f "$keys" "$tmp"

  if [[ "$KEEP_KEYS" == "true" ]]; then
    step "Wrote user info to $options_file (left the existing ssh keys alone)"
  else
    step "Wrote user info to $options_file"
  fi
}

# sshHosts in options.nix lists the hosts that run the ssh server, see
# modules/services/ssh.nix. needs the host, so this runs after pick_host - and
# after --partition-only handed control back, in case the host changed.
write_ssh_host() {
  local options_file="$REPO_DIR/options.nix" tmp key_count password_login="false"

  # --do-not-partition skips ask_user_info, so without --ssh|--no-ssh there is
  # no answer to write - leave the list as the earlier run or the user left it
  if [[ -z "$ENABLE_SSH" ]]; then
    step "Left sshHosts in $options_file alone (pass --ssh or --no-ssh to change it)"
    return 0
  fi

  [[ -f "$options_file" ]] || die "$options_file not found in the repo"
  # Read the actual options, including keys preserved by --keep-keys or an earlier run.
  key_count="$(nix-instantiate --eval --strict \
    --expr '{ optionsFile }: builtins.length ((import (builtins.toPath optionsFile)).user.keys or [])' \
    --argstr optionsFile "$options_file")"
  if [[ "$key_count" == "0" ]]; then
    password_login="true"
  fi
  tmp="$(mktemp)"

  # keep the other hosts in the list, only add or drop this one
  HOST_NAME="$HOST" \
  SSH_ON="$ENABLE_SSH" \
  SSH_PASSWORD_LOGIN="$password_login" \
  awk '
    BEGIN {
      host_name = ENVIRON["HOST_NAME"]
      ssh_on = ENVIRON["SSH_ON"]
      password_login = ENVIRON["SSH_PASSWORD_LOGIN"]
    }
    /^  sshPasswordLogin = / { next }
    # sshHosts = ["a" "b"]; - may also be spread over several lines
    list != "" || /^  sshHosts = / {
      list = list $0
      if ($0 !~ /\];/) next
      hosts = ""
      while (match(list, /"[^"]*"/)) {
        name = substr(list, RSTART + 1, RLENGTH - 2)
        list = substr(list, RSTART + RLENGTH)
        if (name != host_name) hosts = hosts "\"" name "\" "
      }
      if (ssh_on == "true") hosts = hosts "\"" host_name "\" "
      sub(/ $/, "", hosts)
      print "  sshHosts = [" hosts "];"
      print "  sshPasswordLogin = " password_login ";"
      list = ""
      seen = 1
      next
    }
    { print }
    END { if (!seen) exit 1 }
  ' "$options_file" >"$tmp" ||
    die "couldn't find the sshHosts line in $options_file"

  cat "$tmp" >"$options_file"
  rm -f "$tmp"

  if [[ "$ENABLE_SSH" == "true" ]]; then
    step "Enabled the ssh server for $HOST in $options_file"
  else
    step "Left the ssh server off for $HOST in $options_file"
  fi
}

validate_repo_user() {
  local saved_name
  saved_name="$(OPTIONS_FILE="$REPO_DIR/options.nix" \
    nix --extra-experimental-features nix-command eval --impure --raw \
      --expr '(import (builtins.toPath (builtins.getEnv "OPTIONS_FILE"))).user.name')"
  [[ "$saved_name" == "$NAME" ]] ||
    die "username '$NAME' does not match '$saved_name' in $REPO_DIR/options.nix; restore the saved username before resuming"
}

restore_swap() {
  local swap_lv="/dev/mapper/$VG_NAME-swap" swap_uuid
  [[ -b "$swap_lv" ]] || return 0
  [[ "$(blkid -s TYPE -o value "$swap_lv")" == "swap" ]] ||
    die "$swap_lv is not formatted as swap"
  swap_uuid="$(blkid -s UUID -o value "$swap_lv")"
  [[ -n "$swap_uuid" ]] || die "couldn't read the UUID of $swap_lv"
  if ! swapon --show=UUID --noheadings --raw | grep -Fx "$swap_uuid" >/dev/null; then
    step "Activating the prepared swap volume"
    run swapon "$swap_lv"
  fi
}

trust_repo() {
  # The installed user's repository may already have been handed over by chown.
  # Trust this exact path for root's Git commands and nixos-install's Git access.
  if ! git config --global --get-all safe.directory | grep -Fx "$REPO_DIR" >/dev/null; then
    git config --global --add safe.directory "$REPO_DIR"
  fi
}

# --do-not-partition: the disk was prepared by an earlier run, pick the pieces back up
use_existing_setup() {
  step "Continuing on the existing setup at /mnt"
  mountpoint -q /mnt || die "/mnt is not mounted, run without --do-not-partition first"
  mountpoint -q /mnt/boot || die "/mnt/boot is not mounted; mount the EFI partition before continuing"

  local root_device
  root_device="$(findmnt -n -o SOURCE --target /mnt)"
  root_device="${root_device%%\[*}"
  LUKS_PART="$(lsblk -snrpo NAME,TYPE "$root_device" | awk '$2 == "part" { print $1; exit }')"
  [[ -n "$LUKS_PART" ]] || die "couldn't find the partition backing /mnt"
  if [[ "$(blkid -s TYPE -o value "$LUKS_PART")" == "crypto_LUKS" ]]; then
    ENABLE_ENCRYPTION="true"
  fi

  REPO_DIR="/mnt/home/$NAME/nixos"
  [[ -d "$REPO_DIR/.git" ]] || die "$REPO_DIR not found, run without --do-not-partition first"
  validate_repo_user

  trust_repo
  restore_swap

  echo "    root partition  $LUKS_PART (encryption: $ENABLE_ENCRYPTION)"
}

pick_host() {
  # only hosts that are both in hosts/ and in flake.nix's host list can be built
  local hosts=() dir name
  for dir in "$REPO_DIR"/hosts/*/; do
    name="$(basename "$dir")"
    grep -q "\"$name\"" "$REPO_DIR/flake.nix" && hosts+=("$name")
  done
  [[ ${#hosts[@]} -gt 0 ]] || die "no hosts found in $REPO_DIR/hosts that are listed in flake.nix"

  if [[ -n "$HOST" ]]; then
    local name
    for name in "${hosts[@]}"; do
      [[ "$name" == "$HOST" ]] && { step "Host: $HOST"; return 0; }
    done
    die "unknown host '$HOST', available: ${hosts[*]}"
  fi

  screen 2 "Choose your setup" "Select the host configuration for this machine."
  pick "Host configuration" HOST "${hosts[@]}"
}

write_hardware_config() {
  local hw_file host_dir hardware
  step "Generating hardware configuration for every host"

  local luks_uuid="" generated
  if [[ "$ENABLE_ENCRYPTION" == "true" ]]; then
    luks_uuid="$(blkid -s UUID -o value "$LUKS_PART")"
  fi
  generated="$(mktemp)"
  hardware="$(mktemp)"
  nixos-generate-config --root /mnt --show-hardware-config >"$generated"

  # drop whatever the generator wrote for initrd modules and luks, then add
  # dm-snapshot (LVM), plus cryptd and the luks device when encryption is enabled
  awk -v encrypted="$ENABLE_ENCRYPTION" -v crypt="$CRYPT_NAME" -v uuid="$luks_uuid" '
    /boot\.initrd\.kernelModules/ { next }
    /boot\.initrd\.luks\.devices/ { next }
    { lines[++n] = $0 }
    END {
      for (i = n; i > 0; i--) if (lines[i] ~ /^}/) { last = i; break }
      for (i = 1; i <= n; i++) {
        if (i == last) {
          print ""
          if (encrypted == "true") {
            print "  # LVM on LUKS: unlock the encrypted partition in initrd"
            print "  boot.initrd.kernelModules = [\"dm-snapshot\" \"cryptd\"];"
            print "  boot.initrd.luks.devices.\"" crypt "\".device = \"/dev/disk/by-uuid/" uuid "\";"
          } else {
            print "  boot.initrd.kernelModules = [\"dm-snapshot\"];"
          }
        }
        print lines[i]
      }
    }
  ' "$generated" >"$hardware"
  rm -f "$generated"

  for host_dir in "$REPO_DIR"/hosts/*/; do
    [[ -d "$host_dir" ]] || continue
    hw_file="${host_dir}hardware-configuration.nix"
    cp "$hardware" "$hw_file"
    # flakes only see files tracked by git
    git -C "$REPO_DIR" add "$hw_file"
  done
  rm -f "$hardware"
}

# asked before the install so the long build doesn't wait on a prompt afterwards
ask_password() {
  if [[ "$TUI" == "true" ]]; then
    note "Set the login password for $NAME."
  else
    step "Password for $NAME"
  fi

  local again
  while true; do
    ui_input "Account password" USER_PASS "Your login password" "" true
    ui_input "Repeat account password" again "Confirm your password" "" true
    if [[ -z "$USER_PASS" ]]; then
      note "Password can't be empty."
    elif [[ "$USER_PASS" != "$again" ]]; then
      note "Passwords don't match."
    else
      break
    fi
  done
}

# Copy mutable keyfiles, never credentials into the repository or Nix store.
# Optional paths allow non-destructive checks against a temporary installation.
copy_wifi_settings() {
  # Wi-Fi migration is optional and must never interrupt installation or emit UI output.
  copy_wifi_profiles "$@" >/dev/null 2>&1 || true
}

copy_wifi_profiles() {
  local target_root="${1:-/mnt}"
  local sources=(/etc/NetworkManager/system-connections /run/NetworkManager/system-connections)
  if [[ $# -gt 1 ]]; then
    shift
    sources=("$@")
  fi
  local destination="$target_root/etc/NetworkManager/system-connections"
  local directory profile target temporary
  for directory in "${sources[@]}"; do
    for profile in "$directory"/*; do
      [[ -f "$profile" && ! -L "$profile" ]] || continue
      # NetworkManager accepts both the canonical name and the wifi alias.
      if ! awk '
        { sub(/\r$/, "") }
        /^[ \t]*\[/ { connection = ($0 ~ /^[ \t]*\[connection\][ \t]*$/) }
        connection && /^[ \t]*type[ \t]*=[ \t]*(wifi|802-11-wireless)[ \t]*$/ { found = 1 }
        END { exit !found }
      ' "$profile"; then
        continue
      fi
      target="$destination/${profile##*/}"
      # Resuming must preserve profiles already saved or edited on the target.
      [[ ! -e "$target" && ! -L "$target" ]] || continue
      install -d -m 700 -o root -g root "$destination" || continue
      temporary="$(mktemp)" || continue
      # Installer-only users (root/nixos) must not hide the connection from KDE.
      # File mode 600 protects secrets; desktop edits/deletes use NM's Polkit API.
      if awk '
        /^[ \t]*\[/ { connection = ($0 ~ /^[ \t]*\[connection\][ \t]*\r?$/) }
        connection && /^[ \t]*permissions[ \t]*=/ { next }
        { print }
      ' "$profile" >"$temporary"; then
        install -m 600 -o root -g root "$temporary" "$target" || true
      fi
      rm -f "$temporary" || true
    done
  done
}

install_system() {
  step "Committing installation configuration"
  local commit_email
  commit_email="$(OPTIONS_FILE="$REPO_DIR/options.nix" \
    nix --extra-experimental-features nix-command eval --impure --raw \
      --expr '(import (builtins.toPath (builtins.getEnv "OPTIONS_FILE"))).user.email')"
  run git -C "$REPO_DIR" add -A
  if ! git -C "$REPO_DIR" diff --cached --quiet; then
    run git -C "$REPO_DIR" -c "user.name=$NAME" -c "user.email=$commit_email" \
      commit -m "install $HOST"
  fi

  step "Installing $HOST"
  run_long "Building and installing $HOST" nixos-install --flake "$REPO_DIR#$HOST" --no-root-password

  step "Setting the password for $NAME"
  printf '%s:%s\n' "$NAME" "$USER_PASS" | nixos-enter --root /mnt -c "chpasswd" ||
    die "couldn't set the password for $NAME"
  unset USER_PASS

  # the repo was cloned as root, hand the home directory over to the user
  run nixos-enter --root /mnt -c "chown -R $NAME:users /home/$NAME"
}

show_ssh_address() {
  # Resume may leave the SSH choice unset; use the saved setting for this host.
  if [[ -z "$ENABLE_SSH" ]]; then
    ENABLE_SSH="$(nix-instantiate --eval --strict \
      --expr '{ optionsFile, host }: builtins.elem host ((import (builtins.toPath optionsFile)).sshHosts or [])' \
      --argstr optionsFile "$REPO_DIR/options.nix" --argstr host "$HOST")"
  fi
  [[ "$ENABLE_SSH" == "true" ]] || return 0

  local addresses address
  # Route lookup only: this does not send a connection or require internet access.
  addresses="$(ip -4 route get 1.1.1.1 2>/dev/null | \
    awk '{ for (i = 1; i < NF; i++) if ($i == "src") { print $(i + 1); exit } }')" || true
  if [[ -z "$addresses" ]]; then
    addresses="$(ip -o -4 address show up scope global 2>/dev/null | \
      awk '{ split($4, address, "/"); print address[1] }')" || true
  fi
  if [[ -z "$addresses" ]]; then
    note "SSH is enabled. No local IPv4 address is currently available."
    return 0
  fi
  while IFS= read -r address; do
    note "Local IP: $address"
    note "Log in after reboot with: ssh $NAME@$address"
  done <<<"$addresses"
}

wait_for_reboot() {
  local deadline=$((SECONDS + ${1:-60})) remaining answer status
  while (( SECONDS < deadline )); do
    remaining=$((deadline - SECONDS))
    printf '\rRebooting in %2d seconds. Press Enter to reboot now. ' "$remaining"
    if IFS= read -r -t 1 answer; then
      break
    else
      status=$?
      # EOF should still allow the timer to run without a busy loop.
      if (( status <= 128 )); then
        sleep 1
      fi
    fi
  done
  printf '\n'
}

preview_ui() {
  local NAME="you" EMAIL="you@example.com" HOST="laptop" DRIVE="/dev/nvme0n1"
  local BOOT_PART="/dev/nvme0n1p1" LUKS_PART="/dev/nvme0n1p2" FS="btrfs" SWAP_GB=8
  local ENABLE_ENCRYPTION="true" ENABLE_SSH="true" KEEP_KEYS="false" KEYS=()
  screen 4 "Ready to install" "A preview of your new installation experience."
  show_summary
  note "PREVIEW ONLY · No disks are inspected or changed."
  note "Run without --preview to begin setup."
}

main() {
  # Bash keeps a separate descriptor for reading the script. Close the original
  # process-substitution pipe so tools such as LVM do not inherit /dev/fd/63.
  local script_fd
  if [[ "${BASH_SOURCE[0]}" =~ ^/(dev/fd|proc/self/fd)/([0-9]+)$ ]]; then
    script_fd="${BASH_REMATCH[2]}"
    if (( script_fd > 2 )); then
      exec {script_fd}<&-
    fi
  fi
  parse_args "$@"
  # Parse --help and --preview before requiring a terminal. With curl | bash,
  # main has already been read in full, so prompts can safely use /dev/tty.
  if [[ ! -t 0 && "$PREVIEW" == "false" ]]; then
    exec </dev/tty || die "An interactive terminal is required."
  fi
  init_ui
  if [[ "$PREVIEW" == "true" ]]; then
    preview_ui
    return 0
  fi
  preflight

  if [[ "$DO_NOT_PARTITION" == "true" ]]; then
    screen 1 "Pick up where you left off" "Enter the username used when preparing this installation."
    ask_username
    use_existing_setup
    pick_host
    ask_password
    screen 5 "Making it yours" "Preparing configuration, committing changes, and installing NixOS."
    [[ "$TUI" == "false" ]] || note "Full installation log: $INSTALL_LOG"
    write_resume_keys
    # the earlier run wrote the user info, but the ssh server is per host, so
    # --ssh|--no-ssh applies to the host picked here, which may have changed
    write_ssh_host
    # Keep hardware configuration edits made while the target was mounted.
  else
    ask_user_info
    prepare_repo
    pick_host
    ask_disk
    if [[ "$PARTITION_ONLY" == "false" ]]; then
      screen 4 "Secure your account" "Choose the password you will use to log in."
      ask_password
    fi
    confirm
    screen 5 "Making it yours" "Preparing storage and installing your chosen configuration."
    [[ "$TUI" == "false" ]] || note "Full installation log: $INSTALL_LOG"
    partition
    clone_repo
    write_user_info
    write_lan_ip
    write_ssh_host
    write_hardware_config

    if [[ "$PARTITION_ONLY" == "true" ]]; then
      copy_wifi_settings
      screen 5 "Your drive is ready" "Partitioning and configuration are complete."
      note "$DRIVE is mounted at /mnt. Your repository is at $REPO_DIR."
      note "Continue when you are ready:"
      note "bash $REPO_DIR/scripts/install.sh --do-not-partition"
      exit 0
    fi
  fi

  copy_wifi_settings
  install_system

  screen 5 "Welcome home, $NAME" "NixOS is installed. Your configuration changes have been committed."
  if [[ "$ENABLE_ENCRYPTION" == "true" ]]; then
    note "After reboot, unlock the disk with your encryption password, then log in as $NAME."
  else
    note "After reboot, log in as $NAME."
  fi
  show_ssh_address
  wait_for_reboot
  note "Restarting into your new system…"
  echo
  run reboot
}

# Sourcing exposes helpers for non-destructive checks without starting installation.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
