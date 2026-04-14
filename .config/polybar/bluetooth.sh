#!/bin/bash
# Show connected Bluetooth device name in polybar

DEVICE=$(bluetoothctl devices Connected 2>/dev/null | head -n 1)

if [ -n "$DEVICE" ]; then
    NAME=$(echo "$DEVICE" | sed 's/^Device [^ ]* //')
    echo "$NAME"
else
    echo "BT"
fi
