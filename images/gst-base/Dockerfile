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

FROM ubuntu:20.04

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

# Checkout hashed commits with CUDA buffer support.
# This can be removed once MR 1633 is on a release tag:
#   https://gitlab.freedesktop.org/gstreamer/gst-plugins-bad/merge_requests/1633
ARG GSTREAMER_VERSION=77e6c98f6fe7cfb2e6891560c5a1e7bd36d41fec
ARG GST_PLUGINS_BASE_VERSION=932dfd4031bff98df65a045230b03b40c00a5271
ARG GST_PLUGINS_GOOD_VERSION=39c6bc0507554098181baeb01f7cb53718c81bd6
ARG GST_PLUGINS_BAD_VERSION=1138c798ffa6d9b500393cc537db60b805b36e59
ARG GST_PLUGINS_UGLY_VERSION=a9105ad1e1fb8cbcf787c2a967697707eea405ed
ARG GST_PYTHON_VERSION=7a0decbec242b026391ff6504f0619259aa34721

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
ARG USRSCTP_VERSION=dce5c0ed0724356f42b26666714646b76376b24e
RUN \
    git clone https://github.com/sctplab/usrsctp.git && \
    cd usrsctp && git checkout ${USRSCTP_VERSION} && \
    ./bootstrap && ./configure --prefix=/usr && \
        make && make install && make clean

# Install libnice from source
ARG LIBNICE_VERSION=1dbe38d6abe74c415bf4ae44190980c61874a04f
RUN \
    git clone https://gitlab.freedesktop.org/libnice/libnice.git && \
    cd libnice && git checkout ${LIBNICE_VERSION} && \
    meson build --prefix=/usr && \
    ninja -C build install

# Install gst-plugins-bad from source
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