# NixOS — ASUS ZenBook UX425EA

Flake-based NixOS config for `zenbook`: Intel i7-1165G7 (Tiger Lake), 32 GB RAM,
1 TB NVMe, Iris Xe graphics, Wi-Fi 6 AX201.

Hyprland on Wayland, LUKS + btrfs, Home Manager, Swedish keyboard with an
English UI.

Keybindings and handy commands: [KEYBINDINGS.md](KEYBINDINGS.md).

## Status

`nix flake check` passes against the pinned inputs in `flake.lock`
(nixpkgs `e158d9e`, 2026-09-26). That means the whole configuration — system
and Home Manager — *evaluates* cleanly, with no errors and no deprecation
warnings. It has not been *built* or booted; expect the first
`nixos-install` to be the real test.

## Layout

```
flake.nix                 inputs (nixpkgs unstable, home-manager, disko, nixos-hardware)
hosts/zenbook/
  default.nix             boot, networking, locale, users, power
  disko.nix               declarative partitioning — LUKS + btrfs subvolumes
  hardware-configuration.nix   REGENERATE during install (see below)
modules/
  nix.nix                 nix daemon, GC, caches, allowUnfree
  desktop.nix             Hyprland, greetd, portals, pipewire, graphics, fonts
  dev.nix                 Go, Rust, Node, Python, k8s, tofu, claude-code, CLI
  apps.nix                Firefox, Thunderbird, Discord, VLC, VS Code, Steam
  virtualisation.nix      libvirt/virt-manager, podman
home/
  fabian.nix              git, kitty, neovim, mako, wofi, hyprlock, hypridle, theming
  hyprland.nix            compositor config and key bindings
  waybar.nix              status bar
  shell.nix               zsh, starship, fzf, tmux, aliases
```

## Installing

Written for the actual machine this replaces: an ASUS ZenBook UX425EA running
Ubuntu 24.04, with a 30 GB SanDisk Extreme USB stick.

### Devices

| | |
|---|---|
| USB stick | `/dev/sda` — SanDisk Extreme, 29.8 G, removable |
| Internal disk | `/dev/nvme0n1` — 953.9 G NVMe — **this is what gets wiped** |

Re-check both with `lsblk` before each destructive step. USB enumeration is not
guaranteed stable across reboots, and `sda` vs `nvme0n1` is the difference
between losing a USB stick and losing the machine.

### Step 1 — Write the ISO to the stick

Using `nixos-graphical-25.11` — the graphical ISO, for its browser and GUI
Wi-Fi. Verified against releases.nixos.org:

```
cd96cc2a8d6dde124bbd666126f09003017156804336f994b8dd2d09472c9c7e
```

The stick had Proxmox VE on it, so unmount before writing:

```sh
sudo umount /dev/sda3
lsblk -o NAME,SIZE,TRAN,MODEL /dev/sda     # confirm it is still the SanDisk

sudo dd if=~/Downloads/nixos-graphical-25.11.7766.fea3b367d61c-x86_64-linux.iso \
        of=/dev/sda bs=4M status=progress oflag=direct conv=fsync
```

2–4 minutes. Let `conv=fsync` return before pulling the stick.

The ISO is 25.11 while this flake tracks unstable (26.11pre). That's fine —
`nixos-install` builds the system from the flake's own nixpkgs, not the ISO's.

### Step 2 — Boot it

Tap **ESC** repeatedly as the ASUS logo appears for the boot menu (**F2** is
BIOS setup). Secure Boot is already disabled on this machine. Pick the USB
entry, then "NixOS Installer".

### Step 3 — Install

Connect Wi-Fi from the top-right menu, open a terminal:

```sh
sudo -i
export NIX_CONFIG="experimental-features = nix-command flakes"

lsblk                      # confirm the internal disk is still nvme0n1

git clone https://github.com/fabianAhbeck/nixos /tmp/nixos
cd /tmp/nixos

# Partition, format, mount. Prompts for the LUKS passphrase, twice.
nix run github:nix-community/disko -- --mode destroy,format,mount --flake .#zenbook

# Probe the real hardware. --no-filesystems because disko owns those.
nixos-generate-config --no-filesystems --root /mnt
cp /mnt/etc/nixos/hardware-configuration.nix ./hosts/zenbook/hardware-configuration.nix
git add -A                 # Nix ignores untracked files in a git tree

nixos-install --flake .#zenbook               # ~3-4 GB, 15-30 min
nixos-enter --root /mnt -c 'passwd fabian'    # do not skip
reboot
```

Pull the stick as it reboots.

### Two things that will bite you

- **`passwd fabian` is mandatory.** The config defines the user with no
  password. Skip this and greetd will refuse the login, and fixing it means
  booting the ISO again.
- **The LUKS passphrase has no recovery.** Forget it and the disk is gone.

### First login

tuigreet, then Hyprland. `SUPER+Return` for a terminal, `SUPER+D` for the
launcher, `SUPER+Q` closes a window, `SUPER+SHIFT+Q` exits the session. The
full bind list is in `home/hyprland.nix`.

Then, in rough priority:

1. New SSH key for GitHub — the old one does not survive the wipe:
   `ssh-keygen -t ed25519 -C fabian.ahbeck@irori.se`, add it at
   <https://github.com/settings/keys>, then re-point this repo at
   `git@github.com:fabianAhbeck/nixos.git`.
2. Move the repo from `/tmp/nixos` to `/home/fabian/Projects/nixos`, the path
   `NH_FLAKE` expects.
3. `resume_offset` for hibernation (below).
4. Optionally, a wallpaper (below).

### The untracked-file gotcha

When a flake lives in a git repo, Nix builds from the git tree, **silently
ignoring untracked files**. If you copied the config with `cp -r` and it has no
`.git`, this doesn't apply. But in a clone, a freshly generated
`hardware-configuration.nix` that you forgot to `git add` means Nix quietly uses
the committed placeholder instead — and you get a system that won't boot.

Two ways to avoid it:

- `git add -A` before installing, as Step 3 does, or
- bypass git semantics entirely: `nixos-install --flake path:/tmp/nixos#zenbook`

The `path:` prefix makes Nix copy the directory as-is, untracked files included.

### flake.lock

`flake.lock` is committed, pinning nixpkgs, home-manager, disko and
nixos-hardware to the revisions this config was verified against. The install
will use exactly those. Bump them later with `update`.

## Post-install

### Hibernation

The swapfile exists but resume is not wired up until the kernel knows its
physical offset — which can only be read once the filesystem is real:

```sh
sudo btrfs inspect-internal map-swapfile -r /swap/swapfile
```

Put that number in `hosts/zenbook/default.nix`:

```nix
boot.kernelParams = [ ... "resume_offset=<number>" ];
boot.resumeDevice = "/dev/mapper/cryptroot";
```

Rebuild, reboot, then test with `systemctl hibernate`.

### Wallpaper

The first login gets the NixOS "nineish dark gray" wallpaper. To change it:

```sh
wallpaper ~/Pictures/wallpaper.png
```

`awww-daemon` remembers the last image and restores it at every login.

(`swww` was renamed to `awww` upstream; the daemon binary is `awww-daemon`.)

### Things worth checking on first boot

| Check | Command |
|---|---|
| Hardware video decode | `vainfo` — should report the `iHD` driver |
| Battery threshold applied | `cat /sys/class/power_supply/BAT*/charge_control_end_threshold` → `80` |
| Wi-Fi | `nmcli device status` |
| Suspend | close the lid, reopen |
| Firmware updates | `fwupdmgr refresh && fwupdmgr get-updates` |
| Audio | `wpctl status`, then play something |

## Day to day

```sh
rebuild              # nh os switch — apply config changes
rebuild-test         # apply without adding a boot entry
update               # nix flake update — bump all inputs
gc                   # collect garbage, keep 5 generations / 30 days
nvd diff /run/current-system result    # what changed between builds
```

Roll back a bad rebuild by picking an older generation in the systemd-boot menu.

## Notes on the choices here

- **nixos-unstable, not a release branch.** Hyprland moves fast enough that the
  stable channel is routinely a version or two behind. Swap the `nixpkgs.url`
  in `flake.nix` to `nixos-26.05` if you'd rather have the slower channel.
- **No nixos-hardware profile for the UX425EA.** There isn't one upstream; the
  generic `common-cpu-intel` / `common-pc-laptop` / `common-pc-laptop-ssd`
  modules plus `asus-battery` cover what this machine needs.
- **`/boot` is 1 GB and unencrypted.** It holds kernels and initrds;
  `configurationLimit = 10` keeps it from filling up.
- **TLP, not power-profiles-daemon.** PPD expects a desktop environment to
  switch profiles for it, and there isn't one here.
- **`allowUnfree = true`** rather than a predicate list — Steam alone pulls in
  several separately-named unfree derivations.
- **Snaps are gone.** Everything you had via snap (`code`, `go`, `helm`, `tofu`,
  `nvim`, `rustup`, `discord`, `firefox`, `thunderbird`, `steam`, `postman`,
  `transmission`) is in `modules/dev.nix` or `modules/apps.nix` instead.
