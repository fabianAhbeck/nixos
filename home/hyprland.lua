-- Hyprland configuration (Lua). Pulled into the generated
-- ~/.config/hypr/hyprland.lua via extraConfig in hyprland.nix; Home Manager
-- prepends the systemd session start/stop hooks.
--
-- Keyboard layout is Swedish, matching the current install. SUPER is the mod
-- key. Workspaces 1-10 on SUPER+<n>, move window with SUPER+SHIFT+<n>.
--
-- `host` (monitors, backlight, repo paths) is defined above this file by
-- hyprland.nix from my.* in the NixOS config, so this file only verifies as
-- part of the generated config.
--
-- API reference: the `hl` stubs next to this Hyprland build, see
-- ~/.config/hypr/.luarc.json. Check changes with:
--   Hyprland --verify-config -c ~/.config/hypr/hyprland.lua

local mod      = "SUPER"
local terminal = "kitty"
local menu     = "wofi --show drun"
local browser  = "firefox"

-- gcr-ssh-agent (from gnome-keyring) is running, but nothing points SSH at
-- it. Setting it here covers every shell and GUI app launched from Hyprland.
hl.env("SSH_AUTH_SOCK", os.getenv("XDG_RUNTIME_DIR") .. "/gcr/ssh")

---------------------------------------------------------------------------
-- Monitors -- set per machine in my.monitors (hosts/<name>/default.nix).
-- `hyprctl monitors` lists names and modes. Floating windows opened at
-- another scale keep their old pixel size, so reopen or resize them after
-- changing a scale.
---------------------------------------------------------------------------
for _, spec in ipairs(host.monitors) do
  hl.monitor(spec)
end
-- Any other display: preferred mode, placed automatically, unscaled.
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })

---------------------------------------------------------------------------
-- Startup
---------------------------------------------------------------------------
hl.on("hyprland.start", function()
  hl.exec_cmd("systemctl --user start hyprpolkitagent")
  hl.exec_cmd("awww-daemon")
  hl.exec_cmd("wallpaper --init") -- default image on first login only
  hl.exec_cmd("nm-applet --indicator")
  hl.exec_cmd("blueman-applet")
  -- Clipboard history for both text and images.
  hl.exec_cmd("wl-paste --type text --watch cliphist store")
  hl.exec_cmd("wl-paste --type image --watch cliphist store")
end)

---------------------------------------------------------------------------
-- Input
---------------------------------------------------------------------------
hl.config({
  input = {
    kb_layout    = "se",
    kb_options   = "caps:escape", -- Caps Lock as Escape
    follow_mouse = 1,
    sensitivity  = 0,
    touchpad = {
      natural_scroll       = true,
      tap_to_click         = true,
      disable_while_typing = true,
      scroll_factor        = 0.6,
    },
  },
})

-- Three-finger horizontal swipe switches workspaces.
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

---------------------------------------------------------------------------
-- Look
---------------------------------------------------------------------------
hl.config({
  general = {
    gaps_in          = 4,
    gaps_out         = 8,
    border_size      = 2,
    layout           = "dwindle",
    resize_on_border = true,
    col = {
      active_border   = { colors = { "rgba(89b4faee)", "rgba(cba6f7ee)" }, angle = 45 },
      inactive_border = "rgba(45475aaa)",
    },
  },

  decoration = {
    rounding = 8,
    blur = {
      enabled = true,
      size    = 6,
      passes  = 2,
    },
    shadow = {
      enabled      = true,
      range        = 12,
      render_power = 2,
    },
  },

  animations = {
    enabled = true,
  },

  dwindle = {
    preserve_split = true,
  },

  misc = {
    disable_hyprland_logo    = true,
    disable_splash_rendering = true,
    force_default_wallpaper  = 0,
  },

  debug = {
    vfr = true, -- variable refresh when idle -- meaningful battery saving
  },
})

hl.curve("easeOutQuint", { type = "bezier", points = { { 0.23, 1 }, { 0.32, 1 } } })

hl.animation({ leaf = "windows",    enabled = true, speed = 4, bezier = "easeOutQuint" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 4, bezier = "easeOutQuint", style = "slide" })
hl.animation({ leaf = "fade",       enabled = true, speed = 3, bezier = "default" })

---------------------------------------------------------------------------
-- Key bindings
---------------------------------------------------------------------------
-- Cheat-sheet: KEYBINDINGS.md at the repo root. Keep it in sync.
local function key(k) return mod .. " + " .. k end
local function shift(k) return mod .. " + SHIFT + " .. k end
local exec = hl.dsp.exec_cmd

-- Launching
hl.bind(key("Return"), exec(terminal))
hl.bind(key("D"), exec(menu))
hl.bind(key("W"), exec(browser))
hl.bind(shift("D"), exec("discord")) -- single instance: raises it if already open
hl.bind(key("E"), exec("nautilus"))
hl.bind(key("N"), exec("networkmanager_dmenu")) -- Wi-Fi / VPN menu
hl.bind(key("V"), exec("cliphist list | wofi --dmenu | cliphist decode | wl-copy"))

-- Rebuild the system in the background, tracked by a notification (see
-- rebuild-bg in home/hyprland.nix).
hl.bind(shift("R"), exec("rebuild-bg"))

-- Window management
hl.bind(key("Q"), hl.dsp.window.close())
hl.bind(key("F"), hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))
hl.bind(shift("F"), hl.dsp.window.float({ action = "toggle" }))
hl.bind(key("P"), hl.dsp.window.pseudo())
hl.bind(key("T"), hl.dsp.layout("togglesplit"))
-- Logout goes through the power menu (see home/hyprland.nix) so a slip next
-- to SUPER+Q can't end the session.
hl.bind(shift("Q"), exec("powermenu"))

-- Session
-- Escape rather than L, which is vim-right below. Caps Lock is Escape too.
hl.bind(key("Escape"), exec("loginctl lock-session"))

-- Focus and move windows: arrows or vim keys (H/J/K/L = left/down/up/right).
for k, dir in pairs({
  left = "left", right = "right", up = "up", down = "down",
  H = "left", J = "down", K = "up", L = "right",
}) do
  hl.bind(key(k), hl.dsp.focus({ direction = dir }))
  hl.bind(shift(k), hl.dsp.window.move({ direction = dir }))
end

-- Workspaces
for i = 1, 10 do
  local n = tostring(i % 10) -- workspace 10 lives on the 0 key
  hl.bind(key(n), hl.dsp.focus({ workspace = i }))
  hl.bind(shift(n), hl.dsp.window.move({ workspace = i }))
end

hl.bind(key("S"), hl.dsp.workspace.toggle_special("magic"))
hl.bind(shift("S"), hl.dsp.window.move({ workspace = "special:magic" }))

-- Claude Code scratchpads, one per repo, each on its own special workspace
-- and each resuming that repo's most recent conversation (or starting a
-- new one). SUPER+C toggles the session used last (nixos after a config
-- reload); SUPER+SHIFT+C opens a picker (claude-pick in home/hyprland.nix) to
-- switch, and the pick becomes the new "last". Sessions keep running while
-- hidden, and both can run at once. The nixos pane keeps its original
-- workspace name, "claude".
local claude_sessions = {
  nixos    = { class = "claude-nixos",    ws = "claude",          dir = host.repos.nixos },
  dotfiles = { class = "claude-dotfiles", ws = "claude-dotfiles", dir = host.repos.dotfiles },
  -- Runs on the homelab's Claude VM over ssh, inside tmux (claude-remote in
  -- hyprland.nix), so a dropped connection doesn't end the session.
  homelab  = { class = "claude-homelab",  ws = "claude-homelab",
               remote = "claude@10.0.20.203", dir = "/home/claude/Project" },
}

local claude_last = "nixos"

-- The claude session whose pane is `ws_name` ("special:..."), if any.
local function claude_session_on(ws_name)
  for _, sess in pairs(claude_sessions) do
    if ws_name == "special:" .. sess.ws then return sess end
  end
end

-- Returns a function so `hyprctl dispatch "claude_show('dotfiles')"` works:
-- hyprctl wraps the expression in hl.dispatch(), which runs functions.
function claude_show(name)
  return function()
    local sess = claude_sessions[name]
    if not sess then return end
    claude_last = name
    local shown = hl.get_active_special_workspace()
    if not (shown and shown.name == "special:" .. sess.ws) then
      hl.dispatch(hl.dsp.workspace.toggle_special(sess.ws))
    end
    if #hl.get_windows({ class = sess.class }) == 0 then
      if sess.remote then
        hl.exec_cmd(terminal .. " --class " .. sess.class .. " claude-remote "
          .. sess.remote .. " " .. sess.class .. " " .. sess.dir)
      else
        hl.exec_cmd(terminal .. " --class " .. sess.class .. " --directory " .. sess.dir
          .. " sh -c 'claude --continue || claude'")
      end
    end
  end
end

hl.bind(key("C"), function()
  local shown = hl.get_active_special_workspace()
  local sess = shown and claude_session_on(shown.name)
  if sess then
    hl.dispatch(hl.dsp.workspace.toggle_special(sess.ws))
  else
    hl.dispatch(claude_show(claude_last))
  end
end)
hl.bind(shift("C"), exec("claude-pick"))

-- New windows open on the focused workspace, which is a Claude pane while
-- one is shown. Keep the panes for their Claude window only: send anything
-- else to the regular workspace underneath, hide the pane and focus the new
-- window. The hide/focus runs on a timer: it has no effect inside window.open.
-- Small popups are exempt and simply open over the pane.
local pane_popups = {
  gsimplecal = true, -- the Waybar clock's calendar
}
hl.on("window.open", function(w)
  if not w or pane_popups[w.class] then return end
  local ws = w.workspace
  local sess = ws and claude_session_on(ws.name)
  if not sess or w.class == sess.class then return end
  local target = hl.get_active_workspace()
  if not target then return end
  hl.dispatch(hl.dsp.window.move({ workspace = target.id, window = w }))
  hl.timer(function()
    local shown = hl.get_active_special_workspace()
    if shown and claude_session_on(shown.name) then
      hl.dispatch(hl.dsp.workspace.toggle_special(shown.name:sub(#"special:" + 1)))
    end
    hl.dispatch(hl.dsp.focus({ window = w }))
  end, { timeout = 1, type = "oneshot" })
end)

-- SUPER + plus / minus: step the focused monitor's scale through values
-- that divide its resolution evenly (so text stays sharp), with a swayosd
-- popup. Floating Claude windows keep their pixel size across a scale
-- change, so they are resized to their usual 70% x 75% and re-centred. A
-- config reload goes back to the scales in host.monitors.
local scale_candidates = { 1, 1.2, 1.25, 4 / 3, 1.5, 1.6, 2 }

local function clean_scales(width, height)
  local out = {}
  for _, s in ipairs(scale_candidates) do
    local lw, lh = width / s, height / s
    if math.abs(lw - math.floor(lw + 0.5)) < 0.01 and math.abs(lh - math.floor(lh + 0.5)) < 0.01 then
      out[#out + 1] = s
    end
  end
  return out
end

-- The monitor's spec from host.monitors, or one built from its current mode.
local function monitor_spec(m)
  for _, spec in ipairs(host.monitors) do
    if spec.output == m.name then return spec end
  end
  return {
    output = m.name,
    mode = string.format("%dx%d@%.3f", m.width, m.height, m.refresh_rate),
    position = string.format("%dx%d", m.x, m.y),
  }
end

local function fit_claude_windows()
  local m = hl.get_active_monitor()
  if not m then return end
  local w_ = math.floor(m.width / m.scale * 0.7)
  local h_ = math.floor(m.height / m.scale * 0.75)
  for _, sess in pairs(claude_sessions) do
    for _, w in ipairs(hl.get_windows({ class = sess.class })) do
      hl.dispatch(hl.dsp.window.resize({ x = w_, y = h_, exact = true, window = w }))
      hl.dispatch(hl.dsp.window.center({ window = w }))
    end
  end
end

local function step_scale(dir)
  local m = hl.get_active_monitor()
  if not m then return end
  local scales = clean_scales(m.width, m.height)
  -- Index of the listed scale closest to the current one.
  local i, best = 1, math.huge
  for n, s in ipairs(scales) do
    if math.abs(s - m.scale) < best then i, best = n, math.abs(s - m.scale) end
  end
  local new = scales[math.max(1, math.min(#scales, i + dir))]
  if new == scales[i] and best < 0.01 then return end
  local spec = monitor_spec(m)
  hl.monitor({ output = spec.output, mode = spec.mode, position = spec.position, scale = new })
  hl.timer(fit_claude_windows, { timeout = 100, type = "oneshot" })
  hl.exec_cmd(string.format(
    "swayosd-client --custom-message 'Scale %.2f' --custom-icon zoom-in-symbolic", new))
end

hl.bind(key("plus"), function() step_scale(1) end)
hl.bind(key("minus"), function() step_scale(-1) end)

hl.bind(key("mouse_down"), hl.dsp.focus({ workspace = "e+1" }))
hl.bind(key("mouse_up"), hl.dsp.focus({ workspace = "e-1" }))

-- Screenshots -- region, window, full screen; Shift annotates first.
hl.bind("Print", exec('grim -g "$(slurp)" - | wl-copy'))
hl.bind("SHIFT + Print", exec('grim -g "$(slurp)" - | swappy -f -'))
hl.bind(key("Print"), exec("grim - | wl-copy"))

-- Move/resize windows by dragging with LMB/RMB.
hl.bind(key("mouse:272"), hl.dsp.window.drag(), { mouse = true })
hl.bind(key("mouse:273"), hl.dsp.window.resize(), { mouse = true })

-- Media and brightness keys, still live on the lock screen; volume and
-- brightness repeat while held. swayosd-client makes the change and shows an
-- on-screen popup (server: services.swayosd in home/fabian.nix).
local held = { locked = true, repeating = true }
local locked = { locked = true }
local osd = "swayosd-client "
-- Screen only (host.backlight); without --device swayosd would also step
-- e.g. a keyboard backlight.
local screen = host.backlight and (" --device " .. host.backlight) or ""
hl.bind("XF86AudioRaiseVolume", exec(osd .. "--output-volume +5 --max-volume 100"), held)
hl.bind("XF86AudioLowerVolume", exec(osd .. "--output-volume -5"), held)
hl.bind("XF86MonBrightnessUp", exec(osd .. "--brightness +5" .. screen), held)
hl.bind("XF86MonBrightnessDown", exec(osd .. "--brightness -5" .. screen), held)

hl.bind("XF86AudioMute", exec(osd .. "--output-volume mute-toggle"), locked)
hl.bind("XF86AudioMicMute", exec(osd .. "--input-volume mute-toggle"), locked)
hl.bind("XF86AudioPlay", exec(osd .. "--playerctl play-pause"), locked)
hl.bind("XF86AudioNext", exec(osd .. "--playerctl next"), locked)
hl.bind("XF86AudioPrev", exec(osd .. "--playerctl prev"), locked)

---------------------------------------------------------------------------
-- Window rules
---------------------------------------------------------------------------
hl.window_rule({
  name           = "suppress-maximize",
  match          = { class = ".*" },
  suppress_event = "maximize",
})

-- Fix occasional XWayland cursor scaling artefacts.
hl.window_rule({
  name     = "fix-xwayland-drags",
  match    = { class = "^$", title = "^$", xwayland = true, float = true, fullscreen = false, pin = false },
  no_focus = true,
})

hl.window_rule({
  name  = "float-utilities",
  match = { class = "^(pavucontrol|blueman-manager|nm-connection-editor|org.gnome.Calculator|gnome-disks)$" },
  float = true,
})

for name, sess in pairs(claude_sessions) do
  hl.window_rule({
    name      = "claude-" .. name,
    match     = { class = "^(" .. sess.class .. ")$" },
    workspace = "special:" .. sess.ws,
    float     = true,
    size      = "(monitor_w*0.7) (monitor_h*0.75)",
    center    = true,
  })
end

-- The Waybar clock's calendar (calendar-popup in home/waybar.nix): centred
-- just under the bar.
hl.window_rule({
  name  = "calendar-popup",
  match = { class = "^(gsimplecal)$" },
  float = true,
  move  = "(monitor_w*0.5-window_w*0.5) 40",
})

hl.window_rule({
  name   = "rebuild-log",
  match  = { class = "^(rebuild-log)$" },
  float  = true,
  size   = "(monitor_w*0.5) (monitor_h*0.5)",
  center = true,
})

hl.window_rule({
  name  = "float-file-dialogs",
  match = { title = "^(Open File|Save File|Choose Files)$" },
  float = true,
})

-- Games get their own workspace, no gaps, no border.
hl.window_rule({
  name       = "steam-games",
  match      = { class = "^(steam_app_.*)$" },
  workspace  = "9",
  fullscreen = true,
  immediate  = true, -- tearing allowed -> lower latency
})

hl.workspace_rule({
  workspace   = "9",
  gaps_in     = 0,
  gaps_out    = 0,
  no_border   = true,
  no_rounding = true,
})
