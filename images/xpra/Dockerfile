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

FROM ubuntu:bionic

# Install desktop environment
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        apt-transport-https \
        gnupg2 \
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
        x11-utils \
        x11-xserver-utils \
        xdotool \
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
        xfce4-terminal \
        gdebi-core \
        xserver-xephyr \
        git \
        uglifyjs

# Add Tini
ARG TINI_VERSION=v0.19.0
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini-amd64 /tini
RUN chmod +x /tini

# Printer support
RUN sudo apt-get update && sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
    cups-filters \
    cups-common \
    cups-pdf \
    python-cups

# Install ffmpeg-xpra
RUN curl -o ffmpeg-xpra.deb -L https://www.xpra.org/dists/bionic/main/binary-amd64/ffmpeg-xpra_4.0-1_amd64.deb && \
    gdebi -n ffmpeg-xpra.deb && \
    rm -f ffmpeg-xpra.deb

# Install other python dependencies
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    python3-requests \
    python3-setproctitle \
    python3-netifaces

# Install xpra
RUN curl -sfL https://xpra.org/beta/bionic/main/binary-amd64/xpra_4.2.1-r71-1_amd64.deb -o /opt/xpra_4.3-r29771-1_amd64.deb && \
    DEBIAN_FRONTEND=noninteractive gdebi -n /opt/xpra_4.3-r29771-1_amd64.deb

# Apply xpra patches
COPY xpra-prop-conv-py.patch /usr/lib/python3/dist-packages/xpra/x11/
RUN cd /usr/lib/python3/dist-packages/xpra/x11 && \
    sudo patch -p3 < xpra-prop-conv-py.patch && \
    sudo rm xpra-prop-conv-py.patch

# Remove xpra-html5 package, replaced with fork below.
RUN apt-get remove -y xpra-html5

# Install Xpra HTML5 client from forked submodule
# NOTE: installer depends on working non-submodule get repo.

# Supported minifiers are uglifyjs and copy
ARG MINIFIER=uglifyjs
COPY xpra-html5 /opt/xpra-html5
RUN cd /opt/xpra-html5 && \
    git config --global user.email "selkies@docker" && \
    git config --global user.name "Selkies Builder" && \
    git init && git checkout -b selkies-build-patches && \
    git add . && git commit -m "selkies-build-patches" && \
    mkdir -p /usr/share/xpra/www/js/lib && \
    sudo python3 ./setup.py install /usr/share/xpra/www ${MINIFIER}

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

# Add user to printer group
RUN usermod -a -G lpadmin app

# Create run directory for user
RUN sudo mkdir -p /run/user/1000 && sudo chown 1000:1000 /run/user/1000 && \
    sudo mkdir -p /run/xpra && sudo chown 1000:1000 /run/xpra

# Create empty .menu file for xdg menu.
RUN \
    mkdir -p /etc/xdg/menus && \
    echo "<Menu></Menu>" > /etc/xdg/menus/kde-debian-menu.menu

# Patch HTML for PWA
RUN \ 
    sed -i \
        -e 's|</head>|        <meta name="viewport" content="width=device-width, initial-scale=1.0">\n        </head>|' \
        -e 's|</head>|        <link rel="manifest" href="manifest.json" crossorigin="use-credentials">\n        </head>|' \
        -e 's|</head>|        <meta name="theme-color" content="white"/>\n        </head>|' \
        -e 's|</body>|        <script type="application/javascript">window.onload = () => {"use strict"; if ("serviceWorker" in navigator) { navigator.serviceWorker.register("./sw.js");}}</script>\n    </body>|' /usr/share/xpra/www/index.html && \
    rm -f /usr/share/xpra/www/index.html.*

# Replace connect.html with redirect to Selkies App Launcher
COPY connect.html /usr/share/xpra/www/connect.html
RUN rm -f /usr/share/xpra/www/connect.html.*

# Copy PWA source files
COPY pwa/manifest.json /usr/share/xpra/www/manifest.json
COPY pwa/sw.js /usr/share/xpra/www/sw.js

# Patch the service worker with a new cache version so that it is refreshed.
RUN sudo sed -i -e "s|CACHE_VERSION|$(date +%s)|g" '/usr/share/xpra/www/sw.js'

COPY entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/tini", "--", "/entrypoint.sh"]
