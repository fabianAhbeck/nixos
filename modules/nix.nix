# Nix daemon settings, garbage collection, and the unfree policy.
{
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

      # 8 threads on the i7-1165G7. Leaving max-jobs at auto and capping cores
      # keeps the laptop usable during a big rebuild.
      max-jobs = "auto";
      cores = 6;

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

    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
      # Don't run GC on battery.
      persistent = true;
    };

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
    nh # nicer `nixos-rebuild` wrapper, see the alias in home/shell.nix
    nix-output-monitor
    nvd # diff two generations: `nvd diff /run/current-system result`
    nix-tree
  ];

  # `nh os switch` looks here for the flake when you don't pass a path.
  environment.sessionVariables.NH_FLAKE = "/home/fabian/Projects/nixos";

  # Documentation costs build time and disk; keep man pages, drop the rest.
  documentation = {
    enable = true;
    man.enable = true;
    doc.enable = false;
    info.enable = false;
  };
}
