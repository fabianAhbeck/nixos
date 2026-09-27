# Shell, prompt, and the small CLI conveniences that go with them.
{ pkgs, ... }:
{
  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    enableCompletion = true;

    history = {
      size = 100000;
      save = 100000;
      ignoreDups = true;
      ignoreSpace = true;
      expireDuplicatesFirst = true;
      share = true;
    };

    shellAliases = {
      # nh wraps nixos-rebuild with a progress view and a generation diff.
      # `rebuild` itself is a script (see home.packages below).
      rebuild-boot = "nh os boot";
      rebuild-test = "nh os test";
      update = "nix flake update --flake /home/fabian/Projects/nixos";
      gc = "nh clean all --keep 5 --keep-since 30d";

      ls = "eza --group-directories-first";
      ll = "eza -l --group-directories-first --git";
      la = "eza -la --group-directories-first --git";
      lt = "eza --tree --level=2";
      cat = "bat";

      k = "kubectl";
      kx = "kubectx";
      kn = "kubens";
      tf = "tofu";

      g = "git";
      gs = "git status -sb";
      gd = "git diff";
      lg = "lazygit";
    };

    initContent = ''
      # Emacs-style line editing even with EDITOR=nvim.
      bindkey -e

      # Ctrl+R / Ctrl+T come from the fzf module below.

      # Swedish keyboard: make Home/End/Delete behave in the terminal.
      bindkey "''${terminfo[khome]}" beginning-of-line
      bindkey "''${terminfo[kend]}"  end-of-line
      bindkey "''${terminfo[kdch1]}" delete-char
    '';
  };

  programs.starship = {
    enable = true;
    settings = {
      add_newline = false;
      command_timeout = 1000;
      kubernetes.disabled = false;
      kubernetes.format = "[⎈ $context(\\($namespace\\))]($style) ";
      nix_shell.format = "[$symbol$name]($style) ";
      git_status.disabled = false;
    };
  };

  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
    defaultCommand = "fd --type f --hidden --exclude .git";
    defaultOptions = [
      "--height 40%"
      "--layout=reverse"
      "--border"
    ];
  };

  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    enableZshIntegration = true;
  };

  programs.bat = {
    enable = true;
    # A built-in theme, so there is no source hash to keep in sync. `bat
    # --list-themes` shows the rest.
    config.theme = "TwoDark";
  };

  programs.tmux = {
    enable = true;
    prefix = "C-a";
    baseIndex = 1;
    escapeTime = 10;
    keyMode = "vi";
    mouse = true;
    terminal = "tmux-256color";
    historyLimit = 50000;
    extraConfig = ''
      set -ga terminal-overrides ",xterm-kitty:Tc"
      bind | split-window -h -c "#{pane_current_path}"
      bind - split-window -v -c "#{pane_current_path}"
      bind r source-file ~/.config/tmux/tmux.conf \; display "reloaded"
    '';
  };

  programs.btop.enable = true;
  programs.ssh = {
    enable = true;
    # Home Manager's implicit defaults are going away, so spell them out.
    # Note `settings` uses ssh_config's own capitalised key names.
    enableDefaultConfig = false;
    settings."*" = {
      # Reuse connections; makes repeated git pushes over SSH much faster.
      ControlMaster = "auto";
      ControlPath = "~/.ssh/master-%r@%n:%p";
      ControlPersist = "10m";
      ServerAliveInterval = 60;
      ServerAliveCountMax = 3;

      AddKeysToAgent = "yes";
      ForwardAgent = false;
      Compression = false;
      HashKnownHosts = false;
      UserKnownHostsFile = "~/.ssh/known_hosts";
    };
  };

  # `rebuild` as a real command rather than an alias, so it works from any
  # shell, a keybinding, or a script. Extra args go straight to nh.
  home.packages = [
    (pkgs.writeShellScriptBin "rebuild" ''
      exec ${pkgs.nh}/bin/nh os switch /home/fabian/Projects/nixos "$@"
    '')
  ];
}
