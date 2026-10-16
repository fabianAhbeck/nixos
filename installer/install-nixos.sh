# install-nixos [host]: install one of this flake's machines from the live
# ISO (installer/default.nix). Clones the repo, wipes and partitions the disk
# from hosts/<host>/disko.nix, probes the hardware, installs, asks for the
# user's password and leaves the clone in ~/Projects/nixos. Re-running reuses
# /tmp/nixos, so a fix made there (e.g. the disk in disko.nix) is kept.
repo=https://github.com/fabianAhbeck/nixos
push=git@github.com:fabianAhbeck/nixos.git
src=/tmp/nixos
user=fabian

step() { printf '\n\e[1;34m==> %s\e[0m\n' "$*"; }
die() { printf '\e[1;31m%s\e[0m\n' "$*" >&2; exit 1; }

[ "$(id -u)" = 0 ] || die "Run as root: sudo install-nixos"

if [ ! -d "$src/.git" ]; then
  step "Cloning $repo"
  git clone "$repo" "$src" || die "Clone failed. Connect with nmtui first."
fi
cd "$src"

host=${1:-}
if [ -z "$host" ]; then
  mapfile -t hosts < <(ls hosts)
  PS3="Machine to install: "
  select host in "${hosts[@]}"; do [ -n "$host" ] && break; done
fi
[ -d "hosts/$host" ] || die "No hosts/$host in the repo."

step "Disk layout for $host"
disks=$(nix eval --raw ".#nixosConfigurations.$host.config.disko.devices.disk" \
  --apply 'ds: builtins.concatStringsSep " " (map (d: d.device) (builtins.attrValues ds))')
lsblk -o NAME,SIZE,TYPE,MODEL,MOUNTPOINTS
printf '\nhosts/%s/disko.nix will ERASE: \e[1;31m%s\e[0m\n' "$host" "$disks"
echo "If that's the wrong disk, answer no, fix it in $src/hosts/$host/disko.nix and run again."
read -rp "Type the host name ($host) to wipe it: " answer
[ "$answer" = "$host" ] || die "Not confirmed; nothing was changed."

step "Partitioning (asks for the new LUKS passphrase)"
disko --mode destroy,format,mount --yes-wipe-all-disks --flake ".#$host"

step "Probing the hardware"
# --no-filesystems: disko.nix owns fileSystems and swapDevices.
nixos-generate-config --no-filesystems --root /mnt --show-hardware-config \
  >"hosts/$host/hardware-configuration.nix"
git add -A # Nix ignores untracked files in a git tree
git --no-pager diff --cached --stat

step "Installing $host"
nixos-install --flake ".#$host" --no-root-passwd

step "Password for $user"
until nixos-enter --root /mnt -c "passwd $user"; do echo "Try again."; done

step "Putting the repo in ~/Projects/nixos"
# Fetches over HTTPS without a key; pushes over SSH once one is on GitHub.
git remote set-url --push origin "$push"
mkdir -p "/mnt/home/$user/Projects"
cp -a "$src" "/mnt/home/$user/Projects/nixos"
nixos-enter --root /mnt -c "chown -R $user:users /home/$user/Projects"

step "Done"
cat <<EOF
After the first login:
  - gh auth login (it can upload a new SSH key), so pushes work
  - in ~/Projects/nixos, commit and push hosts/$host/hardware-configuration.nix
    if the diff above changed it
The dotfiles repo is cloned at the first login (home/repos.nix).
EOF
read -rp "Reboot now? [Y/n] " answer
[[ "$answer" =~ ^[Nn] ]] || reboot
