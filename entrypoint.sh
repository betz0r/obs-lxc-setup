#!/bin/bash

# Fix GPU permissions at runtime
if [ -d /dev/dri ]; then
    chmod 666 /dev/dri/* || true
fi

# Create VNC password file
mkdir -p /root/.vnc
echo "${VNC_PASSWD:-123456}" | vncpasswd -f > /root/.vnc/passwd 2>/dev/null || true
chmod 600 /root/.vnc/passwd

# Start VNC server on display :1
echo "Starting VNC server..."
killall vncserver 2>/dev/null || true
sleep 1

vncserver :1 -geometry 1920x1080 -depth 24 -dpi 96 >/tmp/vncserver.log 2>&1 &
VNC_PID=$!
sleep 2

# Verify VNC is listening
echo "VNC server started, checking status..."
vncserver -list

# Start OBS in the background
echo "Starting OBS Studio..."
export DISPLAY=:1
export LIBVA_DRIVER_NAME=iHD
obs --startstreaming "$@" >/tmp/obs.log 2>&1 &
OBS_PID=$!

# Keep the container alive - monitor VNC and OBS
echo "Container started. Monitoring services..."
while true; do
    # Check if VNC process is still running
    if ! pgrep -f "Xtigervnc" > /dev/null; then
        echo "VNC process stopped, restarting..."
        killall vncserver 2>/dev/null || true
        sleep 1
        vncserver :1 -geometry 1920x1080 -depth 24 -dpi 96 >/tmp/vncserver.log 2>&1 &
        sleep 2
    fi

    if ! ps -p $OBS_PID > /dev/null 2>&1; then
        echo "OBS stopped, restarting..."
        obs --startstreaming >/tmp/obs.log 2>&1 &
        OBS_PID=$!
    fi

    sleep 10
done
