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

FROM ubuntu:19.10

# Use GCE apt servers
ARG GCE_REGION=us-west1
RUN cp /etc/apt/sources.list /etc/apt/sources.list.orig && \
    sed -i "s/archive.ubuntu.com/${GCE_REGION}.gce.archive.ubuntu.com/g" /etc/apt/sources.list

# Install essentials
RUN \
    apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        curl \
        build-essential \
        ca-certificates \
        git \
        vim

WORKDIR /opt

ARG GSTREAMER_VERSION=1.18.0
ARG GST_PLUGINS_BASE_VERSION=1.18.0
ARG GST_PLUGINS_GOOD_VERSION=1.18.0
ARG GST_PLUGINS_BAD_VERSION=1.18.0
ARG GST_PLUGINS_UGLY_VERSION=1.18.0
ARG GST_PYTHON_VERSION=1.18.0

# cloner repo for each gstreamer module
RUN git clone https://gitlab.freedesktop.org/gstreamer/gstreamer.git && cd gstreamer && git checkout ${GSTREAMER_VERSION}
RUN git clone https://gitlab.freedesktop.org/gstreamer/gst-plugins-base.git && cd gst-plugins-base && git checkout ${GST_PLUGINS_BASE_VERSION}
RUN git clone https://gitlab.freedesktop.org/gstreamer/gst-plugins-good && cd gst-plugins-good && git checkout ${GST_PLUGINS_GOOD_VERSION}
RUN git clone https://gitlab.freedesktop.org/gstreamer/gst-plugins-bad && cd gst-plugins-bad && git checkout ${GST_PLUGINS_BAD_VERSION}
RUN git clone https://gitlab.freedesktop.org/gstreamer/gst-plugins-ugly && cd gst-plugins-ugly && git checkout ${GST_PLUGINS_UGLY_VERSION}
RUN git clone https://gitlab.freedesktop.org/gstreamer/gst-python && cd gst-python && git checkout ${GST_PYTHON_VERSION}

WORKDIR /opt

# Install base build deps
RUN \
    apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        autopoint \
        autoconf \
        automake \
        autotools-dev \
        libtool \
        gettext \
        bison \
        flex \
        gtk-doc-tools \
        libtool-bin \
        libgtk2.0-dev \
        libgl1-mesa-dev \
        libopus-dev \
        libpulse-dev \
        libgirepository1.0-dev

# Install meson build deps
RUN \
    apt-get update && apt install -y python3-pip python-gi-dev ninja-build && \
    pip3 install meson

# Build gstreamer
RUN \
    cd /opt/gstreamer && \
    meson build --prefix=/usr && \
    ninja -C build install

# Build gstreamer-base
RUN \
    cd /opt/gst-plugins-base && \
    meson build --prefix=/usr && \
    ninja -C build install

# Install deps for gst-plugins-good
RUN \
    apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        libvpx-dev \
        libvpx6

# Build gst-plugins-good
RUN \
    cd /opt/gst-plugins-good && \
    meson build --prefix=/usr && \
    ninja -C build install

# Build gst-instruments from source
ARG GST_INSTRUMENTS_VERSION=0.2.4
RUN \
    cd /opt/ && \
    git clone https://github.com/kirushyk/gst-instruments.git && \
    cd gst-instruments && git checkout ${GST_INSTRUMENTS_VERSION} && \
    ./autogen.sh --prefix=/usr && \
    make -j8 && make install

# Install deps for gst-plugins-bad
RUN \
    apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        libwebrtc-audio-processing-dev \
        libssl-dev \
        libsrtp2-dev

# Install usrsctp from source
ARG USRSCTP_VERSION=6ce0f8fe7455e566a6833684ec5983547658856d
RUN \
    git clone https://github.com/sctplab/usrsctp.git && \
    cd usrsctp && git checkout ${USRSCTP_VERSION} && \
    ./bootstrap && ./configure --prefix=/usr && \
        make && make install && make clean

# Install libnice from source
ARG LIBNICE_VERSION=d6087ae5e0c1de2555f64d792c144d49bd816920
RUN \
    git clone https://gitlab.freedesktop.org/libnice/libnice.git && \
    cd libnice && git checkout ${LIBNICE_VERSION} && \
    meson build --prefix=/usr && \
    ninja -C build install

# Checkout experimental CUDA convert branch.
# This can be removed once MR 526 is merged:
#   https://gitlab.freedesktop.org/gstreamer/gst-plugins-bad/merge_requests/526
RUN \
    cd /opt/gst-plugins-bad && \
    git fetch https://gitlab.freedesktop.org/danisla/gst-plugins-bad.git gst-cuda-filter-1.18 && \
    git checkout -b gst-cuda-filter FETCH_HEAD

# Install gst-plugins-bad from source
# Note that the branch being used contains the nvcodec refactor
# that loads the nvidia libraries at runtime, so no existing 
# libs need to be present when building the plugin. 
# This is the case for gstreamer 1.17+.
RUN \
    cd /opt/gst-plugins-bad && \
    meson build --prefix=/usr && \
    ninja -C build install

# Install gst-python from source
RUN \
    cd /opt/gst-python && \
    meson build --prefix=/usr \
        -Dpygi-overrides-dir=/usr/lib/python3/dist-packages/gi/overrides && \
    ninja -C build install

# Install GstShark for latency tracing
ARG GST_SHARK_VERSION=v0.6.1
RUN \
    apt-get update && apt install -y graphviz libgraphviz-dev && \
    cd /opt && \
    git clone --depth 1 https://github.com/RidgeRun/gst-shark -b ${GST_SHARK_VERSION} && \
    cd gst-shark && ./autogen.sh --prefix=/usr && \
        make && make install && make clean

# Build and install gst-plugins-ugly from source
# This package includes the x264 encoder for non-nvenc accelerated pipelines.
RUN \
    apt-get update && apt install -y libx264-155 libx264-dev

RUN \
    cd /opt/gst-plugins-ugly && \
    meson build --prefix=/usr && \
    ninja -C build install