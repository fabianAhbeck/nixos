# Development toolchain. Language servers, formatters and editor plugins that
# are personal rather than machine-wide live in home/fabian.nix instead.
{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    ###########################################################################
    # Languages / toolchains
    ###########################################################################
    go
    gopls
    gotools

    # rustup rather than the `rust-bin` packages: project toolchain files
    # (rust-toolchain.toml) are common and rustup is what honours them.
    rustup

    # Language servers the nvim config (dotfiles repo) enables. Mason can
    # also install these; having them here means they work offline too.
    lua-language-server
    tflint
    # nvim-treesitter's main branch builds parsers with the tree-sitter CLI
    # (plus gcc, below).
    tree-sitter

    nodejs_22
    pnpm
    typescript-language-server

    (python3.withPackages (
      ps: with ps; [
        requests
        pyyaml
        virtualenv
      ]
    ))
    ruff
    uv

    # Build essentials -- needed by cargo/cgo/node-gyp, not implied by the above
    gcc
    gnumake
    pkg-config
    openssl

    ###########################################################################
    # Kubernetes / infrastructure -- matches what you run on Ubuntu today
    ###########################################################################
    kubectl
    kubelogin-oidc # `kubectl oidc-login`: OIDC tokens (browser login) for the leafer cluster
    kubectx
    kubernetes-helm
    k9s
    stern
    kustomize
    opentofu
    terraform-ls
    ansible

    awscli2
    azure-cli
    google-cloud-sdk

    ###########################################################################
    # CLI
    ###########################################################################
    claude-code
    gh
    lazygit
    git-lfs
    delta # side-by-side diffs, wired into git in home/fabian.nix
    jq
    yq-go
    ripgrep
    fd
    fzf
    bat
    eza
    tree
    htop
    btop
    curl
    wget
    unzip
    p7zip
    file
    dig
    nmap
    socat
    tcpdump
    usbutils
    pciutils
    nfs-utils # you have nfs-common installed today

    ###########################################################################
    # Nix tooling
    ###########################################################################
    nixfmt
    nixd # language server
    statix # lints
    deadnix
  ];

  # direnv is configured per-user in home/shell.nix, so the shell hook is
  # only installed once.

  # Run unpatched prebuilt binaries: Mason's language servers, blink.cmp's
  # fuzzy matcher, and the odd vendor CLI. Without it they fail with
  # "No such file or directory" because there is no /lib64/ld-linux.
  programs.nix-ld.enable = true;

  programs.zsh.enable = true; # must be enabled system-wide to be a login shell

  # Claude Code's nixpkgs wrapper already sets DISABLE_AUTOUPDATER=1 -- the
  # store is read-only, so self-update would fail. Updates come from
  # `nix flake update nixpkgs` like everything else.

  # Larger inotify limits; the defaults are too low for a few language servers
  # plus a file watcher on a big repo.
  boot.kernel.sysctl = {
    "fs.inotify.max_user_watches" = 524288;
    "fs.inotify.max_user_instances" = 512;
  };
}
