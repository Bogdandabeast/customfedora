#!/bin/sh

power=$(bluetoothctl show | grep "Powered" | awk '{print $2}')

if [ "$power" = "yes" ]; then
    device=$(bluetoothctl info | grep "Name" | awk -F': ' '{print $2}')
    if [ -n "$device" ]; then
        echo "$device"
    else
        echo "On"
    fi
else
    echo "Off"
fi
