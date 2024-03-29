# Copyright 2019 Google LLC
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

FROM debian:buster

# Install desktop environment
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        libgtk-3-dev \
        libglu1-mesa-dev \
        libnss3-dev \
        libasound2-dev \
        libgconf2-dev \
        libxv1 \
        libgtk2.0-0 \
        libsdl2-2.0-0 \
        libxss-dev \
        libxcb-keysyms1 \
        libopenal1 \
        mesa-utils \
        x11-xserver-utils \
        curl \
        ca-certificates \
        lsb-release \
        libvulkan1 \
        mesa-vulkan-drivers \
        vulkan-utils \
        vdpau-va-driver \
        vainfo \
        vdpauinfo \
        pulseaudio \
        pavucontrol \
        socat \
        jstest-gtk \
        dbus-x11 \
        sudo \
        procps \
        vim \
        xfwm4 \
        gdebi-core \
        libegl1-mesa && \
    rm -rf /var/lib/apt/lists/*

# Install VirtualGL for off-screen rendering with Xpra
RUN \
    VGL_PR_VERSION=$(curl -s https://s3.amazonaws.com/virtualgl-pr | sed 's,</,\n</,g' | grep -o -e "main/linux/virtualgl_.*_amd64.deb" | xargs basename | sort | tail -1) && \
    curl -fsSL -o /tmp/virtualgl.deb https://s3.amazonaws.com/virtualgl-pr/main/linux/${VGL_PR_VERSION} && \
    apt-get update && dpkg -i /tmp/virtualgl.deb && rm -f /tmp/virtualgl.deb

ENV PATH=${PATH}:/opt/VirtualGL/bin

# Install Vulkan ICD
COPY nvidia_icd.json /usr/share/vulkan/icd.d/

# Install EGL config
RUN mkdir -p /usr/share/glvnd/egl_vendor.d
COPY 10_nvidia.json /usr/share/glvnd/egl_vendor.d/

ENV DISPLAY :0
ENV SDL_AUDIODRIVER pulse

RUN groupadd --gid 1000 app && \
    adduser --uid 1000 --gid 1000 --disabled-password --gecos '' app

# Grant sudo to user for vulkan init workaround
RUN adduser app sudo
RUN echo "app ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/nopasswd

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]