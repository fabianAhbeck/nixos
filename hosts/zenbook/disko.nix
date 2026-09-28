# Declarative disk layout. This is what actually partitions and formats the
# drive during installation (see README.md), and it is also the source of
# truth for `fileSystems` / `swapDevices` afterwards -- which is why
# hardware-configuration.nix must be generated with `--no-filesystems`.
#
#   nvme0n1
#   ├─ p1  1G     ESP (vfat)  -> /boot
#   └─ p2  rest   LUKS2       -> cryptroot
#        └─ btrfs
#           ├─ @          -> /
#           ├─ @home      -> /home
#           ├─ @nix       -> /nix          (noatime, no compression accounting churn)
#           ├─ @log       -> /var/log
#           ├─ @snapshots -> /.snapshots
#           └─ @swap      -> /swap/swapfile (34G, sized for hibernate)
_:
{
  disko.devices.disk.main = {
    # Verify with `lsblk` before installing -- on the live ISO this should
    # still be nvme0n1, but check rather than assume.
    device = "/dev/nvme0n1";
    type = "disk";
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          priority = 1;
          name = "ESP";
          size = "1G";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            # The ESP holds unencrypted kernels + initrds; keep it root-only.
            mountOptions = [ "umask=0077" ];
          };
        };

        luks = {
          size = "100%";
          content = {
            type = "luks";
            name = "cryptroot";
            # Pass TRIM through to the SSD. Slight metadata leak (reveals how
            # much of the disk is in use); worth it for NVMe longevity.
            settings.allowDiscards = true;
            # Uncomment to keep a keyfile in the initrd instead of typing the
            # passphrase twice when you add TPM unlock later.
            # settings.crypttabExtraOpts = [ "tpm2-device=auto" ];

            content = {
              type = "btrfs";
              extraArgs = [
                "-L"
                "nixos"
                "-f"
              ];

              subvolumes = {
                "@" = {
                  mountpoint = "/";
                  mountOptions = [
                    "compress=zstd:1"
                    "noatime"
                  ];
                };

                "@home" = {
                  mountpoint = "/home";
                  mountOptions = [
                    "compress=zstd:1"
                    "noatime"
                  ];
                };

                "@nix" = {
                  mountpoint = "/nix";
                  mountOptions = [
                    "compress=zstd:1"
                    "noatime"
                  ];
                };

                "@log" = {
                  mountpoint = "/var/log";
                  mountOptions = [
                    "compress=zstd:1"
                    "noatime"
                  ];
                };

                # Target for btrfs snapshots. Kept as its own subvolume so a
                # rollback of @ does not take the snapshots with it.
                "@snapshots" = {
                  mountpoint = "/.snapshots";
                  mountOptions = [
                    "compress=zstd:1"
                    "noatime"
                  ];
                };

                # 34G: slightly more than the 31GiB of RAM, so hibernation has
                # room even with a full page cache. disko uses
                # `btrfs filesystem mkswapfile`, which sets NODATACOW for us.
                "@swap" = {
                  mountpoint = "/swap";
                  mountOptions = [ "noatime" ];
                  swap.swapfile.size = "34G";
                };
              };
            };
          };
        };
      };
    };
  };
}
