# Copyright 2020 Google LLC
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

ARG BASE_IMAGE=gcr.io/PROJECT_ID/vdi-proton-base
FROM ${BASE_IMAGE}

# Copy and extract the proton dist archive.
ARG DIST_ARCHIVE=proton_dist.tar.gz
WORKDIR /opt/proton
ADD ${DIST_ARCHIVE} .

ENV PATH=${PATH}:/opt/proton/bin

# Install basic window manager and runtime dependencies
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        dbus-x11 \
        xfwm4 \
        zip \
        sudo \
        socat \
        libfaudio0 \
        libvulkan1 \
        vulkan-utils \
        mesa-utils \
        mesa-vulkan-drivers \
        mesa-utils-extra \
        lxrandr \
        libxrandr-dev \
        jstest-gtk

# Install Vulkan ICD
COPY nvidia_icd.json /usr/share/vulkan/icd.d/

# Install EGL config
RUN mkdir -p /usr/share/glvnd/egl_vendor.d
COPY 10_nvidia.json /usr/share/glvnd/egl_vendor.d/

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Create app user
RUN groupadd -g 1000 app && \
    useradd -g 1000 -u 1000 app -s /bin/bash && \
    passwd -d app && \
    mkdir -p /home/app && \
    mkdir -p /home/app/.vnc && \
    echo "xsetroot -solid grey" > /home/app/.vnc/xstartup && \
    chmod +x /home/app/.vnc/xstartup && \
    chown 1000:1000 -R /home/app > /dev/null 2>&1 || true

# Grant sudo to user for vulkan init workaround
RUN adduser app sudo

RUN echo "app ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/nopasswd

USER app
ENV USER app

# Export library path for NVIDIA libs
ENV LD_LIBRARY_PATH /usr/local/nvidia/lib64:/usr/local/nvidia/lib32

# Set the DISPLAY variable.
ENV DISPLAY :0

# Set the PATH
ENV PATH ${PATH}:/usr/local/nvidia/bin:/usr/games

ENV RESOLUTION 1920x1080

ENTRYPOINT ["/entrypoint.sh"]