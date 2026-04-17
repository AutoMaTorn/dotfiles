#!/bin/sh

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

exec i3
