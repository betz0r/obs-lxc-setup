FROM docker.io/bandi13/gui-docker:1.5

USER root

RUN export DEBIAN_FRONTEND=noninteractive \
    && apt update -y \
    && apt install -y software-properties-common \
    && apt update -y \
    && add-apt-repository ppa:obsproject/obs-studio \
    && apt update -y \
    && apt install -y obs-studio \
    && sed -i 's/^deb \(.*\)$/deb \1\ndeb \1 contrib non-free-firmware/' /etc/apt/sources.list.d/debian.sources 2>/dev/null || echo "deb http://deb.debian.org/debian bookworm contrib non-free-firmware" >> /etc/apt/sources.list \
    && apt update -y \
    && apt install -y vainfo libva2 intel-media-va-driver-non-free \
    && apt clean -y

RUN echo "?package(bash):needs=\"X11\" section=\"DockerCustom\" title=\"OBS Screencast\" command=\"obs\"" >> /usr/share/menu/custom-docker && update-menus

# Set environment variables for VNC password
ENV VNC_PASSWD=123456
ENV SHARED_DIR=/shared

# Create a shared directory inside the container
RUN mkdir -p ${SHARED_DIR} && chmod -R 777 ${SHARED_DIR}

RUN usermod -aG video root

# Keep the container alive with a dummy loop
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]

# Keep the container alive with a dummy loop
CMD ["tail", "-f", "/dev/null"]