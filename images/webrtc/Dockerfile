# Copyright 2021 The Selkies Authors
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

ARG UBUNTU_RELEASE=20.04
FROM ubuntu:${UBUNTU_RELEASE}

ARG UBUNTU_RELEASE
ARG SELKIES_GSTREAMER_VERSION=1.2.0

ARG DEBIAN_FRONTEND=noninteractive

# Install selkies-gstreamer system dependencies
RUN apt-get update && apt-get install --no-install-recommends -y \
        build-essential \
        curl \
        python3-pip \
        python3-dev \
        python3-gi \
        python3-setuptools \
        python3-wheel \
        tzdata \
        sudo \
        udev \
        xclip \
        x11-utils \
        xdotool \
        wmctrl \
        jq \
        gdebi-core \
        x11-xserver-utils \
        xserver-xorg-core \
        libopus0 \
        libgdk-pixbuf2.0-0 \
        libsrtp2-1 \
        libxdamage1 \
        libxml2-dev \
        libwebrtc-audio-processing1 \
        libcairo-gobject2 \
        pulseaudio \
        libpulse0 \
        libpangocairo-1.0-0 \
        libgirepository1.0-dev && \
    rm -rf /var/lib/apt/lists/*

# Install latest selkies-gstreamer (https://github.com/selkies-project/selkies-gstreamer) build, Python application, and web application
RUN apt-get update && \
    cd /opt && \
    curl -fsSL "https://github.com/selkies-project/selkies-gstreamer/releases/download/v${SELKIES_GSTREAMER_VERSION}/selkies-gstreamer-v${SELKIES_GSTREAMER_VERSION}-ubuntu${UBUNTU_RELEASE}.tgz" | tar -zxf - && \
    curl -O -fsSL "https://github.com/selkies-project/selkies-gstreamer/releases/download/v${SELKIES_GSTREAMER_VERSION}/selkies_gstreamer-${SELKIES_GSTREAMER_VERSION}-py3-none-any.whl" && pip3 install "selkies_gstreamer-${SELKIES_GSTREAMER_VERSION}-py3-none-any.whl" && rm -f "selkies_gstreamer-${SELKIES_GSTREAMER_VERSION}-py3-none-any.whl" && \
    curl -fsSL "https://github.com/selkies-project/selkies-gstreamer/releases/download/v${SELKIES_GSTREAMER_VERSION}/selkies-gstreamer-web-v${SELKIES_GSTREAMER_VERSION}.tgz" | tar -zxf - && \
    rm -rf /var/lib/apt/lists/*

# Install Tini
ARG TINI_VERSION=v0.19.0
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini-amd64 /tini
RUN chmod +x /tini

# Create user
RUN apt-get update && apt-get install --no-install-recommends -y \
        sudo && \
    rm -rf /var/lib/apt/lists/* && \
    groupadd -g 1000 user && \
    useradd -ms /bin/bash user -u 1000 -g 1000 && \
    echo "user ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers && \
    chown user:user /home/user

# Install webrtc app dependencies
RUN apt-get update && apt-get install --no-install-recommends -y \
        imagemagick && \
    rm -rf /var/lib/apt/lists/*

# Add entrypoint scripts
COPY entrypoint.sh record.sh /
RUN chmod +x /entrypoint.sh

USER user
ENV PATH=/usr/local/nvidia/bin:${PATH}
ENTRYPOINT ["/tini", "--", "/entrypoint.sh"]