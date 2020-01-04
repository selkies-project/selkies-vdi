FROM ubuntu:18.04

# Install essentials and chrome remote desktop package.
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
        sudo \
        vim \
        emacs \
        curl \
        htop \
        pulseaudio \
        gdebi-core && \
    curl -sfLO https://dl.google.com/linux/direct/chrome-remote-desktop_current_amd64.deb && \
        gdebi -n chrome-remote-desktop_current_amd64.deb && \
        rm chrome-remote-desktop_current_amd64.deb && \
    rm -rf /var/lib/apt/lists/*

# Patch chrome remote desktop to connect to existing X server.
RUN sed -i \
    -e 's/FIRST_X_DISPLAY_NUMBER = .*/FIRST_X_DISPLAY_NUMBER = 0/g' \
    -e '/while os.path.exists(X_LOCK_FILE_TEMPLATE % display):/ s/^#*/#/' \
    -e '/display += 1/ s/^#*/#/' \
    -e '/self._launch_x_session()/a\\n    display = self.get_unused_display_number()\n    self.child_env["DISPLAY"] = ":%d" % display' \
    -e '/self._launch_x_server(x_args)/ s/^#*/#/' \
    -e '/self._launch_x_session()/ s/^#*/#/' \
    -e 's|self.pulseaudio_pipe = pipe_name|self.pulseaudio_pipe = "/tmp/.pulse/pulse_fifo_output"|' \
    -e 's/DEFAULT_SIZES = .*/DEFAULT_SIZES = "1920x1080"/g' \
    /opt/google/chrome-remote-desktop/chrome-remote-desktop

# Create vdi user
# Chrome Remote Desktop cannot run as root.
RUN groupadd -g 1000 vdi && \
    useradd -g 1000 -u 1000 vdi -s /bin/bash && \
    passwd -d vdi && \
    mkdir -p /home/vdi && \
    chown 1000:1000 -R /home/vdi > /dev/null 2>&1 || true

# Add user to chrome-remote-desktop group
RUN adduser vdi chrome-remote-desktop 

# Grant user sudo
RUN adduser vdi sudo
RUN echo "vdi ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/nopasswd

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

USER vdi

# Set the DISPLAY variable.
ENV DISPLAY :0

WORKDIR /opt/google/chrome-remote-desktop

ENTRYPOINT ["/entrypoint.sh"]