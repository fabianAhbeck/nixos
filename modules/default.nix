# Everything shared between machines. flake.nix adds this to every host.
{
  imports = [
    ./host.nix
    ./common.nix
    ./nix.nix
    ./desktop.nix
    ./dev.nix
    ./apps.nix
    ./virtualisation.nix
  ];
}
