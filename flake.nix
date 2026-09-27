{
  description = "Fabian's NixOS configuration (ASUS ZenBook UX425EA)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      nixos-hardware,
      disko,
      home-manager,
      ...
    }@inputs:
    {
      nixosConfigurations.zenbook = nixpkgs.lib.nixosSystem {
        # No `system` here on purpose: nixpkgs.hostPlatform is set in
        # hosts/zenbook/hardware-configuration.nix, and setting both conflicts.
        specialArgs = { inherit inputs; };
        modules = [
          disko.nixosModules.disko
          home-manager.nixosModules.home-manager

          # No nixos-hardware profile exists for the UX425EA specifically, so we
          # compose the generic ones. asus-battery gives us the charge threshold.
          nixos-hardware.nixosModules.common-cpu-intel
          nixos-hardware.nixosModules.common-pc-laptop
          nixos-hardware.nixosModules.common-pc-laptop-ssd
          nixos-hardware.nixosModules.asus-battery

          ./hosts/zenbook
        ];
      };

      # Convenience: `nix fmt`
      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixfmt-tree;
    };
}
