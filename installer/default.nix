# USB installer: the minimal NixOS ISO plus `install-nixos <host>`, which
# installs one of this flake's machines (see "Installing on a machine" in
# README.md). Build with `nix build .#installer-iso`.
#
# Not built from ../modules: this is the live system, not a machine.
{
  inputs,
  lib,
  modulesPath,
  pkgs,
  ...
}:
{
  imports = [ (modulesPath + "/installer/cd-dvd/installation-cd-minimal.nix") ];

  nixpkgs.hostPlatform = "x86_64-linux";

  # Newest kernel, so Wi-Fi chips newer than the LTS kernel work. ZFS is
  # usually behind it and none of the machines use it.
  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.supportedFilesystems.zfs = lib.mkForce false;

  # Wi-Fi firmware that isn't redistributable (some Intel and MediaTek
  # cards), same as the installed machines.
  nixpkgs.config.allowUnfree = true;
  hardware.enableAllFirmware = true;

  # NetworkManager: `nmtui` to connect. It turns networking.wireless on
  # itself, to drive wpa_supplicant over D-Bus -- don't force that off, or
  # every Wi-Fi card stays "unavailable".
  networking.networkmanager.enable = true;

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  console.keyMap = "sv-latin1";

  environment.systemPackages = [
    pkgs.git
    inputs.disko.packages.${pkgs.stdenv.hostPlatform.system}.disko
    (pkgs.writeShellApplication {
      name = "install-nixos";
      runtimeInputs = with pkgs; [
        git
        util-linux # lsblk
        nixos-install-tools
        inputs.disko.packages.${pkgs.stdenv.hostPlatform.system}.disko
      ];
      text = builtins.readFile ./install-nixos.sh;
    })
  ];

  # Say what to do at the login prompt.
  services.getty.helpLine = lib.mkForce ''

    Install one of the machines in github.com/fabianAhbeck/nixos:
      nmtui                    connect to Wi-Fi (not needed on a cable)
      sudo install-nixos       pick a host, then confirm the disk
  '';

  isoImage.squashfsCompression = "zstd -Xcompression-level 6"; # faster builds
}
