# NixOS — ASUS ZenBook UX425EA

Flake-based NixOS config for `zenbook`: Intel i7-1165G7 (Tiger Lake), 32 GB RAM,
1 TB NVMe, Iris Xe graphics, Wi-Fi 6 AX201.

Hyprland on Wayland, LUKS + btrfs, Home Manager, Swedish keyboard with an
English UI.

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

## Before you wipe the machine

1. **Back up.** The install destroys everything on `/dev/nvme0n1`. At minimum:
   `~/.ssh`, `~/.gnupg`, `~/.config`, browser profiles, any VM images under
   `/var/lib/libvirt`, and anything not already pushed to a remote.
2. **Push this repo somewhere you can reach from the installer** (GitHub, or a
   USB stick — it's small).
3. Write a NixOS ISO (the graphical one is convenient because it has a browser
   and Wi-Fi tooling): https://nixos.org/download

## Getting the config onto the installer

The repo is public at <https://github.com/fabianAhbeck/nixos>, so the ISO can
clone it directly — no credentials needed:

```sh
nix-shell -p git --run 'git clone https://github.com/fabianAhbeck/nixos /tmp/nixos'
```

Nothing in this config is secret, so public is fine. If you'd rather flip it
back to private after the install, you can — the installer is the only step
that needs to read it, and the alternatives are a copy on the USB stick,
`gh auth login` with the device flow, a read-only fine-grained PAT, or a
throwaway SSH key.

## Install

Boot the ISO, get networking up (`nmtui` for Wi-Fi), get the config onto the
machine as above, then:

```sh
sudo -i
cd /tmp/nixos

# 1. Confirm the disk is still nvme0n1 before disko eats it
lsblk

# 2. Partition, format and mount. Prompts for the LUKS passphrase.
#    --mode destroy,format,mount does exactly what it says.
nix --experimental-features "nix-command flakes" run github:nix-community/disko -- \
  --mode destroy,format,mount \
  --flake .#zenbook

# 3. Regenerate hardware-configuration.nix for the real machine.
#    --no-filesystems is required: disko.nix owns fileSystems/swapDevices.
nixos-generate-config --no-filesystems --root /mnt
cp /mnt/etc/nixos/hardware-configuration.nix ./hosts/zenbook/hardware-configuration.nix

# 4. IMPORTANT: if /tmp/nixos is a git clone, Nix ignores untracked files.
#    Stage everything so the flake actually sees it.
git add -A

# 5. Install
nixos-install --flake .#zenbook

# 6. Set the user password, then reboot
nixos-enter --root /mnt -c 'passwd fabian'
reboot
```

### The untracked-file gotcha

When a flake lives in a git repo, Nix builds from the git tree, **silently
ignoring untracked files**. If you copied the config with `cp -r` and it has no
`.git`, this doesn't apply. But in a clone, a freshly generated
`hardware-configuration.nix` that you forgot to `git add` means Nix quietly uses
the committed placeholder instead — and you get a system that won't boot.

Two ways to avoid it:

- `git add -A` before installing (step 4 above), or
- bypass git semantics entirely: `nixos-install --flake path:/tmp/nixos#zenbook`

The `path:` prefix makes Nix copy the directory as-is, untracked files included.

### flake.lock

`flake.lock` is committed, pinning nixpkgs, home-manager, disko and
nixos-hardware to the revisions this config was verified against. The install
will use exactly those. Bump them later with `update`.

## After the first boot

Move the repo to `/home/fabian/project/nixos` (the path `NH_FLAKE` points at),
set up an SSH key for GitHub so you can push again, and rebuild with `rebuild`.

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

`swww` runs but starts blank. Drop an image and set it:

```sh
swww img ~/Pictures/wallpaper.png
```

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
