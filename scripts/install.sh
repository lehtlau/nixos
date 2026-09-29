#!/usr/bin/env bash
# install.sh — install NixOS from this flake onto a fresh drive, from the NixOS minimal install ISO
#
# Asks for your user info, wipes the chosen drive and sets it up as described in install.md:
#   p1  2G    EFI System, vfat, label NixOS-Boot                -> /mnt/boot
#   p2  rest  LUKS2, label NixOS-Encrypted, opened as cryptroot
#             └─ LVM volume group lvmroot
#                ├─ swap  (optional) label NixOS-Swap             -> swapon
#                └─ root  ext4 | btrfs | xfs, label NixOS-Root     -> /mnt
# then clones the repo to /mnt/home/<user>/nixos, writes your user info into it, generates the
# host's hardware-configuration.nix with LUKS unlock, runs nixos-install and sets your password.
#
# Usage (on the ISO, after connecting to the internet):
#   sudo -i
#   bash <(curl -sL https://raw.githubusercontent.com/<github_user>/nixos/main/scripts/install.sh)
#
# Flags:
#   --name <user> --email <email>     skip the user info prompts
#   --key "<ssh public key>"          repeatable, skip the ssh key prompt
#   --no-keys                         no ssh keys
#   --repo <url> --branch <branch>    clone another repo / branch
#   --dry-run                         print disk and install commands instead of running them

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
NO_KEYS="false"
DRY_RUN="false"

# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------

usage() {
  cat <<'EOF'
Install NixOS from this flake onto a fresh drive (run from the NixOS install ISO as root).

  bash <(curl -sL https://raw.githubusercontent.com/<github_user>/nixos/main/scripts/install.sh) [flags]

Flags:
  --name <user> --email <email>     skip the user info prompts
  --key "<ssh public key>"          repeatable, skip the ssh key prompt
  --no-keys                         no ssh keys
  --repo <url> --branch <branch>    clone another repo / branch
  --dry-run                         print disk and install commands instead of running them
EOF
  exit "${1:-0}"
}

die() {
  echo "Error: $*" >&2
  exit 1
}

step() {
  echo
  echo "==> $*"
}

# run a command, or just print it in dry-run mode
run() {
  echo "+ $*"
  [[ "$DRY_RUN" == "true" ]] || "$@"
}

# pick one item from a list: pick <prompt> <result var> <items...>
pick() {
  local prompt="$1" var="$2" choice
  shift 2
  PS3="$prompt> "
  select choice in "$@"; do
    [[ -n "$choice" ]] && break
    echo "Invalid choice, enter a number from the list."
  done
  printf -v "$var" '%s' "$choice"
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
      --name) NAME="${2:?--name needs a value}"; shift 2 ;;
      --email) EMAIL="${2:?--email needs a value}"; shift 2 ;;
      --key) KEYS+=("${2:?--key needs a value}"); shift 2 ;;
      --no-keys) NO_KEYS="true"; shift ;;
      --repo) REPO_URL="${2:?--repo needs a value}"; shift 2 ;;
      --branch) BRANCH="${2:?--branch needs a value}"; shift 2 ;;
      --dry-run) DRY_RUN="true"; shift ;;
      -h | --help) usage ;;
      *) echo "Unknown argument: $1" >&2; usage 1 ;;
    esac
  done
}

preflight() {
  [[ "$REPO_URL" == *"<github_user>"* ]] && die "REPO_URL isn't set, edit it at the top of the script or pass --repo <url>"

  if [[ "$DRY_RUN" == "false" ]]; then
    [[ $EUID -eq 0 ]] || die "run as root (sudo -i)"
    [[ -d /sys/firmware/efi ]] || die "not booted in UEFI mode, the flake uses grub with efiSupport"
    if [[ -e "/dev/mapper/$CRYPT_NAME" ]] || mountpoint -q /mnt; then
      die "/dev/mapper/$CRYPT_NAME is open or /mnt is mounted, clean up first:
  swapoff -a; umount -R /mnt; vgchange -an $VG_NAME; cryptsetup close $CRYPT_NAME"
    fi
  fi

  # the drive gets wiped before cloning, so make sure the clone will work first
  step "Checking internet access"
  curl -sfI --max-time 10 https://github.com >/dev/null ||
    die "can't reach github.com, connect first (nmtui or: nmcli device wifi connect \"<SSID>\" password \"<PASSWORD>\")"

  # the minimal ISO doesn't ship git, pull it in once
  if ! command -v git >/dev/null; then
    step "Fetching git"
    PATH="$(nix-build '<nixpkgs>' -A git --no-out-link)/bin:$PATH"
    export PATH
  fi

  git ls-remote --exit-code --heads "$REPO_URL" "$BRANCH" >/dev/null ||
    die "can't read branch '$BRANCH' of $REPO_URL (private repo? wrong url?)"
}

ask_user_info() {
  step "User info"

  while [[ ! "$NAME" =~ ^[a-z_][a-z0-9_-]*$ ]]; do
    [[ -n "$NAME" ]] && echo "Invalid username '$NAME': use lowercase letters, digits, - and _, starting with a letter."
    read -rp "Username: " NAME
  done

  while [[ -z "$EMAIL" ]]; do
    read -rp "Email (used for git): " EMAIL
  done

  if [[ ${#KEYS[@]} -eq 0 && "$NO_KEYS" == "false" ]]; then
    echo "SSH public keys allowed to log in as $NAME, one per line. Empty line to finish."
    local key
    while read -rp "key> " key && [[ -n "$key" ]]; do
      if [[ "$key" =~ ^(ssh-|ecdsa-|sk-) ]]; then
        KEYS+=("$key")
      else
        echo "Doesn't look like an ssh public key, skipped."
      fi
    done
  fi

  local key
  for key in "${KEYS[@]}"; do
    [[ "$key" =~ ^(ssh-|ecdsa-|sk-) ]] || die "doesn't look like an ssh public key: $key"
  done
}

ask_disk() {
  step "Disk setup"

  local drives=() name type
  while read -r name _ type; do
    [[ "$type" == "disk" ]] && drives+=("$name")
  done < <(lsblk -dpno NAME,SIZE,TYPE)
  [[ ${#drives[@]} -gt 0 ]] || die "no drives found"

  lsblk -o NAME,SIZE,TYPE,FSTYPE,LABEL,MOUNTPOINT,MODEL "${drives[@]}"
  echo
  echo "Select the drive to install NixOS on (EVERYTHING ON IT WILL BE ERASED):"
  pick drive DRIVE "${drives[@]}"

  if lsblk -no MOUNTPOINT "$DRIVE" | grep -q .; then
    die "$DRIVE has mounted partitions (is it the usb you booted from?)"
  fi

  # nvme0n1 / mmcblk0 -> nvme0n1p1, sda -> sda1
  if [[ "$DRIVE" =~ [0-9]$ ]]; then
    BOOT_PART="${DRIVE}p1"
    LUKS_PART="${DRIVE}p2"
  else
    BOOT_PART="${DRIVE}1"
    LUKS_PART="${DRIVE}2"
  fi

  echo "Select the root filesystem:"
  pick filesystem FS ext4 btrfs

  while true; do
    read -rp "Swap size in GiB (0 for no swap) [8]: " SWAP_GB
    SWAP_GB="${SWAP_GB:-8}"
    [[ "$SWAP_GB" =~ ^[0-9]+$ ]] && break
    echo "Enter a whole number."
  done

  local again
  while true; do
    read -rsp "LUKS password: " LUKS_PASS; echo
    read -rsp "Repeat LUKS password: " again; echo
    if [[ -z "$LUKS_PASS" ]]; then
      echo "Password can't be empty."
    elif [[ "$LUKS_PASS" != "$again" ]]; then
      echo "Passwords don't match."
    else
      break
    fi
  done
}

confirm() {
  step "About to:"
  echo "    wipe       $DRIVE"
  echo "    boot       $BOOT_PART  $BOOT_SIZE vfat ($BOOT_LABEL)"
  echo "    encrypted  $LUKS_PART  LUKS2 ($LUKS_LABEL) -> /dev/mapper/$CRYPT_NAME -> LVM $VG_NAME"
  [[ "$SWAP_GB" -gt 0 ]] && echo "    swap       ${SWAP_GB}G ($SWAP_LABEL)"
  echo "    root       rest of the disk, $FS ($ROOT_LABEL)"
  echo "    clone      $REPO_URL ($BRANCH) -> /mnt/home/$NAME/nixos"
  echo "    user       $NAME <$EMAIL>, ${#KEYS[@]} ssh key(s)"
  echo
  local answer
  read -rp "Type the drive path ($DRIVE) to confirm: " answer
  [[ "$answer" == "$DRIVE" ]] || { echo "Aborted, nothing was changed."; exit 1; }
}

partition() {
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

  step "Setting up LUKS"
  printf '%s' "$LUKS_PASS" | run cryptsetup luksFormat --batch-mode --type luks2 --label="$LUKS_LABEL" --key-file=- "$LUKS_PART"
  printf '%s' "$LUKS_PASS" | run cryptsetup open --key-file=- "$LUKS_PART" "$CRYPT_NAME"
  unset LUKS_PASS

  step "Setting up LVM"
  run pvcreate "/dev/mapper/$CRYPT_NAME"
  run vgcreate "$VG_NAME" "/dev/mapper/$CRYPT_NAME"
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

clone_repo() {
  if [[ "$DRY_RUN" == "true" ]]; then
    REPO_DIR="$(mktemp -d)/nixos"
  else
    REPO_DIR="/mnt/home/$NAME/nixos"
  fi

  step "Cloning $REPO_URL into $REPO_DIR"
  mkdir -p "$(dirname "$REPO_DIR")"
  git clone --branch "$BRANCH" "$REPO_URL" "$REPO_DIR"
}

write_user_info() {
  local users_file="$REPO_DIR/modules/system/users/default.nix"
  [[ -f "$users_file" ]] || die "$users_file not found in the cloned repo"

  local block tmp key
  block="$(mktemp)"
  tmp="$(mktemp)"
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
  } >"$block"

  # replace from "  my.user = {" up to its closing "  };"
  awk -v block="$block" '
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
  ' "$users_file" >"$tmp" || die "couldn't find the 'my.user = { ... };' block in $users_file"

  cat "$tmp" >"$users_file"
  rm -f "$block" "$tmp"

  step "Wrote user info to $users_file"
}

pick_host() {
  # only hosts that are both in hosts/ and in flake.nix's host list can be built
  local hosts=() dir name
  for dir in "$REPO_DIR"/hosts/*/; do
    name="$(basename "$dir")"
    grep -q "\"$name\"" "$REPO_DIR/flake.nix" && hosts+=("$name")
  done
  [[ ${#hosts[@]} -gt 0 ]] || die "no hosts found in $REPO_DIR/hosts that are listed in flake.nix"

  step "Select the host to install:"
  pick host HOST "${hosts[@]}"
}

write_hardware_config() {
  local hw_file="$REPO_DIR/hosts/$HOST/hardware-configuration.nix"
  step "Generating $hw_file"

  if [[ "$DRY_RUN" == "true" ]]; then
    echo "+ nixos-generate-config --root /mnt --show-hardware-config > $hw_file (+ LUKS unlock)"
    return
  fi

  local luks_uuid generated
  luks_uuid="$(blkid -s UUID -o value "$LUKS_PART")"
  generated="$(mktemp)"
  nixos-generate-config --root /mnt --show-hardware-config >"$generated"

  # drop whatever the generator wrote for initrd modules and luks, then add
  # dm-snapshot (LVM) + cryptd and the luks device before the closing brace
  awk -v crypt="$CRYPT_NAME" -v uuid="$luks_uuid" '
    /boot\.initrd\.kernelModules/ { next }
    /boot\.initrd\.luks\.devices/ { next }
    { lines[++n] = $0 }
    END {
      for (i = n; i > 0; i--) if (lines[i] ~ /^}/) { last = i; break }
      for (i = 1; i <= n; i++) {
        if (i == last) {
          print ""
          print "  # LVM on LUKS: unlock the encrypted partition in initrd"
          print "  boot.initrd.kernelModules = [\"dm-snapshot\" \"cryptd\"];"
          print "  boot.initrd.luks.devices.\"" crypt "\".device = \"/dev/disk/by-uuid/" uuid "\";"
        }
        print lines[i]
      }
    }
  ' "$generated" >"$hw_file"
  rm -f "$generated"

  # flakes only see files tracked by git
  git -C "$REPO_DIR" add "$hw_file"
}

install_system() {
  step "Installing $HOST"
  run nixos-install --flake "$REPO_DIR#$HOST" --no-root-password

  step "Set the password for $NAME"
  if [[ "$DRY_RUN" == "true" ]]; then
    echo "+ nixos-enter --root /mnt -c 'passwd $NAME'"
  else
    until nixos-enter --root /mnt -c "passwd $NAME"; do
      echo "Try again."
    done
  fi

  # the repo was cloned as root, hand the home directory over to the user
  run nixos-enter --root /mnt -c "chown -R $NAME:users /home/$NAME"
}

main() {
  parse_args "$@"
  preflight
  ask_user_info
  ask_disk
  confirm
  partition
  clone_repo
  write_user_info
  pick_host
  write_hardware_config
  install_system

  step "Done"
  echo "Reboot, unlock the disk with your LUKS password and log in as $NAME."
  echo "Then commit the generated config:"
  echo "  cd ~/nixos && git add -A && git commit -m \"install $HOST\""
}

# with `curl ... | bash` stdin is the script itself, so read answers from the terminal.
# everything runs inside main, so bash has read the whole script before stdin is swapped.
if [[ -t 0 ]]; then
  main "$@"
else
  main "$@" </dev/tty
fi
