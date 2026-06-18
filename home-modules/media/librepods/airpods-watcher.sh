# shellcheck shell=bash
airpods_connected() {
    local paired addr info icon connected
    paired=$(bluetoothctl devices Paired 2>/dev/null | awk '{print $2}')
    [[ -z "$paired" ]] && return 1
    while IFS= read -r addr; do
        info=$(bluetoothctl info "$addr" 2>/dev/null)
        icon=$(printf '%s' "$info" | awk '/Icon:/{print $2}')
        connected=$(printf '%s' "$info" | awk '/Connected:/{print $2}')
        [[ "$icon" == "audio-headphones" && "$connected" == "yes" ]] && return 0
    done <<< "$paired"
    return 1
}

sync_librepods() {
    if airpods_connected; then
        systemctl --user start librepods.service 2>/dev/null || true
    else
        systemctl --user stop librepods.service 2>/dev/null || true
        sleep 2
        easyeffects --bypass 1
        sleep 0.5
        easyeffects --bypass 2
    fi
}

sync_librepods

tail -f /dev/null | bluetoothctl 2>/dev/null | while IFS= read -r line; do
    [[ "$line" == *"Connected: "* ]] && sync_librepods
done
