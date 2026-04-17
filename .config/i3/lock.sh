#!/bin/sh
# Lock screen with blur effect if ImageMagick is available,
# otherwise fall back to solid color matching i3 theme.

if command -v convert >/dev/null 2>&1; then
    tmpimg="/tmp/i3lock-$(date +%s).png"
    maim "$tmpimg" 2>/dev/null || import -window root "$tmpimg" 2>/dev/null
    if [ -f "$tmpimg" ]; then
        convert "$tmpimg" -blur 0x8 "$tmpimg"
        i3lock -i "$tmpimg" -e
        rm -f "$tmpimg"
        exit 0
    fi
fi

# Fallback: solid background matching i3 theme
i3lock -c 181818 -e
