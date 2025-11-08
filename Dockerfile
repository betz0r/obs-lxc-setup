FROM bandi13/gui-docker:1.5

USER root

RUN export DEBIAN_FRONTEND=noninteractive \
    && apt-get update -y \
    && apt-get install -y software-properties-common \
    && add-apt-repository ppa:obsproject/obs-studio \
    && apt-get update -y \
    && apt-get install -y obs-studio \
    && apt-get clean -y

RUN apt-get update -y && apt-get install -y vainfo libva2 intel-media-va-driver-non-free i965-va-driver

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