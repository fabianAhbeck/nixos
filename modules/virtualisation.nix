# libvirt/QEMU and Podman. You are in the libvirt group on the current install,
# so virt-manager is carried over.
{ pkgs, ... }:
{
  virtualisation.libvirtd = {
    enable = true;
    qemu = {
      package = pkgs.qemu_kvm;
      runAsRoot = false;
      swtpm.enable = true; # Windows 11 guests want a TPM
      # No ovmf block: the submodule was removed upstream, QEMU now ships the
      # OVMF images by default.
    };
    onBoot = "ignore"; # don't resume VMs on every boot
    onShutdown = "shutdown";
  };

  programs.virt-manager.enable = true;

  # Default NAT network, so a fresh VM gets an address without manual setup.
  virtualisation.libvirtd.allowedBridges = [
    "virbr0"
    "br0"
  ];

  virtualisation.podman = {
    enable = true;
    # `docker` and `docker-compose` resolve to podman. Nothing here installs
    # the real Docker daemon; drop this if you ever want it back.
    dockerCompat = true;
    dockerSocket.enable = true;
    defaultNetwork.settings.dns_enabled = true;
    autoPrune = {
      enable = true;
      dates = "weekly";
      flags = [ "--all" ];
    };
  };

  environment.systemPackages = with pkgs; [
    podman-compose
    podman-tui
    dive # inspect image layers
    skopeo
    virt-viewer
    virtio-win # virtio drivers ISO for Windows guests
  ];

  # Rootless podman needs subuid/subgid ranges.
  users.users.fabian.subUidRanges = [
    {
      startUid = 100000;
      count = 65536;
    }
  ];
  users.users.fabian.subGidRanges = [
    {
      startGid = 100000;
      count = 65536;
    }
  ];

  # Bridged networking for VMs is blocked by the firewall's default rules
  # otherwise.
  networking.firewall.trustedInterfaces = [ "virbr0" ];
}
