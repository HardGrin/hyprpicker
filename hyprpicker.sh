#!/usr/bin/env bash
# ============================================================================
#  hyprpaper-picker.sh — pick wallpapers from ~/backgrounds via wofi
#  for hyprpaper v0.8.x (new IPC: hyprctl hyprpaper wallpaper MON,PATH,FIT)
#
#  Usage:
#    hyprpaper-picker.sh                  — selection menu (wofi)
#    hyprpaper-picker.sh /path/file.jpg   — set a specific file without menu
#
#  Dependencies: hyprctl, wofi, jq, notify-send (all present on the system)
#  Tested: Hyprland 0.56.2 + hyprpaper 0.8.4 (arch)
# ============================================================================

# ------------------------------- SETTINGS -----------------------------------
WALLPAPER_DIR="/home/alex/backgrounds"                       # wallpaper folder
HYPRPAPER_CONF="/home/alex/.config/hypr/hyprpaper.conf"      # hyprpaper config
FIT_MODE="cover"                                             # cover/contain/fit/tile
UPDATE_CONF=1                # 1 = remember choice in hyprpaper.conf (survives restart)
HYPRPAPER_LOG="${XDG_RUNTIME_DIR:-/tmp}/hyprpaper-picker.log" # selection and startup log
# ----------------------------------------------------------------------------

WALLPAPER_DIR="${WALLPAPER_DIR%/}"

msg()    { command -v notify-send >/dev/null 2>&1 && notify-send -a "hyprpaper-picker" -t 3000 "$@" >/dev/null 2>&1 || true; }
msg_err(){ command -v notify-send >/dev/null 2>&1 && notify-send -u critical -a "hyprpaper-picker" -t 5000 "$@" >/dev/null 2>&1 || true; }


if [ -z "$XDG_RUNTIME_DIR" ]; then
    XDG_RUNTIME_DIR="/run/user/$(id -u)"
    export XDG_RUNTIME_DIR
fi
if [ -z "$HYPRLAND_INSTANCE_SIGNATURE" ] && [ -d "$XDG_RUNTIME_DIR/hypr" ]; then
    for d in "$XDG_RUNTIME_DIR/hypr"/*; do
        [ -d "$d" ] || continue
        if [ -S "$d/.socket.sock" ] || [ -S "$d/.socket2.sock" ]; then
            export HYPRLAND_INSTANCE_SIGNATURE="${d##*/}"
            break
        fi
    done
fi
[ -n "$HYPRLAND_INSTANCE_SIGNATURE" ] || { msg_err "hyprpaper-picker" "Hyprland is not running"; exit 1; }


if ! pgrep -x hyprpaper >/dev/null 2>&1; then
    touch "$HYPRPAPER_LOG" 2>/dev/null || HYPRPAPER_LOG="/tmp/hyprpaper-picker.log"
    nohup /usr/bin/hyprpaper >>"$HYPRPAPER_LOG" 2>&1 &
    disown
    for _ in $(seq 1 100); do                  
        hyprctl hyprpaper listactive >/dev/null 2>&1 && break
        sleep 0.1
    done
    hyprctl hyprpaper listactive >/dev/null 2>&1 || { msg_err "hyprpaper-picker" "hyprpaper did not respond to IPC (see $HYPRPAPER_LOG)"; exit 1; }
fi


monitor="$(hyprctl -j monitors 2>/dev/null | jq -r '.[0].name // empty')"
[ -n "$monitor" ] || { msg_err "hyprpaper-picker" "Failed to determine monitor"; exit 1; }

if [ $# -ge 1 ]; then                            # CLI mode: file passed as argument
    full="$1"
    [ -f "$full" ] || { msg_err "hyprpaper-picker" "File not found: $full"; exit 1; }
    case "${full,,}" in
        *.jpg|*.jpeg|*.png|*.webp) ;;
        *) msg_err "hyprpaper-picker" "Not an image (needs .jpg/.jpeg/.png/.webp): $full"; exit 1 ;;
    esac
else
    shopt -s nullglob
    files=( "$WALLPAPER_DIR"/*.jpg  "$WALLPAPER_DIR"/*.jpeg  "$WALLPAPER_DIR"/*.png  "$WALLPAPER_DIR"/*.webp
            "$WALLPAPER_DIR"/*.JPG  "$WALLPAPER_DIR"/*.JPEG  "$WALLPAPER_DIR"/*.PNG  "$WALLPAPER_DIR"/*.WEBP )
    shopt -u nullglob
    if [ ${#files[@]} -eq 0 ]; then
        msg_err "hyprpaper-picker" "No .jpg/.jpeg/.png/.webp files in $WALLPAPER_DIR"
        exit 1
    fi

    declare -A path_of=()  
    items=""
    for f in "${files[@]}"; do
        n="$(basename "$f")"
        path_of["$n"]="$f"
        items+="$n"$'\n'
    done

    chosen="$(printf '%s' "$items" | wofi --dmenu -p "Wallpaper: $WALLPAPER_DIR" --insensitive)" || exit 0
    [ -n "$chosen" ] || exit 0                     # empty input = cancel
    full="${path_of[$chosen]}"
    [ -n "$full" ] || { msg_err "hyprpaper-picker" "Path not found for: $chosen"; exit 1; }
fi


if out="$(hyprctl hyprpaper wallpaper "$monitor,$full,$FIT_MODE" 2>&1)"; then
    msg "Wallpaper set" "$(basename "$full") → $monitor"
    printf '%s  %s: %s\n' "$(date '+%F %T')" "$monitor" "$full" >> "$HYPRPAPER_LOG" 2>/dev/null
else
    msg_err "Failed to set wallpaper" "$out"
    exit 1
fi


if [ "$UPDATE_CONF" -eq 1 ] && [ -w "$HYPRPAPER_CONF" ]; then
    esc="${full//\\/\\\\}"; esc="${esc//&/\\&}" 
    sed -i "s|^\(\s*path\s*=\s*\).*|\1${esc}|" "$HYPRPAPER_CONF"
fi