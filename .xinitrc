#!/bin/sh

# Load X resources (DPI, fonts)
if [ -f "$HOME/.Xresources" ]; then
    xrdb -merge "$HOME/.Xresources"
fi

# Scaling for GTK and Qt applications
export GDK_DPI_SCALE=1.5
export QT_SCALE_FACTOR=1.5

# Set maximum available refresh rate for the PREFERRED (native) resolution
# of each connected display. The preferred mode is marked with '+' in xrandr.
for output in $(xrandr | awk '/ connected/ {print $1}'); do
    # Find the preferred/native resolution (marked with +)
    preferred_mode=$(xrandr --query | awk -v out="$output" '
        $0 ~ "^"out" " { show=1; next }
        show && /^[^ ]/ { exit }
        show {
            for(i=2;i<=NF;i++) {
                if ($i ~ /\+/) {
                    print $1
                    exit
                }
            }
        }
    ')

    # Find the highest refresh rate for that preferred resolution
    mode_rate=$(xrandr --query | awk -v out="$output" -v mode="$preferred_mode" '
        $0 ~ "^"out" " { show=1; next }
        show && /^[^ ]/ { exit }
        show && $1 == mode {
            for(i=2;i<=NF;i++) {
                gsub(/[+*]/, "", $i)
                if ($i ~ /^[0-9]+(\.[0-9]+)?$/) {
                    print $1, $i
                }
            }
        }
    ' | sort -t' ' -k2 -n -r | head -n1)

    mode=$(printf '%s' "$mode_rate" | awk '{print $1}')
    rate=$(printf '%s' "$mode_rate" | awk '{print $2}')

    if [ -n "$mode" ] && [ -n "$rate" ]; then
        xrandr --output "$output" --mode "$mode" --rate "$rate"
    fi
done

# Touchpad settings (fallback via xinput for immediate effect)
if command -v xinput &>/dev/null; then
    for id in $(xinput list | grep -iE 'touchpad|synaptics' | sed -n 's/.*id=\([0-9]*\).*/\1/p'); do
        xinput set-prop "$id" "libinput Tapping Enabled" 1 2>/dev/null || true
        xinput set-prop "$id" "libinput Tapping Drag Enabled" 1 2>/dev/null || true
        xinput set-prop "$id" "libinput Natural Scrolling Enabled" 0 2>/dev/null || true
        xinput set-prop "$id" "libinput Scroll Method Enabled" 0 1 0 2>/dev/null || true
        xinput set-prop "$id" "libinput Disable While Typing Enabled" 1 2>/dev/null || true
    done
fi

# Start Touchegg gesture daemon (fallback if systemd user session didn't start it)
if command -v touchegg &>/dev/null; then
    touchegg &
fi

exec i3
