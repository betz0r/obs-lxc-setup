#!/bin/bash

# Fix GPU permissions at runtime
if [ -d /dev/dri ]; then
    chmod 666 /dev/dri/* || true
fi

# Create VNC password file
mkdir -p /root/.vnc
echo "${VNC_PASSWD:-123456}" | vncpasswd -f > /root/.vnc/passwd 2>/dev/null || true
chmod 600 /root/.vnc/passwd

# Start Xvfb (virtual framebuffer) for headless X11
echo "Starting virtual X server (Xvfb)..."
Xvfb :1 -screen 0 1920x1080x24 -ac +extension GLX +render -noreset >/tmp/xvfb.log 2>&1 &
XVFB_PID=$!
sleep 3

# Start VNC server on display :1
echo "Starting VNC server..."
vncserver :1 -geometry 1920x1080 -depth 24 -dpi 96 2>&1 | tee /tmp/vncserver.log || true
sleep 2

# Verify VNC is listening
if nc -z localhost 5901 2>/dev/null; then
    echo "VNC server is listening on port 5901"
else
    echo "WARNING: VNC server may not be listening"
    echo "Attempting to check vncserver status..."
    vncserver -list || echo "vncserver -list failed"
fi

# Start OBS in the background
echo "Starting OBS Studio..."
export DISPLAY=:1
export LIBVA_DRIVER_NAME=iHD
obs --startstreaming "$@" >/tmp/obs.log 2>&1 &
OBS_PID=$!

# Keep the container alive - monitor VNC and restart if needed
echo "Container started. Monitoring services..."
while true; do
    if ! nc -z localhost 5901 2>/dev/null; then
        echo "VNC not responding, restarting..."
        killall vncserver 2>/dev/null || true
        sleep 1
        vncserver :1 -geometry 1920x1080 -depth 24 -dpi 96 2>&1 || true
    fi

    if ! ps -p $OBS_PID > /dev/null 2>&1; then
        echo "OBS stopped, restarting..."
        obs --startstreaming >/tmp/obs.log 2>&1 &
        OBS_PID=$!
    fi

    sleep 10
done
