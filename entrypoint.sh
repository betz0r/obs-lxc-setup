#!/bin/bash

# Fix GPU permissions at runtime
if [ -d /dev/dri ]; then
    chmod 666 /dev/dri/* || true
fi

# Start OBS in the background with virtual display
echo "Starting OBS Studio..."
export DISPLAY=:0
export LIBVA_DRIVER_NAME=iHD
obs --startstreaming "$@" >/tmp/obs.log 2>&1 &
OBS_PID=$!

echo "OBS PID: $OBS_PID"

# Keep the container alive and monitor OBS
echo "Container started. Monitoring OBS..."
while true; do
    if ! ps -p $OBS_PID > /dev/null 2>&1; then
        echo "OBS stopped, restarting..."
        obs --startstreaming >/tmp/obs.log 2>&1 &
        OBS_PID=$!
        echo "OBS restarted with PID: $OBS_PID"
    fi

    sleep 10
done
