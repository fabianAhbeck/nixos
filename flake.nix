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
      disko,
      home-manager,
      ...
    }@inputs:
    let
      # A machine is hosts/<name>/ (hardware, disk layout, my.* settings)
      # plus everything shared in modules/. Adding one is a new folder and a
      # line below; see "Adding a machine" in README.md.
      mkHost =
        name:
        nixpkgs.lib.nixosSystem {
          # No `system` here on purpose: nixpkgs.hostPlatform is set in each
          # host's hardware-configuration.nix, and setting both conflicts.
          specialArgs = { inherit inputs; };
          modules = [
            disko.nixosModules.disko
            home-manager.nixosModules.home-manager
            ./modules
            ./hosts/${name}
          ];
        };
    in
    {
      nixosConfigurations.zenbook = mkHost "zenbook";

      # Convenience: `nix fmt`
      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixfmt-tree;
    };
}
