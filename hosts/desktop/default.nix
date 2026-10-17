# Desktop: Intel CPU, NVIDIA GPU (Turing or newer), 5120x1440 ultrawide,
# Wi-Fi. Everything shared with other machines comes from ../../modules
# (added by mkHost in flake.nix); this file is only what is specific to it.
{
  config,
  inputs,
  pkgs,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
    ./disko.nix

    # cpu-only: microcode without the Intel iGPU drivers; the NVIDIA card
    # drives the screens.
    inputs.nixos-hardware.nixosModules.common-cpu-intel-cpu-only
    inputs.nixos-hardware.nixosModules.common-gpu-nvidia-nonprime
    inputs.nixos-hardware.nixosModules.common-pc
    inputs.nixos-hardware.nixosModules.common-pc-ssd
  ];

  networking.hostName = "desktop";

  my = {
    monitors = [
      # Verified with `hyprctl monitors all` after the first boot: the
      # ultrawide is on DP-3 and offers 5120x1440 at 120, 100 and 60 Hz. A
      # wrong output name only means Hyprland picks the preferred mode at
      # scale 1 by itself (which was 3840x1080 here).
      {
        output = "DP-3";
        mode = "5120x1440@120";
        position = "0x0";
        scale = 1;
      }
    ];
    backlight = null;
    laptop = false;
  };

  ###########################################################################
  # Graphics -- NVIDIA
  ###########################################################################

  # The LTS kernel rather than the newest one (modules/common.nix): the
  # NVIDIA driver is built against the kernel, and it is often a little
  # behind brand-new kernels on unstable.
  boot.kernelPackages = pkgs.linuxPackages;

  hardware.nvidia = {
    # The open kernel module: NVIDIA's recommended one from Turing on.
    open = true;
    modesetting.enable = true; # required by Wayland compositors
    package = config.boot.kernelPackages.nvidiaPackages.stable;
    # Save video memory across suspend, or apps come back to a black or
    # corrupted screen.
    powerManagement.enable = true;
  };

  # Hardware video decode (VA-API) in Firefox and mpv, through NVDEC.
  hardware.graphics.extraPackages = [ pkgs.nvidia-vaapi-driver ];

  environment.sessionVariables = {
    LIBVA_DRIVER_NAME = "nvidia";
    NVD_BACKEND = "direct"; # nvidia-vaapi-driver's EGL backend is broken
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
  };

  ###########################################################################
  # The version of NixOS this machine was first installed with. Do NOT bump it
  # on upgrade -- it pins stateful defaults (database versions and the like).
  ###########################################################################
  system.stateVersion = "26.11";
}
