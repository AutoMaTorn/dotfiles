#!/bin/bash
# Show active network interface: ETH, WIFI or disconnect network

ETH_IF="eno1"
WIFI_IF="wlp9s0"

ETH_STATE=$(cat /sys/class/net/"$ETH_IF"/operstate 2>/dev/null)
WIFI_STATE=$(cat /sys/class/net/"$WIFI_IF"/operstate 2>/dev/null)

if [ "$ETH_STATE" = "up" ]; then
    echo "ETH"
elif [ "$WIFI_STATE" = "up" ]; then
    echo "WIFI"
else
    echo "disconnect network"
fi
