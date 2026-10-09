# Bose earbuds/headphones control from the bar, via bosectl
# (https://github.com/aaronsb/bosectl): the Bose BMAP protocol over
# Bluetooth, no app or account. The QC Ultra Earbuds (2nd Gen) are verified
# upstream; status, per-bud battery and mode changes also checked here.
{ pkgs, ... }:
let
  bosectl = pkgs.stdenvNoCC.mkDerivation {
    pname = "bosectl";
    version = "0.5.0";
    src = pkgs.fetchFromGitHub {
      owner = "aaronsb";
      repo = "bosectl";
      rev = "v0.5.0";
      hash = "sha256-NtDgY16mrSzEZoIb2wRUuJ0+xVwBy42or3vSX720vyI=";
    };
    nativeBuildInputs = [ pkgs.makeWrapper ];
    # Pure Python, no dependencies on Linux; the `bosectl` script finds the
    # library in ./python next to itself.
    installPhase = ''
      mkdir -p $out/share/bosectl $out/bin
      cp -r bosectl python $out/share/bosectl/
      makeWrapper ${pkgs.python3}/bin/python3 $out/bin/bosectl \
        --add-flags $out/share/bosectl/bosectl
    '';
  };

  waybar-bose = pkgs.writeShellApplication {
    name = "waybar-bose";
    runtimeInputs = with pkgs; [
      bluez
      python3
    ];
    runtimeEnv = {
      WAYBAR_BOSE_PY = ./scripts/waybar-bose.py;
      PYTHONPATH = "${bosectl}/share/bosectl/python"; # pybmap
    };
    text = builtins.readFile ./scripts/waybar-bose.sh;
  };

  bose-mode = pkgs.writeShellApplication {
    name = "bose-mode";
    runtimeInputs = with pkgs; [
      bosectl
      wofi
      gnused
      procps
    ];
    text = builtins.readFile ./scripts/bose-mode.sh;
  };
in
{
  home.packages = [
    bosectl
    bose-mode
  ];

  # Listed in modules-right in waybar.nix. Hidden while no Bose device is
  # connected; refreshed every 30 s and right after bose-mode (signal 8).
  programs.waybar.settings.mainBar."custom/bose" = {
    exec = "${waybar-bose}/bin/waybar-bose";
    return-type = "json";
    interval = 30;
    signal = 8;
    on-click = "bose-mode toggle";
    on-click-right = "bose-mode menu";
  };
}
