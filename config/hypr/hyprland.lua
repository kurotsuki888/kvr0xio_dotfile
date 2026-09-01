-- Hyprland Lua Configuration File
-- Convertido desde hyprland.conf para compatibilidad con Hyprland v0.56+ y v0.57+

------------------
---- MONITORS ----
------------------
hl.monitor({
    output   = "HDMI-A-1",
    mode     = "1680x1050@59.883",
    position = "0x0",
    scale    = "1",
})

hl.monitor({
    output   = "eDP-1",
    mode     = "1920x1080@60.027",
    position = "1680x0",
    scale    = "1",
})



-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("GTK_THEME", "adw-gtk3-dark")

-- Nvidia
hl.env("LIBVA_DRIVER_NAME", "nvidia")
hl.env("GBM_BACKEND", "nvidia-drm")
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
hl.env("__GL_VRR_ALLOWED", "0")


-------------------
---- AUTOSTART ----
-------------------
hl.on("hyprland.start", function ()
    hl.exec_cmd("/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 || /usr/libexec/polkit-gnome-authentication-agent-1 || /usr/lib/polkit-kde-authentication-agent-1 || /usr/libexec/polkit-mate-authentication-agent-1")
    hl.exec_cmd("sleep 1 && gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'")
    hl.exec_cmd("sleep 1 && gsettings set org.gnome.desktop.interface gtk-theme 'adw-gtk3-dark'")
    hl.exec_cmd("waybar")
    hl.exec_cmd("swaync")
    hl.exec_cmd("~/.config/hypr/scripts/init_wp.sh")
    hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
    hl.exec_cmd("systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
    hl.exec_cmd("sleep 1 && (/usr/lib/xdg-desktop-portal-hyprland || /usr/libexec/xdg-desktop-portal-hyprland)")
    hl.exec_cmd("sleep 2 && (/usr/lib/xdg-desktop-portal || /usr/libexec/xdg-desktop-portal)")
    hl.exec_cmd("sleep 2 && env QT_QPA_PLATFORM=xcb whatsie")
end)


-----------------------
---- CONFIGURATION ----
-----------------------
hl.config({
    input = {
        kb_layout = "latam",
        numlock_by_default = false,
        follow_mouse = 1,
        touchpad = {
            natural_scroll = false,
        },
    },
    cursor = {
        no_hardware_cursors = true,
    },
    ecosystem = {
        no_update_news = true,
        no_donation_nag = true,
    },
    general = {
        gaps_in = 5,
        gaps_out = 10,
        border_size = 2,
        col = {
            active_border   = { colors = {"rgb(b30000)", "rgb(000000)"}, angle = 45 },
            inactive_border = "rgba(313244aa)",
        },
    },
    decoration = {
        rounding = 8,
        blur = {
            enabled = true,
            size = 3,
            passes = 1,
            new_optimizations = true,
        },
    },
    animations = {
        enabled = true,
    },
})


--------------------
---- ANIMATIONS ----
--------------------
hl.curve("wind",     { type = "bezier", points = { {0.05, 0.9},  {0.1, 1.05} } })
hl.curve("winSlide", { type = "bezier", points = { {0.1, 0.9},   {0.1, 1.05} } })
hl.curve("winIn",    { type = "bezier", points = { {0.1, 1.1},   {0.1, 1.1}  } })
hl.curve("winOut",   { type = "bezier", points = { {0.3, -0.3},  {0, 1}      } })
hl.curve("liner",    { type = "bezier", points = { {1, 1},       {1, 1}      } })

hl.animation({ leaf = "windows",     enabled = true, speed = 6,  bezier = "wind",   style = "slide" })
hl.animation({ leaf = "windowsIn",   enabled = true, speed = 6,  bezier = "winIn",  style = "slide" })
hl.animation({ leaf = "windowsOut",  enabled = true, speed = 5,  bezier = "winOut", style = "slide" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 5,  bezier = "wind",   style = "slide" })
hl.animation({ leaf = "border",      enabled = true, speed = 1,  bezier = "liner" })
hl.animation({ leaf = "borderangle", enabled = true, speed = 30, bezier = "liner", style = "loop" })
hl.animation({ leaf = "fade",        enabled = true, speed = 8,  bezier = "default" })
hl.animation({ leaf = "workspaces",  enabled = true, speed = 5,  bezier = "wind",   style = "slide" })


----------------------
---- KEYBINDINGS -----
----------------------
local mainMod     = "SUPER"
local terminal    = "kitty"
local browser     = "firefox"
local fileManager = "thunar"

-- Apps principales
hl.bind(mainMod .. " + RETURN", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd(browser))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + SPACE", hl.dsp.exec_cmd("rofi -show drun -show-icons"))

-- Gestión de ventanas
hl.bind("ALT + TAB", hl.dsp.exec_cmd("~/.config/hypr/scripts/rofi-window.sh"))
hl.bind(mainMod .. " + Q", hl.dsp.window.close())
hl.bind(mainMod .. " + SHIFT + Q", hl.dsp.exec_cmd("hyprctl dispatch exit"))
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen())
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())
hl.bind(mainMod .. " + SHIFT + RETURN", hl.dsp.exec_cmd("kitty --session ~/.config/kitty/dashboard.session"))

-- Captura de pantalla
hl.bind("PRINT", hl.dsp.exec_cmd("flameshot gui"))
hl.bind("SHIFT + PRINT", hl.dsp.exec_cmd("grim -g \"$(slurp)\" - | wl-copy"))
hl.bind(mainMod .. " + PRINT", hl.dsp.exec_cmd("grim - | wl-copy"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd("grim -g \"$(slurp)\" ~/Pictures/screenshot_$(date +%Y%m%d_%H%M%S).png"))

-- Foco entre ventanas
hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "l" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "r" }))
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "u" }))
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "d" }))
hl.bind(mainMod .. " + H",     hl.dsp.focus({ direction = "l" }))
hl.bind(mainMod .. " + L",     hl.dsp.focus({ direction = "r" }))
hl.bind(mainMod .. " + K",     hl.dsp.focus({ direction = "u" }))
hl.bind(mainMod .. " + J",     hl.dsp.focus({ direction = "d" }))

-- Mover ventanas
hl.bind(mainMod .. " + SHIFT + left",  hl.dsp.window.move({ direction = "l" }))
hl.bind(mainMod .. " + SHIFT + right", hl.dsp.window.move({ direction = "r" }))
hl.bind(mainMod .. " + SHIFT + up",    hl.dsp.window.move({ direction = "u" }))
hl.bind(mainMod .. " + SHIFT + down",  hl.dsp.window.move({ direction = "d" }))

-- Redimensionar ventanas
hl.bind(mainMod .. " + CTRL + left",  hl.dsp.exec_raw("resizeactive", "-40 0"))
hl.bind(mainMod .. " + CTRL + right", hl.dsp.exec_raw("resizeactive", "40 0"))
hl.bind(mainMod .. " + CTRL + up",    hl.dsp.exec_raw("resizeactive", "0 -40"))
hl.bind(mainMod .. " + CTRL + down",  hl.dsp.exec_raw("resizeactive", "0 40"))

-- Workspaces
for i = 1, 10 do
    local key = i % 10
    hl.bind(mainMod .. " + " .. key,         hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

-- Minimizar (workspace especial)
hl.bind(mainMod .. " + M",         hl.dsp.exec_cmd("~/.config/hypr/scripts/minimize.sh minimize"))
hl.bind(mainMod .. " + SHIFT + M", hl.dsp.exec_cmd("~/.config/hypr/scripts/minimize.sh toggle"))
hl.bind(mainMod .. " + CTRL + M",  hl.dsp.exec_cmd("~/.config/hypr/scripts/minimize.sh restore"))

-- Mouse binds
hl.bind(mainMod .. " + mouse_down", hl.dsp.exec_raw("workspace", "e+1"))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.exec_raw("workspace", "e-1"))

hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Multimedia keys (con OSD y animaciones)
hl.bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd("~/.config/hypr/scripts/volume.sh up"),         { locked = true })
hl.bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd("~/.config/hypr/scripts/volume.sh down"),       { locked = true })
hl.bind("XF86AudioMute",         hl.dsp.exec_cmd("~/.config/hypr/scripts/volume.sh mute"),       { locked = true })
hl.bind("XF86AudioMicMute",      hl.dsp.exec_cmd("~/.config/hypr/scripts/volume.sh mic-mute"),   { locked = true })
hl.bind("XF86AudioPlay",         hl.dsp.exec_cmd("playerctl play-pause"),                         { locked = true })
hl.bind("XF86AudioPause",        hl.dsp.exec_cmd("playerctl play-pause"),                         { locked = true })
hl.bind("XF86AudioNext",         hl.dsp.exec_cmd("playerctl next"),                               { locked = true })
hl.bind("XF86AudioPrev",         hl.dsp.exec_cmd("playerctl previous"),                           { locked = true })
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("~/.config/hypr/scripts/brightness.sh up"),     { locked = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("~/.config/hypr/scripts/brightness.sh down"),   { locked = true })

-- Bloqueo de pantalla
hl.bind(mainMod .. " + SHIFT + L", hl.dsp.exec_cmd("hyprlock"))

-- Clipboard history
hl.bind(mainMod .. " + C", hl.dsp.exec_cmd("~/.config/hypr/scripts/clipboard.sh"))

-- Recargar waybar
hl.bind(mainMod .. " + SHIFT + W", hl.dsp.exec_cmd("killall waybar && waybar"))

-- Selector de fondos y control de fondos
hl.bind(mainMod .. " + ALT + W",   hl.dsp.exec_cmd("~/.config/hypr/scripts/wp_picker.sh"))
hl.bind(mainMod .. " + SHIFT + P", hl.dsp.exec_cmd("~/.config/hypr/scripts/toggle_wallpaper_pause.sh toggle"))
hl.bind(mainMod .. " + SHIFT + O", hl.dsp.exec_cmd("~/.config/hypr/scripts/toggle_wallpaper_pause.sh resume"))


--------------------------------
---- WINDOWS & LAYER RULES -----
--------------------------------
hl.layer_rule({
    name         = "waybar-blur",
    match        = { namespace = "^waybar$" },
    blur         = true,
    ignore_alpha = 0.5,
})

hl.layer_rule({
    name         = "quickshell-blur",
    match        = { namespace = "^quickshell$" },
    blur         = true,
    ignore_alpha = 0.2,
})

hl.layer_rule({
    name         = "rofi-blur",
    match        = { namespace = "^rofi$" },
    blur         = true,
    ignore_alpha = 0.2,
})

hl.window_rule({
    name   = "nmtui-float",
    match  = { class = "^nmtui-float$" },
    float  = true,
    size   = "600 400",
    center = true,
})

hl.window_rule({
    name   = "blueman-manager-float",
    match  = { class = "^blueman-manager$" },
    float  = true,
    size   = "600 450",
    center = true,
})

hl.window_rule({
    name   = "wallpaper-picker-float",
    match  = { class = "^wallpaper-picker$" },
    float  = true,
    size   = "700 400",
    center = true,
})
