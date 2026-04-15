#!/bin/bash

BAT=$(basename /sys/class/power_supply/BAT* 2>/dev/null | head -n1)

if [ -z "$BAT" ] || [ ! -d "/sys/class/power_supply/$BAT" ]; then
    echo ""
    exit 0
fi

CAPACITY=$(cat "/sys/class/power_supply/$BAT/capacity" 2>/dev/null)
STATUS=$(cat "/sys/class/power_supply/$BAT/status" 2>/dev/null)

if [ "$STATUS" = "Charging" ]; then
    echo "CHARGING ${CAPACITY}%"
else
    echo "BAT ${CAPACITY}%"
fi
