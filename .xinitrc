#!/bin/sh

# Auto-configure displays: dual-monitor mode when HDMI is connected,
# single-monitor mode otherwise.
if [ -x ~/.config/i3/autodisplay.sh ]; then
    ~/.config/i3/autodisplay.sh
fi

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
