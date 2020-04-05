# Copyright 2019 Google Inc. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Download Jetbrains Toolbox and extract appimage
FROM ubuntu:16.04 as jetbrains
WORKDIR /tmp
ADD https://data.services.jetbrains.com/products/download?platform=linux&code=TBA ./jetbrains-toolbox.tar.gz
RUN tar --strip-components=1 -zxvf jetbrains-toolbox.tar.gz

# Extract the AppImage, output will be in /tmp/appimage
RUN chmod +x jetbrains-toolbox && \
    "./jetbrains-toolbox" --appimage-extract && \
    find squashfs-root -type d -exec chmod ugo+rx {} \; && \
    chown -R 1000:1000 squashfs-root && \
    mv squashfs-root appimage

# Build cloudshell image with Desktop environment
FROM gcr.io/cloudshell-images/cloudshell:latest

# Copy shared config files
WORKDIR /usr/share/cloudshell
COPY config/* ./

# Install base dependencies
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
        bsdtar \
        gdebi-core \
        gnupg2

# Download git-prompt to use as default prompt.
RUN curl -sfL -o /usr/share/cloudshell/git-prompt.sh \
	https://raw.githubusercontent.com/git/git/master/contrib/completion/git-prompt.sh

# Install Chrome browser
RUN curl -sfL https://dl.google.com/linux/linux_signing_key.pub | sudo apt-key add - && \
    curl -sfLO https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb && \
    gdebi -n google-chrome-stable_current_amd64.deb

# Install desktop environment and terminal
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y \
        xfce4 \
        terminator

# Install Vulkan, OpenGL-ES and GLX libraries.
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y \
        libvulkan1 \
        vulkan-utils \
        mesa-utils \
        mesa-vulkan-drivers \
        mesa-utils-extra \
        libxrandr-dev \
        vdpau-va-driver \
        vainfo \
        vdpauinfo

# Install socat for uinput control socket forwarding
RUN apt-get install -y \
    jstest-gtk \
    socat

# Install Jetbrains Toolbox and desktop shortcut
COPY --from=jetbrains /tmp/appimage /opt/jetbrains-toolbox
RUN \
    sudo mkdir -p /etc/skel/Desktop && printf "[Desktop Entry]\nVersion=1.0\nType=Application\nExec=env APPDIR=/opt/jetbrains-toolbox /opt/jetbrains-toolbox/AppRun\nPath=/opt/jetbrains-toolbox\nName=Jetbrains Toolbox\nIcon=/opt/jetbrains-toolbox/jetbrains-toolbox.svg\nTerminal=false\n" | sudo tee /etc/skel/Desktop/Jetbrains.desktop && \
    sudo chmod +x /etc/skel/Desktop/Jetbrains.desktop

# Install VS Code
RUN \
    wget -q https://packages.microsoft.com/keys/microsoft.asc -O- | sudo apt-key add - && \
    sudo add-apt-repository "deb [arch=amd64] https://packages.microsoft.com/repos/vscode stable main" && \
    sudo apt update && sudo apt install -y code
RUN \
    sudo mkdir -p /etc/skel/Desktop && sudo cp /usr/share/applications/code.desktop /etc/skel/Desktop/ && \
    sudo chmod +x /etc/skel/Desktop/code.desktop

# Install Vulkan ICD
COPY nvidia_icd.json /usr/share/vulkan/icd.d/

# Install EGL config
RUN mkdir -p /usr/share/glvnd/egl_vendor.d
COPY 10_nvidia.json /usr/share/glvnd/egl_vendor.d/

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Add user and grant sudo
RUN adduser --gecos '' --disabled-password --shell /bin/bash coder && \
	echo "coder ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/nopasswd

WORKDIR /home/coder/project

# Prevent zombie python processes whenever gcloud is run.
RUN gcloud config set disable_usage_reporting true

# Use bash as default shell
ENV SHELL /bin/bash
ENV USER coder
ENV PATH ${PATH}:/usr/local/nvidia/bin:/home/coder/bin

# Export library path for NVIDIA libs
ENV LD_LIBRARY_PATH /usr/local/nvidia/lib64

# Set the DISPLAY variable.
ENV DISPLAY :0

# Set SDL audio driver to use pulseaudio
ENV SDL_AUDIODRIVER pulse

ENTRYPOINT ["/entrypoint.sh"]
