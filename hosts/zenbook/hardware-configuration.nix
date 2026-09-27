# Hardware detected by nixos-generate-config during the install. The file
# committed at first was a placeholder probed from the old Ubuntu install,
# and it lacked `vmd`: on this laptop the NVMe drive sits behind Intel VMD,
# so without that module the initrd never sees the disk and boot hangs
# before the LUKS prompt. Regenerate (as root) with:
#
#   nixos-generate-config --no-filesystems --show-hardware-config
#
# `--no-filesystems` matters: disko.nix owns fileSystems and swapDevices.
{
  config,
  lib,
  modulesPath,
  ...
}:
{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "thunderbolt"
    "vmd" # NVMe is behind Intel VMD; without it the disk never appears
    "nvme"
    "usb_storage"
    "sd_mod"
    "rtsx_pci_sdmmc" # SD card reader
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
