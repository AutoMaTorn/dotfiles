#!/bin/bash

ETH_IF=$(/usr/bin/ip link show | /usr/bin/awk '/^[0-9]+: e/{gsub(/:/,""); print $2; exit}')
WIFI_IF=$(/usr/bin/ip link show | /usr/bin/awk '/^[0-9]+: w/{gsub(/:/,""); print $2; exit}')

ETH_STATE=$(/usr/bin/cat /sys/class/net/"$ETH_IF"/operstate 2>/dev/null)
WIFI_STATE=$(/usr/bin/cat /sys/class/net/"$WIFI_IF"/operstate 2>/dev/null)

if [ "$ETH_STATE" = "up" ]; then
    echo "ETH"
elif [ "$WIFI_STATE" = "up" ]; then
    SSID=$(/sbin/iwgetid -r 2>/dev/null)
    [ -z "$SSID" ] && SSID=$(/usr/bin/nmcli -t -f active,ssid dev wifi | /usr/bin/awk -F: '$1=="yes" || $1=="да" {print $2; exit}')
    [ -n "$SSID" ] && echo "WIFI $SSID" || echo "WIFI"
else
    echo "disconnect network"
fi
