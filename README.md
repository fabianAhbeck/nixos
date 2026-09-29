# NixOS config

Flake-based NixOS + Home Manager configuration for my machines: Hyprland on
Wayland, Catppuccin Mocha throughout, LUKS + btrfs, Swedish keyboard with an
English UI.

Keybindings and handy commands: [KEYBINDINGS.md](KEYBINDINGS.md).

| Host | Machine | Notes |
|---|---|---|
| `zenbook` | ASUS ZenBook UX425EA — i7-1165G7 (Tiger Lake), Iris Xe, 32 GB, 1 TB NVMe, 1080p panel | laptop: TLP, battery limit, hibernation, home VPN |
| — | desktop (NVIDIA, ultrawide) | planned; see [Adding a machine](#adding-a-machine) |

## Day to day

| | |
|---|---|
| `SUPER + SHIFT + R` | rebuild in the background; a notification tracks it, a password dialog appears when the build is done |
| `rebuild` | the same in a terminal (`nh os switch`) |
| `rebuild-test` | apply without adding a boot entry |
| `rebuild-boot` | only on next boot — use this when changing the greeter, which a live switch can't restart safely |
| `update` | `nix flake update`, then rebuild |
| `gc` | delete old generations now (also runs weekly, keeping the last 5 and anything from the last 30 days) |
| `nvd diff /run/current-system result` | what changed between two builds |

Roll back a bad rebuild by picking an older generation in the systemd-boot
menu.

**New files must be `git add`ed** (or at least `git add -N`) before a
rebuild: Nix builds from the git tree and silently ignores untracked files.

## Layout

```
flake.nix                 inputs; mkHost builds each machine from modules/ + hosts/<name>/
hosts/<name>/             everything specific to one machine:
  default.nix             my.* values, GPU drivers, power, machine-only services
  disko.nix               declarative partitioning
  hardware-configuration.nix   generated on the machine (see Installing)
modules/                  shared by every machine (default.nix imports them all)
  host.nix                my.* options: monitors, backlight, laptop, repo paths
  common.nix              boot, networking, locale + console, user, sudo, Home Manager
  nix.nix                 nix daemon, nh + cleanup, caches, allowUnfree
  desktop.nix             Hyprland, greeter, portals, pipewire, graphics, fonts
  dev.nix                 Go, Rust, Node, Python, k8s, tofu, claude-code, CLI
  apps.nix                Firefox, Thunderbird, Discord, VLC, VS Code, Steam
  virtualisation.nix      libvirt/virt-manager, podman
home/                     Home Manager; reads my.* as osConfig.my
  fabian.nix              git, kitty, neovim (config from the dotfiles repo), mako, wofi,
                          hyprlock, hypridle, theming
  hyprland.nix/.lua       compositor config and key bindings (gets a `host` table from my.*)
  waybar.nix              status bar, calendar popup, temperature module
  shell.nix               zsh, starship, fzf, tmux, aliases
  scripts/                shell scripts built into the config
```

## Adding a machine

1. `hosts/<name>/default.nix` with `networking.hostName`, `system.stateVersion`,
   the hardware bits (GPU drivers, nixos-hardware profiles, power) and the
   `my.*` settings: `monitors` (from `hyprctl monitors`), `backlight` (null on
   a desktop) and `laptop`. `hosts/zenbook/default.nix` is the worked example.
2. `hosts/<name>/disko.nix` (adapt zenbook's) and `hardware-configuration.nix`,
   generated on the machine as below.
3. One line in `flake.nix`: `nixosConfigurations.<name> = mkHost "<name>";`

For the planned desktop: `hardware.nvidia` with the open kernel module and
`services.xserver.videoDrivers = [ "nvidia" ]`, `my.monitors` with the
ultrawide's mode and refresh rate (its scale steps come out as 1 / 1.25 /
1.33 / 1.6 / 2), and none of zenbook's laptop power, hibernation or VPN
settings.

## Installing on a machine

1. **Write a NixOS ISO to a USB stick.** The graphical ISO is easiest (browser,
   GUI Wi-Fi). Its version doesn't matter: `nixos-install` builds from this
   flake's pinned nixpkgs. Check the stick's device with `lsblk` right before
   writing — `/dev/sdX` versus the internal disk is the difference between
   losing a stick and losing the machine:

   ```sh
   sudo dd if=nixos-graphical-*.iso of=/dev/sdX bs=4M status=progress oflag=direct conv=fsync
   ```

2. **Boot it** from the firmware's boot menu, with Secure Boot off.

3. **Install**, from a root shell on the live system:

   ```sh
   export NIX_CONFIG="experimental-features = nix-command flakes"
   git clone https://github.com/fabianAhbeck/nixos /tmp/nixos && cd /tmp/nixos
   lsblk                                    # confirm the target disk in hosts/<name>/disko.nix

   # Partition, format, mount (prompts for the LUKS passphrase).
   nix run github:nix-community/disko -- --mode destroy,format,mount --flake .#<name>

   # Probe the real hardware; --no-filesystems because disko owns those.
   nixos-generate-config --no-filesystems --root /mnt
   cp /mnt/etc/nixos/hardware-configuration.nix hosts/<name>/
   git add -A

   nixos-install --flake .#<name>
   nixos-enter --root /mnt -c 'passwd fabian'
   reboot
   ```

4. **After the first login:** add an SSH key to GitHub and point the clone at
   `git@github.com:fabianAhbeck/nixos.git`; move it to `~/Projects/nixos`
   (`my.repos.nixos`); then rebuild once.

Things that bite:

- **Always use the generated `hardware-configuration.nix`**, never one written
  for other hardware. zenbook's first committed copy lacked the `vmd` initrd
  module its NVMe sits behind, and every generation built from it hung before
  the LUKS prompt.
- **`passwd` before rebooting.** The user has no password in the config; skip
  it and the greeter refuses the login until you boot the ISO again.
- **The LUKS passphrase has no recovery.**
- **`git add` the generated files.** Nix ignores untracked files in a git
  tree; `nixos-install --flake path:/tmp/nixos#<name>` sidesteps that.

## Per-machine notes: zenbook

### Hibernation

Resume from the btrfs swapfile needs the file's physical offset:

```sh
sudo btrfs inspect-internal map-swapfile -r /swap/swapfile
```

That number is `resume_offset` in `hosts/zenbook/default.nix`, with
`boot.resumeDevice = "/dev/mapper/cryptroot"`. Update it if the swapfile is
ever recreated (e.g. after a reinstall).

### Home VPN

`home-vpn` (OpenVPN) connects automatically whenever a network comes up,
except on the home Wi-Fi ("Calaverea Cafe"), where it's disconnected. The
logic is a NetworkManager dispatcher script in `hosts/zenbook/default.nix`.
The server is UniFi's OpenVPN server on TCP 1194, reached as
`vpn.leafer.site` (kept current by UniFi's dynamic DNS).

The connection holds keys and a password, so it's imported into
NetworkManager (root-only, `/etc/NetworkManager/system-connections`) rather
than kept in this repo:

```sh
nmcli connection import type openvpn file Client.ovpn
nmcli connection modify Client connection.id home-vpn \
  +vpn.data "remote=vpn.leafer.site:1194, password-flags=0"
nm-connection-editor   # home-vpn → VPN: username + password
```

`password-flags=0` stores the password with the connection, so the script can
connect before anyone logs in. Delete the `.ovpn` afterwards; its private key
now lives in NetworkManager. `nmcli connection up|down home-vpn` still work by
hand.

### First-boot checks

| Check | Command |
|---|---|
| Hardware video decode | `vainfo` — should report the `iHD` driver |
| Battery threshold applied | `cat /sys/class/power_supply/BAT*/charge_control_end_threshold` → `80` |
| Wi-Fi | `nmcli device status` |
| Suspend / hibernate | close the lid; power menu → Hibernate |
| Firmware updates | `fwupdmgr refresh && fwupdmgr get-updates` |
| Audio | `wpctl status`, then play something |

## Customising

- **Wallpaper:** `wallpaper ~/Pictures/wallpaper.png`. The first login gets
  the NixOS "nineish dark gray" image; awww restores the last one set at every
  login.
- **Screen scale:** `SUPER + plus/minus` steps it live; the default is the
  monitor's `scale` in `my.monitors`.
- **Neovim** is configured in the dotfiles repo (`~/Projects/dotfiles`);
  `~/.config/nvim` links there, so edits apply without a rebuild.

## Notes on the choices here

- **nixos-unstable, not a release branch.** Hyprland moves fast enough that the
  stable channel is routinely a version or two behind. Swap `nixpkgs.url` in
  `flake.nix` to a release branch for the slower channel.
- **`/boot` is 1 GB and unencrypted.** It holds kernels and initrds;
  `configurationLimit = 10` keeps it from filling up.
- **TLP on laptops, not power-profiles-daemon.** PPD expects a desktop
  environment to switch profiles for it, and there isn't one here.
- **`allowUnfree = true`** rather than a predicate list — Steam alone pulls in
  several separately-named unfree derivations.
- **Secrets stay out of the repo.** The VPN profile lives in NetworkManager;
  SSH keys and similar are per machine.
