# Nix daemon settings, garbage collection, and the unfree policy.
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
{
  nix = {
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];

      # Build cores are capped per machine (hosts/<name>/) so it stays usable
      # during a big rebuild.
      max-jobs = "auto";

      # Nothing here should ever build glibc from source.
      substituters = [
        "https://cache.nixos.org"
        "https://nix-community.cachix.org"
        "https://hyprland.cachix.org"
      ];
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
      ];

      trusted-users = [
        "root"
        "fabian"
      ];

      auto-optimise-store = true;
      warn-dirty = false;
    };

    # Keep the flake's nixpkgs as the system channel, so `nix shell nixpkgs#foo`
    # and the flake agree on a revision.
    registry.nixpkgs.flake = inputs.nixpkgs;
    nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];

    optimise.automatic = true;
  };

  # Personal laptop: Steam, Discord, VS Code, Claude Code and the Intel
  # microcode are all unfree. Flipping the whole switch rather than
  # maintaining a predicate list that Steam alone would blow up.
  nixpkgs.config.allowUnfree = true;

  # Rebuilds should not be silently reverted by a stale channel.
  system.autoUpgrade.enable = false;

  environment.systemPackages = with pkgs; [
    git # needed before home-manager's git is on PATH, e.g. in a rescue shell
    nix-output-monitor
    nvd # diff two generations: `nvd diff /run/current-system result`
    nix-tree
  ];

  # nh: the `nixos-rebuild` wrapper behind `rebuild`. `flake` sets NH_FLAKE,
  # so `nh os switch` finds the repo without a path. `clean` replaces
  # nix.gc: it also prunes old generations (and their boot entries) while
  # always keeping the last few.
  programs.nh = {
    enable = true;
    flake = config.my.repos.nixos;
    clean = {
      enable = true;
      dates = "weekly";
      extraArgs = "--keep 5 --keep-since 30d";
    };
  };

  # Documentation costs build time and disk; keep man pages, drop the rest.
  documentation = {
    enable = true;
    man.enable = true;
    doc.enable = false;
    info.enable = false;
  };
}
