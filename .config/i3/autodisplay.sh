#!/bin/sh
# Автоматическое переключение между режимом одного и двух мониторов

# Получить список подключённых выходов
CONNECTED=$(xrandr | awk '/ connected/ {print $1}')

# Найти внутренний (eDP) и внешний (HDMI) выходы
EDP=$(echo "$CONNECTED" | grep -E '^eDP' | head -n1)
HDMI=$(echo "$CONNECTED" | grep -E '^HDMI' | head -n1)

# Функция: получить предпочтительное разрешение (native, отмечено +)
get_preferred_mode() {
    local out=$1
    xrandr --query | awk -v out="$out" '
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
    '
}

# Функция: получить максимальную частоту для заданного разрешения
get_max_rate() {
    local out=$1
    local mode=$2
    xrandr --query | awk -v out="$out" -v mode="$mode" '
        $0 ~ "^"out" " { show=1; next }
        show && /^[^ ]/ { exit }
        show && $1 == mode {
            for(i=2;i<=NF;i++) {
                gsub(/[+\*]/, "", $i)
                if ($i ~ /^[0-9]+(\.[0-9]+)?$/) {
                    print $i
                }
            }
        }
    ' | sort -n -r | head -n1
}

# Функция: применить оптимальный режим к выходу
apply_optimal() {
    local out=$1
    local mode=$(get_preferred_mode "$out")
    local rate=$(get_max_rate "$out" "$mode")
    if [ -n "$mode" ] && [ -n "$rate" ]; then
        xrandr --output "$out" --mode "$mode" --rate "$rate"
    else
        xrandr --output "$out" --auto
    fi
}

if [ -n "$EDP" ] && [ -n "$HDMI" ]; then
    # Режим двух мониторов: внешний сверху
    mode=$(get_preferred_mode "$HDMI")
    rate=$(get_max_rate "$HDMI" "$mode")
    if [ -n "$mode" ] && [ -n "$rate" ]; then
        xrandr --output "$HDMI" --mode "$mode" --rate "$rate" --above "$EDP" --output "$EDP" --auto
    else
        xrandr --output "$HDMI" --above "$EDP" --auto --output "$EDP" --auto
    fi
elif [ -n "$EDP" ]; then
    # Только внутренний монитор
    xrandr --output "$HDMI" --off 2>/dev/null || true
    apply_optimal "$EDP"
else
    # Только внешний монитор (или вообще ничего — на всякий случай)
    xrandr --output "$EDP" --off 2>/dev/null || true
    [ -n "$HDMI" ] && apply_optimal "$HDMI"
fi
