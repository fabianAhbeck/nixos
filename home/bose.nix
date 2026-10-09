# Bose earbuds/headphones control from the bar, via bosectl
# (https://github.com/alabalag1/bosectl): the Bose BMAP protocol over
# Bluetooth, no app or account. The QC Ultra 2 Earbuds aren't in its
# tested list but answer as the QC Ultra Headphones 2 do: status and mode
# changes read back correctly (tested 2026-10).
{ pkgs, ... }:
let
  bosectl = pkgs.stdenvNoCC.mkDerivation {
    pname = "bosectl";
    version = "0.1.0-unstable-2026-10-09";
    src = pkgs.fetchFromGitHub {
      owner = "alabalag1";
      repo = "bosectl";
      rev = "1d2a8791f9ccfce3f7c78b52c8cf796673e12ffc";
      hash = "sha256-IvSIZH5aBtrzNGrgP1fKKvv7Hx6CzTD5wFx4RSrt5iI=";
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
      bosectl
      bluez
      jq
      gawk
      gnused
    ];
    text = builtins.readFile ./scripts/waybar-bose.sh;
  };

  bose-mode = pkgs.writeShellApplication {
    name = "bose-mode";
    runtimeInputs = with pkgs; [
      bosectl
      wofi
      gawk
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
