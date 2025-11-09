#!/bin/bash
set -e

# Fix GPU permissions at runtime
if [ -d /dev/dri ]; then
    chmod 666 /dev/dri/* || true
fi

# Create VNC password file if it doesn't exist
mkdir -p /root/.vnc
echo "${VNC_PASSWD:-123456}" | vncpasswd -f > /root/.vnc/passwd 2>/dev/null || true
chmod 600 /root/.vnc/passwd

# Start X server with VNC
echo "Starting X server with VNC server..."
vncserver :1 -geometry 1920x1080 -depth 24 -dpi 96 2>&1 || echo "VNC server startup output above"

# Give X server time to start
sleep 2

# Start OBS
echo "Starting OBS Studio..."
export DISPLAY=:1
exec obs --startstreaming "$@"
