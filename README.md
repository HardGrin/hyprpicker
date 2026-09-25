# HyprPicker
This is a simple script for hyprpaper that lets you quickly switch to a wallpaper of your choice on your Hyprland setup.

You can see all settings in script
# ------------------------------- SETTINGS -----------------------------------
WALLPAPER_DIR="YOU_PASS"                       # wallpaper folder
HYPRPAPER_CONF="YOU_PASS/.config/hypr/hyprpaper.conf"      # hyprpaper config
FIT_MODE="cover"                                             # cover/contain/fit/tile
UPDATE_CONF=1                # 1 = remember choice in hyprpaper.conf (survives restart)
HYPRPAPER_LOG="${XDG_RUNTIME_DIR:-/tmp}/hyprpaper-picker.log" # selection and startup log
# ----------------------------------------------------------------------------
