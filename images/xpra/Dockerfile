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
        xserver-xephyr

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

# Install xpra
ADD https://xpra.org/repos/bionic/xpra.list /etc/apt/sources.list.d/xpra-beta.list
RUN curl -sfL https://xpra.org/gpg.asc | sudo apt-key add - && \
    sudo apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
        python3-requests \
        xpra

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

COPY entrypoint.sh desktop_resizer.sh /

# Create empty .menu file for xdg menu.
RUN \
    mkdir -p /etc/xdg/menus && \
    echo "<Menu></Menu>" > /etc/xdg/menus/kde-debian-menu.menu

# Patch to add full screen keyboard lock
RUN \
    sed -i 's|</body>|    <script type="application/javascript" src="js/keyboard-lock.js"></script>\n    </body>|' /usr/share/xpra/www/index.html && \
    rm -f /usr/share/xpra/www/index.html.*

COPY patch-fullscreen-keyboard-lock.js /usr/share/xpra/www/js/keyboard-lock.js

# Patch to add HTML5 printing fix
RUN \
    sed -i 's|</body>|    <script type="application/javascript" src="js/fix-printing.js"></script>\n    </body>|' /usr/share/xpra/www/index.html && \
    rm -f /usr/share/xpra/www/index.html.*

COPY patch-fix-printing.js /usr/share/xpra/www/js/fix-printing.js

# Patch to add HTML5 auto fullscreen feature
RUN \
    sed -i 's|</body>|    <script type="application/javascript" src="js/auto-fullscreen.js"></script>\n    </body>|' /usr/share/xpra/www/index.html && \
    rm -f /usr/share/xpra/www/index.html.*

COPY patch-auto-fullscreen.js /usr/share/xpra/www/js/auto-fullscreen.js

# Patch to fix broken minimize action
RUN \
    cd /usr/share/xpra/www/js && \
    sed -i 's|this.wid,True|this.wid,true|g' Window.js && \
    rm -f Window.js.* && \
    gzip -c Window.js > Window.js.gz

ENTRYPOINT ["/entrypoint.sh"]