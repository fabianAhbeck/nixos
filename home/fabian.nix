{
  config,
  osConfig,
  pkgs,
  ...
}:
let
  qtctAppearance = {
    custom_palette = true;
    color_scheme_path = "${config.xdg.configHome}/qtct/catppuccin-mocha.conf";
    style = "Fusion";
    icon_theme = "Papirus-Dark";
  };
in
{
  imports = [
    ./hyprland.nix
    ./waybar.nix
    ./shell.nix
    ./speech.nix
    ./bose.nix
    ./battery.nix
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
    config.lib.file.mkOutOfStoreSymlink "${osConfig.my.repos.dotfiles}/.config/nvim";

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

      # Critical notifications (e.g. battery at 5%) stay until dismissed.
      "urgency=critical" = {
        default-timeout = 0;
        border-color = "#f38ba8";
      };
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
    # Catppuccin Mocha, shared by every wofi menu: launcher, power menu,
    # Claude picker, Wi-Fi menu.
    style = ''
      window {
        margin: 0;
        border: 2px solid #89b4fa;
        border-radius: 10px;
        background-color: #1e1e2e;
        font-family: "Inter", "JetBrainsMono Nerd Font";
        font-size: 13px;
      }
      #outer-box { margin: 0; padding: 8px; border: none; }
      #input {
        margin: 0 0 8px 0;
        padding: 6px 10px;
        border: none;
        border-radius: 6px;
        background-color: #313244;
        color: #cdd6f4;
        box-shadow: none;
      }
      #input:focus { border: none; box-shadow: none; }
      #inner-box, #scroll { margin: 0; border: none; background-color: transparent; }
      #entry { padding: 5px 8px; border-radius: 6px; }
      #entry:selected { background-color: #45475a; outline: none; }
      #text { color: #cdd6f4; }
      #entry:selected #text { color: #89b4fa; font-weight: bold; }
    '';
  };

  # Wi-Fi / VPN menu in wofi (Waybar network click, SUPER+N). Replaces
  # nmtui in a terminal; nm-connection-editor is still there for details.
  # The package is in home.packages below.
  xdg.configFile."networkmanager-dmenu/config.ini".text = ''
    [dmenu]
    dmenu_command = wofi --dmenu --insensitive --width 420 --lines 12 --cache-file /dev/null
    highlight = True
    highlight_fg = #89b4fa
    highlight_bg = #313244
    highlight_bold = True
    compact = True
    wifi_chars = ▂▄▆█
    format = {bars}  {name:<{max_len_name}}  {sec}
    list_saved = False
    prompt = Wi-Fi

    [dmenu_passphrase]
    obscure = True

    [editor]
    terminal = kitty
    gui_if_available = True
    gui = nm-connection-editor

    [nmdm]
    rescan_delay = 3
  '';

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
          timeout = 1800; # 30 min -- suspend (laptops: then hibernate, see hosts/)
          on-timeout = if osConfig.my.laptop then "systemctl suspend-then-hibernate" else "systemctl suspend";
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
    networkmanager_dmenu
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

  # Qt apps (the polkit password dialog, VLC, Wireshark, ...) get the same
  # Catppuccin Mocha colours as kitty, Waybar and hyprlock. The palette comes
  # from qt6ct/qt5ct; Fusion is the Qt style that actually follows it.
  # libadwaita/GTK4 apps (Mission Center, Nautilus, Loupe, Calculator) ignore
  # the GTK theme and follow this instead; the portal also passes it on to
  # apps like Firefox.
  dconf.settings."org/gnome/desktop/interface".color-scheme = "prefer-dark";

  qt = {
    enable = true;
    platformTheme.name = "qtct";
    qt5ctSettings.Appearance = qtctAppearance;
    qt6ctSettings.Appearance = qtctAppearance;
  };

  # Colours in QPalette role order: WindowText, Button, Light, Midlight, Dark,
  # Mid, Text, BrightText, ButtonText, Base, Window, Shadow, Highlight,
  # HighlightedText, Link, LinkVisited, AlternateBase, NoRole, ToolTipBase,
  # ToolTipText, PlaceholderText, Accent.
  xdg.configFile."qtct/catppuccin-mocha.conf".text = ''
    [ColorScheme]
    active_colors=#cdd6f4, #313244, #585b70, #45475a, #11111b, #181825, #cdd6f4, #ffffff, #cdd6f4, #181825, #1e1e2e, #11111b, #89b4fa, #1e1e2e, #89b4fa, #cba6f7, #313244, #1e1e2e, #313244, #cdd6f4, #6c7086, #89b4fa
    inactive_colors=#cdd6f4, #313244, #585b70, #45475a, #11111b, #181825, #cdd6f4, #ffffff, #cdd6f4, #181825, #1e1e2e, #11111b, #89b4fa, #1e1e2e, #89b4fa, #cba6f7, #313244, #1e1e2e, #313244, #cdd6f4, #6c7086, #89b4fa
    disabled_colors=#6c7086, #313244, #585b70, #45475a, #11111b, #181825, #6c7086, #ffffff, #6c7086, #181825, #1e1e2e, #11111b, #45475a, #a6adc8, #89b4fa, #cba6f7, #313244, #1e1e2e, #313244, #cdd6f4, #6c7086, #45475a
  '';

  # Shape of the Hyprland Qt Quick style used by hyprpolkitagent and the
  # other hypr* dialogs. Roundness and border width both go 0-3.
  xdg.configFile."hypr/application-style.conf".text = ''
    roundness = 2
    border_width = 1
  '';

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
