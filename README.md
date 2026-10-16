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
| `update` | `nix flake update`, rebuild, then commit and push `flake.lock`; a failed rebuild puts the old one back |
| `gc` | delete old generations now (also runs weekly, keeping the last 5 and anything from the last 30 days) |
| `nvd diff /run/current-system result` | what changed between two builds |

Roll back a bad rebuild by picking an older generation in the systemd-boot
menu.

**New files must be `git add`ed** (or at least `git add -N`) before a
rebuild: Nix builds from the git tree and silently ignores untracked files.

## Layout

```
flake.nix                 inputs; mkHost builds each machine from modules/ + hosts/<name>/
installer/                the USB installer ISO and its install-nixos script
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
  repos.nix               clones this repo and dotfiles at login if they're missing
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

The USB installer (`installer/`) is the minimal NixOS ISO plus
`install-nixos`, which does the whole install for one of the hosts here.

1. **Build the ISO and write it to a stick.** Check the stick's device with
   `lsblk` right before writing — `/dev/sdX` versus the internal disk is the
   difference between losing a stick and losing the machine:

   ```sh
   nix build .#installer-iso
   iso=(result/iso/*.iso)   # the glob doesn't expand inside if=...
   sudo dd if=$iso of=/dev/sdX bs=4M status=progress oflag=direct conv=fsync
   ```

   The ISO doesn't need rebuilding when the config changes: the script clones
   the repo's current `main`, and `nixos-install` builds from its pinned
   nixpkgs. Rebuild it for a newer kernel (Wi-Fi drivers) or a changed script.

2. **Boot it** from the firmware's boot menu, with Secure Boot off.

3. **Install:** `nmtui` to connect to Wi-Fi, then `sudo install-nixos`. It:
   - clones the repo to `/tmp/nixos` and asks which host to install
   - shows `lsblk` and the disk `hosts/<name>/disko.nix` will erase, and wipes
     it only after you type the host name. Wrong disk: answer no, fix it in
     `/tmp/nixos/hosts/<name>/disko.nix` and run it again (the clone is reused)
   - partitions with disko, asking for the new LUKS passphrase
   - writes `hardware-configuration.nix` from the real hardware and `git add`s it
   - runs `nixos-install`, asks for fabian's password, copies the clone to
     `~/Projects/nixos` and offers to reboot

4. **After the first login:** `gh auth login` (it can upload a new SSH key),
   then commit and push `hosts/<name>/hardware-configuration.nix` if the
   install changed it. The clones fetch over HTTPS and push over SSH. The
   dotfiles repo is cloned at login by `home/repos.nix` (as is this one, if
   `~/Projects/nixos` is ever missing); homelab is private, so clone that by
   hand once the key works.

Things that bite:

- **Always use the generated `hardware-configuration.nix`**, never one written
  for other hardware. zenbook's first committed copy lacked the `vmd` initrd
  module its NVMe sits behind, and every generation built from it hung before
  the LUKS prompt. `install-nixos` always regenerates it.
- **The LUKS passphrase has no recovery.**
- **A failed install** can be re-run from the start: it wipes and
  partitions again. The user has no password in the config, so if the script
  stops after `nixos-install`, run `nixos-enter --root /mnt -c 'passwd fabian'`
  before rebooting, or the greeter refuses the login.

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
