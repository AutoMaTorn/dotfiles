#!/bin/sh
# Per-session setup for the i3 session.
#
# This used to live in ~/.xinitrc, which only startx/xinit read. Since login
# goes through GDM (gdm-x-session --run-script i3), .xinitrc is never sourced
# and everything in it silently stopped running — touch gestures and the
# touchpad tweaks had been dead. i3 reads its own config under every launcher,
# so putting the setup here and calling it from the i3 config makes it work
# under GDM, greetd+startx, or anything else.
#
# Must stay idempotent: the i3 config runs it with exec_always, so it re-runs
# on every i3 restart.

# Touchpad settings (fallback via xinput for immediate effect)
if command -v xinput >/dev/null 2>&1; then
    for id in $(xinput list | grep -iE 'touchpad|synaptics' | sed -n 's/.*id=\([0-9]*\).*/\1/p'); do
        xinput set-prop "$id" "libinput Tapping Enabled" 1 2>/dev/null || true
        xinput set-prop "$id" "libinput Tapping Drag Enabled" 1 2>/dev/null || true
        xinput set-prop "$id" "libinput Natural Scrolling Enabled" 0 2>/dev/null || true
        xinput set-prop "$id" "libinput Scroll Method Enabled" 0 1 0 2>/dev/null || true
        xinput set-prop "$id" "libinput Disable While Typing Enabled" 1 2>/dev/null || true
    done
fi

# Start the Touchegg *client*. Touchégg is split in two: a root daemon started
# by systemd (touchegg.service) that reads the raw libinput events, and a
# per-user client that owns touchegg.conf and performs the actions. Only the
# client belongs here.
#
# The guard must be scoped to this user: `pgrep -x touchegg` also matches the
# root daemon, which is always running, so an unscoped check is permanently
# true and the client never starts — gestures silently do nothing.
if command -v touchegg >/dev/null 2>&1 && ! pgrep -x -u "$(id -u)" touchegg >/dev/null 2>&1; then
    touchegg &
fi
