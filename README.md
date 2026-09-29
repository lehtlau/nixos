# Install nixos
Boot the NixOS minimal install ISO, then:

`sudo -i`

`loadkeys fi`

## Connect to the internet
`nixos-install` downloads the whole system. For wifi:
```bash
nmtui
# or
nmcli device wifi connect "<SSID>" password "<PASSWORD>"
```

## run install script
```bash
bash <(curl -sL https://raw.githubusercontent.com/lehtlau/nixos/main/scripts/install.sh)
```
or continue with the manual installation...

## Create boot and root partitions
Find your drives `lsblk -o name,uuid,size,fstype,mountpoint,model`

Use `cfdisk` on your drive `cfdisk /dev/<YOUR_BLOCK_DEVICE>` and make a GPT table with the following layout:
- partition 1: 2G, type `EFI System`
- partition 2: rest of the disk, type `Linux filesystem`

```bash
NAME               UUID                                     SIZE FSTYPE      MODEL
nvme1n1                                                   931,5G             Samsung SSD 980 1TB
├─nvme1n1p1        8A88-665B                                  2G vfat
└─nvme1n1p2        582d6f53-d527-48a4-9d19-f6945b2b8584   929,5G crypto_LUKS
```
## Setup luks full disk encryption
Replace `nvme1n1p1` / `nvme1n1p2` with your own partitions.
```bash
# format the boot partition
mkfs.fat -F 32 -n "NixOS-Boot" /dev/nvme1n1p1

# create an encrypted partition
cryptsetup luksFormat -y --label="NixOS-Encrypted" /dev/nvme1n1p2

# open the encrypted partition and map it to /dev/mapper/cryptroot
cryptsetup luksOpen /dev/nvme1n1p2 cryptroot

# create the physical volume
pvcreate /dev/mapper/cryptroot

# create a volume group inside
vgcreate lvmroot /dev/mapper/cryptroot

# Optional, create the swap volume
lvcreate --size 8G lvmroot --name swap

# create the root volume
lvcreate -l 100%FREE lvmroot --name root

# format the root volume
mkfs.ext4 -L "NixOS-Root" /dev/mapper/lvmroot-root

# format the swap volume
mkswap -L "NixOS-Swap" /dev/mapper/lvmroot-swap

# mount root
mount /dev/disk/by-label/NixOS-Root /mnt

# mount boot
mkdir -p /mnt/boot
mount -o umask=077 /dev/disk/by-label/NixOS-Boot /mnt/boot

# turn on swap
swapon /dev/disk/by-label/NixOS-Swap
```
Your layout should look something like this
```
nvme1n1                                                   931,5G             Samsung SSD 980 1TB
├─nvme1n1p1        8A88-665B                                  2G vfat
└─nvme1n1p2        582d6f53-d527-48a4-9d19-f6945b2b8584   929,5G crypto_LUKS
  └─cryptroot      QPeLcN-y2du-bN6C-ZCLI-vf5M-w6FU-Z93nkw 929,5G LVM2_member
    ├─lvmroot-swap 80e5ff5b-70d1-4ea7-81a5-0919d0515935       8G swap
    └─lvmroot-root b844ab70-8b62-4396-8873-ba81c3a80552   921,5G ext4
```

## Generate your hardware config
```bash
nixos-generate-config --root /mnt
```
This writes `/mnt/etc/nixos/hardware-configuration.nix`.

## Get the flake
Pick **one** of the two options. Both end with the repo at `/mnt/home/<your_username>/nixos`.

The username comes from `my.user.name` in `modules/system/users/default.nix`. Change it there if you install for someone else.

### Option A: clone from github
Needs internet. The minimal ISO doesn't ship git, so pull it into a temporary shell:
```bash
nix-shell -p git

mkdir -p /mnt/home/<your_username>
git clone https://github.com/lehtlau/nixos /mnt/home/<your_username>/nixos
cd /mnt/home/<your_username>/nixos
```

### Option B: copy from the ventoy usb thumbdrive
Before booting, put the `nixos` repo folder (including its hidden `.git` folder) in the root of the ventoy data partition, next to the ISO files.

lsblk -f Find the ventoy data partition, it's the big `exfat` partition labeled `Ventoy`:
```bash
lsblk -o name,label,size,fstype,mountpoint
```
Mount it somewhere other than `/mnt` (`/mnt` is the new system):
```bash
mkdir -p /media/usb

# while booted from ventoy the raw partition (e.g. /dev/sda1) is held by ventoy,
# so it shows up as a device mapper node instead
mount /dev/mapper/sda1 /media/usb
```
Copy the repo to your new home directory and unmount the usb:
```bash
mkdir -p /mnt/home/<your_username>
cp -r /media/usb/nixos /mnt/home/<your_username>/nixos
umount /media/usb
cd /mnt/home/<your_username>/nixos
```

## Pick a host and copy in your hardware config
Available hosts: `laptop`, `gmk`, `server`, `jupiter` (see `hosts/` and the host list in `flake.nix`).

**Reinstalling an existing host**, overwrite its hardware config:
```bash
cp /mnt/etc/nixos/hardware-configuration.nix hosts/<host>/hardware-configuration.nix
```

**Adding a new host**:
```bash
cp -r hosts/laptop hosts/<new_host>
cp /mnt/etc/nixos/hardware-configuration.nix hosts/<new_host>/hardware-configuration.nix
```
- set `networking.hostName = "<new_host>";` in `hosts/<new_host>/configuration.nix`
- add `"<new_host>"` to the host list at the bottom of `flake.nix`
- stage the new files, **flakes only see files tracked by git**:
```bash
git add hosts/<new_host>
```

## Verify your hardware config has everything required to mount encrypted logical volumes
initrd needs to know where to find the encrypted partition. Edit `hosts/<host>/hardware-configuration.nix` and make sure it has the following:
```nix
{ # cut
  # We need "cryptd" in the initrd kernel modules, or the system won't boot expecting an encrypted partition, which is where our root and swap logical volumes live.
  boot.initrd.kernelModules = [ "dm-snapshot" "cryptd" ]; # <- Add "cryptd" in it

  # Modify this to the name of the encrypted partition (name you used in cryptsetup luksFormat)
  boot.initrd.luks.devices."cryptroot".device = "/dev/disk/by-label/NixOS-Encrypted";

  # Modify this to the name of the root logical volume (name you used in mkfs.ext4)
  fileSystems."/" =
    { device = "/dev/disk/by-label/NixOS-Root"; # <- Change this
      fsType = "ext4";
    };

  # Modify this to the name of the unencrypted boot partition (name you used in mkfs.fat)
  fileSystems."/boot" =
    { device = "/dev/disk/by-label/NixOS-Boot"; # <- Change this
      fsType = "vfat";
      options = [ "fmask=0077" "dmask=0077" ];
    };

  # Modify this to the name of the swap logical volume (name you used in mkswap)
  swapDevices = [ { device = "/dev/disk/by-label/NixOS-Swap"; } ]; # <- Change this
}
```

## Install
```bash
nixos-install --flake /mnt/home/<your_username>/nixos#<host> --no-root-password
```
If you get `experimental feature 'flakes' is disabled`, add `--option experimental-features 'nix-command flakes'`.


After the install, set a password for your user and give it ownership of the flake
```bash
nixos-enter --root /mnt -c 'passwd <your_username>'
nixos-enter --root /mnt -c 'chown -R <your_username>:users /home/<your_username>'
```

`reboot`

### done

# useful stuff

### create and delete profiles
```
sudo nixos-rebuild switch --profile-name work

sudo nix-env -p /nix/var/nix/profiles/system-profiles/<name> --delete-generations old

sudo nixos-rebuild boot
```
### Test build without applying
```
sudo nixos-rebuild dry-build --flake .
```
### change host
```
sudo nixos-rebuild switch --flake .#<host>
```
###  change ownership

```
# change ownsersip of dir its files recursively
sudo chown -R $(id -un):users <path>
```
###  unlock with a keyfile

```
  boot.initrd.availableKernelModules = ["mmc_block"];
  boot.initrd.luks.devices.cryptroot = {
    keyFile = "/luks.key:UUID=70553896-3b13-4964-ba55-582b001fc7ab";
    crypttabExtraOpts = ["keyfile-timeout=5s"];
  };


sudo dd if=/dev/urandom of=/media/user/sdcard/luks.key bs=512 count=8
sudo chmod 400 /media/user/sdcard/luks.key
sudo cryptsetup luksAddKey /dev/disk/by-uuid/714d8d85-3444-4a28-937c-ab967e2737e8 /media/user/sdcard/luks.key
```
