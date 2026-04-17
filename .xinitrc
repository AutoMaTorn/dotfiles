#!/bin/sh

# Set maximum available refresh rate for each connected display
for output in $(xrandr | awk '/ connected/ {print $1}'); do
    read -r mode rate <<< "$(xrandr --query | awk -v out="$output" '
        $0 ~ "^"out" " { show=1; next }
        show && /^[^ ]/ { exit }
        show {
            res=$1
            for(i=2;i<=NF;i++) {
                gsub(/[+*]/, "", $i)
                if ($i ~ /^[0-9]+(\.[0-9]+)?$/) {
                    print res, $i
                }
            }
        }
    ' | sort -t' ' -k2 -n -r | head -n1)"

    if [ -n "$mode" ] && [ -n "$rate" ]; then
        xrandr --output "$output" --mode "$mode" --rate "$rate"
    fi
done

exec i3
