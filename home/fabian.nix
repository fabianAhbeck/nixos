{ config, pkgs, ... }:
{
  imports = [
    ./hyprland.nix
    ./waybar.nix
    ./shell.nix
  ];

  home.username = "fabian";
  home.homeDirectory = "/home/fabian";

  ###########################################################################
  # Git
  ###########################################################################

  programs.git = {
    enable = true;

    # userName / userEmail / extraConfig were all folded into `settings`.
    settings = {
      user.name = "Fabian Åhbeck";
      user.email = "fabian.ahbeck@irori.se";

      init.defaultBranch = "main";
      pull.rebase = true;
      push.autoSetupRemote = true;
      rebase.autoStash = true;
      fetch.prune = true;
      diff.algorithm = "histogram";
      merge.conflictStyle = "zdiff3";
      rerere.enabled = true;
      column.ui = "auto";
      branch.sort = "-committerdate";
    };

    ignores = [
      ".direnv/"
      "result"
      "result-*"
      ".DS_Store"
    ];
  };

  # Standalone module: programs.git.delta is the older nested form, and its
  # automatic git integration is deprecated.
  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    options = {
      navigate = true;
      line-numbers = true;
      side-by-side = true;
    };
  };

  programs.gh = {
    enable = true;
    settings.git_protocol = "ssh";
  };

  programs.lazygit.enable = true;

  ###########################################################################
  # Terminal
  ###########################################################################

  programs.kitty = {
    enable = true;
    font = {
      name = "JetBrainsMono Nerd Font";
      size = 11.0;
    };
    settings = {
      enable_audio_bell = false;
      confirm_os_window_close = 0;
      window_padding_width = 6;
      scrollback_lines = 20000;
      # Kitty is the terminal the Hyprland binds open (SUPER+Return).
      background_opacity = "0.95";
    };
    themeFile = "Catppuccin-Mocha";
  };

  ###########################################################################
  # Editor
  ###########################################################################

  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    # init.lua comes from the dotfiles repo (below); load HM's own bits
    # through the wrapper instead of writing ~/.config/nvim/init.lua.
    sideloadInitLua = true;
  };

  # The config itself lives in the dotfiles repo (lazy.nvim + Mason). Linked
  # rather than copied into the store, so edits apply without a rebuild and
  # lazy.nvim can still write lazy-lock.json. Mason's downloaded servers run
  # thanks to programs.nix-ld (modules/dev.nix).
  xdg.configFile."nvim".source =
    config.lib.file.mkOutOfStoreSymlink "/home/fabian/Projects/dotfiles/.config/nvim";

  ###########################################################################
  # Notifications, launcher, lock, idle
  ###########################################################################

  services.mako = {
    enable = true;
    settings = {
      default-timeout = 6000;
      border-radius = 8;
      border-size = 2;
      padding = "12";
      width = 380;
      font = "Inter 10";
      background-color = "#1e1e2ee6";
      text-color = "#cdd6f4";
      border-color = "#89b4fa";
    };
  };

  # Volume / brightness / media popups, driven by swayosd-client in the
  # Hyprland key bindings.
  services.swayosd.enable = true;

  programs.wofi = {
    enable = true;
    settings = {
      allow_images = true;
      insensitive = true;
      width = 600;
      lines = 10;
    };
  };

  programs.hyprlock = {
    enable = true;
    settings = {
      general = {
        hide_cursor = true;
        grace = 2;
      };
      background = [
        {
          color = "rgba(30, 30, 46, 1.0)";
          blur_passes = 2;
        }
      ];
      input-field = [
        {
          size = "300, 50";
          position = "0, -20";
          halign = "center";
          valign = "center";
          outline_thickness = 2;
          outer_color = "rgb(137, 180, 250)";
          inner_color = "rgb(49, 50, 68)";
          font_color = "rgb(205, 214, 244)";
          placeholder_text = "";
          fade_on_empty = false;
        }
      ];
      label = [
        {
          text = "$TIME";
          font_size = 64;
          color = "rgb(205, 214, 244)";
          position = "0, 120";
          halign = "center";
          valign = "center";
        }
      ];
    };
  };

  services.hypridle = {
    enable = true;
    settings = {
      general = {
        lock_cmd = "pidof hyprlock || hyprlock";
        before_sleep_cmd = "loginctl lock-session";
        after_sleep_cmd = "hyprctl dispatch dpms on";
      };
      listener = [
        {
          timeout = 300; # 5 min -- dim
          on-timeout = "brightnessctl -s set 10";
          on-resume = "brightnessctl -r";
        }
        {
          timeout = 600; # 10 min -- lock
          on-timeout = "loginctl lock-session";
        }
        {
          timeout = 900; # 15 min -- screen off
          on-timeout = "hyprctl dispatch dpms off";
          on-resume = "hyprctl dispatch dpms on";
        }
        {
          timeout = 1800; # 30 min -- suspend
          on-timeout = "systemctl suspend";
        }
      ];
    };
  };

  # Clipboard history, fed by the wl-paste watchers in hyprland.lua.
  home.packages = with pkgs; [
    cliphist
    wl-clipboard
    awww # wallpaper daemon (formerly swww)
    networkmanagerapplet
  ];

  ###########################################################################
  # Theming -- GTK apps need to be told, they don't follow Hyprland
  ###########################################################################

  gtk = {
    enable = true;
    theme = {
      name = "Adwaita-dark";
      package = pkgs.gnome-themes-extra;
    };
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };
    font = {
      name = "Inter";
      size = 11;
    };
  };

  qt = {
    enable = true;
    platformTheme.name = "adwaita";
    style.name = "adwaita-dark";
  };

  home.pointerCursor = {
    enable = true;
    gtk.enable = true;
    hyprcursor.enable = true;
    package = pkgs.bibata-cursors;
    name = "Bibata-Modern-Classic";
    size = 24;
  };

  # Tell Electron/Chromium apps (VS Code, Discord, Slack) to use Wayland.
  home.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    ELECTRON_OZONE_PLATFORM_HINT = "auto";
    MOZ_ENABLE_WAYLAND = "1";
  };

  xdg.userDirs = {
    enable = true;
    createDirectories = true;
  };

  programs.home-manager.enable = true;

  # Same rule as system.stateVersion: set once, never bump.
  home.stateVersion = "26.05";
}
