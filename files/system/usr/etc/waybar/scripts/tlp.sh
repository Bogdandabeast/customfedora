#!/bin/sh

mode=$(tlp-stat -s | grep "Mode" | awk '{print $3}')

if [ "$mode" = "AC" ]; then
    echo "AC"
else
    echo "BAT"
fi
