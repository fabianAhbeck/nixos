# Clone the repos this config expects (my.repos) if they're missing, e.g. on
# the first login after an install. Fetches over HTTPS, so it works before
# GitHub has an SSH key for this machine; pushes go over SSH. homelab is
# private, so it isn't cloned here.
{
  lib,
  osConfig,
  pkgs,
  ...
}:
let
  clone-repos = pkgs.writeShellApplication {
    name = "clone-repos";
    runtimeInputs = [ pkgs.git ];
    text =
      lib.concatMapStrings
        (
          { path, name }:
          ''
            if [ ! -e ${path} ]; then
              git clone https://github.com/fabianAhbeck/${name} ${path}
              git -C ${path} remote set-url --push origin git@github.com:fabianAhbeck/${name}.git
            fi
          ''
        )
        [
          {
            path = osConfig.my.repos.nixos;
            name = "nixos";
          }
          {
            path = osConfig.my.repos.dotfiles;
            name = "dotfiles";
          }
        ];
  };
in
{
  # Retries until the network is up; does nothing once both exist.
  systemd.user.services.clone-repos = {
    Unit.Description = "Clone missing config repos";
    Service = {
      Type = "oneshot";
      ExecStart = lib.getExe clone-repos;
      Restart = "on-failure";
      RestartSec = 30;
    };
    Install.WantedBy = [ "default.target" ];
  };
}
