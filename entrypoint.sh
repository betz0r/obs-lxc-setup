#!/bin/bash
set -e

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
Xvfb :1 -screen 0 1920x1080x24 -ac +extension GLX +render -noreset 2>&1 | tee /tmp/xvfb.log &
XVFB_PID=$!
sleep 2

# Start VNC server pointing to the virtual display
echo "Starting VNC server..."
vncserver :1 -geometry 1920x1080 -depth 24 -dpi 96 2>&1 || true
sleep 2

# Verify VNC is listening
if nc -z localhost 5901 2>/dev/null; then
    echo "VNC server is listening on port 5901"
else
    echo "WARNING: VNC server may not be listening properly"
fi

# Start OBS
echo "Starting OBS Studio..."
export DISPLAY=:1
export LIBVA_DRIVER_NAME=iHD
exec obs --startstreaming "$@"
