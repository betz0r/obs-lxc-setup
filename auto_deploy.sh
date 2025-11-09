#!/bin/bash
set -e

# User Configuration
CONTAINER_NAME="obs-vnc-lxc"
TEMPLATE="local:vztmpl/ubuntu-24.04-standard_24.04-2_amd64.tar.zst"
STORAGE="local-lvm"
MEMORY=2048
CORES=4
DISK_SIZE=60
SHARED_DIR="/host/shared"
ARCH="amd64"
DNS_SERVER="192.168.1.162"
UNPRIVILEGED=0  # Set to 0 for privileged container (GPU access)

# Function to check and download LXC template
function check_template() {
    echo "Checking for Ubuntu 24.04 template..."
    if ! pveam list local | grep -q "ubuntu-24.04-standard"; then
        echo "Template not found. Downloading the Ubuntu 24.04 template..."
        pveam update
        if ! pveam download local ubuntu-24.04-standard_24.04-2_amd64.tar.zst; then
            echo "Error: Failed to download template. Check your network or Proxmox storage."
            exit 1
        fi
    else
        echo "Template already exists."
    fi
}

# Function to check and create the shared directory
function create_shared_dir() {
    if [ ! -d "${SHARED_DIR}" ]; then
        echo "Creating shared directory on the host: ${SHARED_DIR}"
        mkdir -p ${SHARED_DIR}
        chmod 777 ${SHARED_DIR}
    fi
}

# Function to prompt for Container ID
function prompt_container_id() {
    while true; do
        read -p "Enter the Container ID (e.g., 120): " CONTAINER_ID

        # Check if input is a valid number
        if ! [[ "${CONTAINER_ID}" =~ ^[0-9]+$ ]]; then
            echo "Error: Container ID must be a number. Please try again."
            continue
        fi

        # Check if the Container ID is already in use
        if pct list | grep -q "^\\s*${CONTAINER_ID}\\s"; then
            echo "Error: Container ID ${CONTAINER_ID} is already in use. Please choose another ID."
            continue
        fi

        break
    done
}

# Function to prompt for root password
function prompt_root_password() {
    while true; do
        read -sp "Enter the root password for the container: " ROOT_PASSWORD
        echo
        read -sp "Confirm the root password: " CONFIRM_PASSWORD
        echo

        if [ "${ROOT_PASSWORD}" != "${CONFIRM_PASSWORD}" ]; then
            echo "Error: Passwords do not match. Please try again."
        else
            echo "Password confirmed."
            break
        fi
    done
}

# Step 1: Prompt for Container ID
prompt_container_id

# Step 2: Prompt for Root Password
prompt_root_password

# Step 3: Check and Download Template
check_template

# Step 4: Create Shared Directory
create_shared_dir

# Step 5: Create the LXC container
echo "Creating LXC container with ID ${CONTAINER_ID}..."
pct create ${CONTAINER_ID} ${TEMPLATE} \
    --ostype ubuntu \
    --arch ${ARCH} \
    --features nesting=1 \
    --hostname ${CONTAINER_NAME} \
    --storage ${STORAGE} \
    --cores ${CORES} \
    --memory ${MEMORY} \
    --rootfs ${STORAGE}:${DISK_SIZE} \
    --net0 name=eth0,bridge=vmbr0,ip=dhcp,hwaddr=BC:24:11:90:EA:23 \
    --password "${ROOT_PASSWORD}"

# Step 6: Configure LXC container for Podman with GPU access
echo "Configuring LXC container for privileged Podman with GPU support..."
cat >> /etc/pve/lxc/${CONTAINER_ID}.conf <<EOF

# Additional LXC Configuration for Podman with GPU
unprivileged: ${UNPRIVILEGED}
mp0: ${SHARED_DIR},mp=/shared
nameserver: ${DNS_SERVER}

# AppArmor and Capabilities for Podman
lxc.apparmor.profile: unconfined
lxc.cap.drop:

# Device access for hardware
lxc.cgroup2.devices.allow: c 226:* rwm
lxc.mount.entry: /dev/dri dev/dri none bind,optional,create=dir

# Network namespace support for Podman
lxc.mount.entry: /dev/net/tun dev/net/tun none bind,optional,create=file
EOF

# Step 7: Start the container
echo "Starting the container..."
pct start ${CONTAINER_ID}

# Step 8: Install OBS, VNC, and dependencies directly in LXC container
echo "Installing OBS, VNC server, and dependencies..."
pct exec ${CONTAINER_ID} -- bash -c "
    # Fix DNS resolution
    echo 'nameserver ${DNS_SERVER}' > /etc/resolv.conf

    # Update the repository
    echo 'Updating the repository...'
    apt update -y && apt upgrade -y

    # Install OBS Studio
    echo 'Installing OBS Studio...'
    apt install -y software-properties-common
    add-apt-repository ppa:obsproject/obs-studio
    apt update -y
    apt install -y obs-studio

    # Install VNC server and X11
    echo 'Installing VNC server and X11...'
    apt install -y tigervnc-standalone-server x11-apps xvfb

    # Install GPU drivers for hardware encoding
    echo 'Installing GPU drivers...'
    apt install -y vainfo libva2 intel-media-va-driver-non-free

    # Create VNC password file
    mkdir -p /root/.vnc
    echo '123456' | vncpasswd -f > /root/.vnc/passwd
    chmod 600 /root/.vnc/passwd

    # Create startup script for VNC and OBS
    cat > /root/start-obs-vnc.sh << 'SCRIPT'
#!/bin/bash
# Start VNC server on display :1
echo 'Starting VNC server...'
vncserver :1 -geometry 1920x1080 -depth 24 -dpi 96 -localhost no -noxstartup

sleep 2

# Start OBS with GPU encoding
echo 'Starting OBS Studio...'
export DISPLAY=:1
export LIBVA_DRIVER_NAME=iHD

# Fix GPU permissions
chmod 666 /dev/dri/* 2>/dev/null || true

obs --startstreaming

SCRIPT
    chmod +x /root/start-obs-vnc.sh

    # Create systemd service
    cat > /etc/systemd/system/obs-vnc.service << 'SERVICE'
[Unit]
Description=OBS with VNC Server
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=/root
ExecStart=/root/start-obs-vnc.sh
Restart=always
RestartSec=10
Environment=\"PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin\"

[Install]
WantedBy=multi-user.target

SERVICE
    chmod 644 /etc/systemd/system/obs-vnc.service

    # Enable and start the service
    systemctl daemon-reload
    systemctl enable obs-vnc
    systemctl start obs-vnc
"

echo "Deployment complete! OBS with VNC is running on port 5901."
echo "Access VNC at: http://\$(pct exec ${CONTAINER_ID} hostname -I | awk '{print \$1}'):6080/vnc.html"
