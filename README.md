# Install NixOS
Boot the NixOS minimal installation ISO, then run:

`sudo su`

`loadkeys fi`

## Connect to the internet

`nixos-install` downloads the whole system. To connect to Wi-Fi:
```bash
nmtui
# or
nmcli device wifi connect "<SSID>" password "<PASSWORD>"
```

## Install over SSH (optional)

On the machine booted from the NixOS ISO, after connecting it to the network,
set a temporary password for the live `nixos` user and start SSH:

```bash
passwd nixos
systemctl start sshd
hostname -I
```

From another machine on the same network, connect using the IP shown above.
For example:

```bash
ssh -t nixos@192.168.1.50
```

Enter the temporary password, then run these commands inside the SSH session:

```bash
sudo su
bash <(curl -sL https://raw.githubusercontent.com/lehtlau/nixos/main/scripts/install.sh)
```

## Run the installation script
```bash
bash <(curl -sL https://raw.githubusercontent.com/lehtlau/nixos/main/scripts/install.sh)
```

Alternatively, continue with the manual installation below.

## Create boot and root partitions (Manual install guide)
Find your drives with `lsblk -o name,uuid,size,fstype,mountpoint,model`.

Run `cfdisk /dev/<YOUR_BLOCK_DEVICE>` on your drive and create a GPT partition table with the following layout:

- Partition 1: 2G, type `EFI System`
- Partition 2: rest of the disk, type `Linux filesystem`

```bash
NAME               UUID                                     SIZE FSTYPE      MODEL
nvme1n1                                                   931,5G             Samsung SSD 980 1TB
├─nvme1n1p1        8A88-665B                                  2G vfat
└─nvme1n1p2        582d6f53-d527-48a4-9d19-f6945b2b8584   929,5G crypto_LUKS
```
## Set up LUKS full disk encryption
Replace `nvme1n1p1` and `nvme1n1p2` with your own partitions.
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

# Optionally, create the swap volume
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
Your layout should look something like this:
```
nvme1n1                                                   931,5G             Samsung SSD 980 1TB
├─nvme1n1p1        8A88-665B                                  2G vfat
└─nvme1n1p2        582d6f53-d527-48a4-9d19-f6945b2b8584   929,5G crypto_LUKS
  └─cryptroot      QPeLcN-y2du-bN6C-ZCLI-vf5M-w6FU-Z93nkw 929,5G LVM2_member
    ├─lvmroot-swap 80e5ff5b-70d1-4ea7-81a5-0919d0515935       8G swap
    └─lvmroot-root b844ab70-8b62-4396-8873-ba81c3a80552   921,5G ext4
```

## Generate your hardware configuration
```bash
nixos-generate-config --root /mnt
```
This writes `/mnt/etc/nixos/hardware-configuration.nix`.

## Get the flake
Pick **one** of the two options. Both place the repository at `/mnt/home/<your_username>/nixos`.

The username comes from `user.name` in `options.nix` at the repository root. Change it there if you are installing for someone else.

### Option A: Clone from GitHub
This requires an internet connection. The minimal ISO does not include Git, so load it in a temporary shell:
```bash
nix-shell -p git

mkdir -p /mnt/home/<your_username>
git clone https://github.com/lehtlau/nixos /mnt/home/<your_username>/nixos
cd /mnt/home/<your_username>/nixos
```

### Option B: Copy from the Ventoy USB drive
Before booting, put the `nixos` repository folder (including its hidden `.git` folder) in the root of the Ventoy data partition, next to the ISO files.

Find the Ventoy data partition: it is the large `exfat` partition labeled `Ventoy`:
```bash
lsblk -o name,label,size,fstype,mountpoint
```
Mount it somewhere other than `/mnt`, where the new system is mounted:
```bash
mkdir -p /media/usb

# While booted from Ventoy, the raw partition (e.g. /dev/sda1) is held by Ventoy,
# so it appears as a device-mapper node instead.
mount /dev/mapper/sda1 /media/usb
```
Copy the repository to your new home directory and unmount the USB drive:
```bash
mkdir -p /mnt/home/<your_username>
cp -r /media/usb/nixos /mnt/home/<your_username>/nixos
umount /media/usb
cd /mnt/home/<your_username>/nixos
```

## Pick a host and copy your hardware configuration
Available hosts: `laptop`, `gmk`, `server`, `jupiter`, `kde-desktop`, and
`mini-ai-server` (see `hosts/` and the host list in `flake.nix`).
`kde-desktop` and `mini-ai-server` have placeholder hardware configurations.
The installer replaces these; for manual installation, copy the generated
hardware configuration as described below.

**Reinstalling an existing host:** overwrite its hardware configuration:
```bash
cp /mnt/etc/nixos/hardware-configuration.nix hosts/<host>/hardware-configuration.nix
```

**Adding a new host:**
```bash
cp -r hosts/laptop hosts/<new_host>
cp /mnt/etc/nixos/hardware-configuration.nix hosts/<new_host>/hardware-configuration.nix
```
- Set `networking.hostName = "<new_host>";` in `hosts/<new_host>/configuration.nix`.
- Add `"<new_host>"` to the host list at the bottom of `flake.nix`.
- Stage the new files. **Flakes only see files tracked by Git:**
```bash
git add hosts/<new_host>
```

## Verify that your hardware configuration can mount encrypted logical volumes
The initrd needs to know where to find the encrypted partition. Edit `hosts/<host>/hardware-configuration.nix` and make sure it has the following:
```nix
{ # cut
  # Include "cryptd" in the initrd kernel modules so the system can boot
  # with the root and swap logical volumes inside the encrypted partition.
  boot.initrd.kernelModules = [ "dm-snapshot" "cryptd" ]; # <- Add "cryptd" here

  # Modify this to the name of the encrypted partition (the label you used with cryptsetup luksFormat)
  boot.initrd.luks.devices."cryptroot".device = "/dev/disk/by-label/NixOS-Encrypted";

  # Modify this to the name of the root logical volume (the label you used with mkfs.ext4)
  fileSystems."/" =
    { device = "/dev/disk/by-label/NixOS-Root"; # <- Change this
      fsType = "ext4";
    };

  # Modify this to the name of the unencrypted boot partition (the label you used with mkfs.fat)
  fileSystems."/boot" =
    { device = "/dev/disk/by-label/NixOS-Boot"; # <- Change this
      fsType = "vfat";
      options = [ "fmask=0077" "dmask=0077" ];
    };

  # Modify this to the name of the swap logical volume (the label you used with mkswap)
  swapDevices = [ { device = "/dev/disk/by-label/NixOS-Swap"; } ]; # <- Change this
}
```

## Install
```bash
nixos-install --flake /mnt/home/<your_username>/nixos#<host> --no-root-password
```
If you get `experimental feature 'flakes' is disabled`, add `--option experimental-features 'nix-command flakes'`.

After installation, set a password for your user and give the user ownership of the flake repository:
```bash
nixos-enter --root /mnt -c 'passwd <your_username>'
nixos-enter --root /mnt -c 'chown -R <your_username>:users /home/<your_username>'
```

`reboot`

Installation is complete.

# Useful commands

### Create and delete named NixOS system profiles

```bash
# Create or update a named system profile and activate it
sudo nixos-rebuild switch \
  --flake /etc/nixos#<hostname> \
  --profile-name <profile_name>

# List named system profiles
sudo ls -lah /nix/var/nix/profiles/system-profiles/

# List generations for a named profile
sudo nix-env \
  -p /nix/var/nix/profiles/system-profiles/<profile_name> \
  --list-generations

# Delete older generations of a named profile,
# retaining its current generation and the profile itself
sudo nix-env \
  -p /nix/var/nix/profiles/system-profiles/<profile_name> \
  --delete-generations old

# Delete a named profile reference
sudo rm /nix/var/nix/profiles/system-profiles/<profile_name>

# List available system maintenance commands
just

```

### Update flake inputs
```
nix flake update
nix flake lock --update-input hypr-monitors
```

### Install a new system configuration for the next boot
```
sudo nixos-rebuild boot --flake

# --profile-name <profile_name> 
```

### Change hosts
```
sudo nixos-rebuild switch --flake .#<host>
```
### Change ownership

```
# Recursively change ownership of a directory and its files
sudo chown -R $(id -un):users <path>
```
### Unlock with a keyfile

```
  boot.initrd.availableKernelModules = ["mmc_block"];
  boot.initrd.luks.devices.cryptroot = {
    keyFile = "/luks.key:UUID=<sd-card-uuid>";
    crypttabExtraOpts = ["keyfile-timeout=5s"];
  };

sudo dd if=/dev/urandom of=/media/user/sdcard/luks.key bs=512 count=8
sudo chmod 400 /media/user/sdcard/luks.key
sudo cryptsetup luksAddKey /dev/disk/by-uuid/714d8d85-3444-4a28-937c-ab967e2737e8 /media/user/sdcard/luks.key
```
