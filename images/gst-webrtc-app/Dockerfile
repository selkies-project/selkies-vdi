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

ARG BASE_IMAGE=gcr.io/cloud-solutions-images/webrtc-gpu-streaming-gst-base:latest

FROM ${BASE_IMAGE}

RUN \
    pip3 install websockets xlib gputil python-uinput prometheus_client msgpack pynput

RUN \
    apt-get update && apt-get install -y \
        sudo \
        udev \
        xclip \
        x11-utils \
        xdotool \
        wmctrl \
        x11-xserver-utils

# Build app
WORKDIR /opt/app
COPY *.py debug.sh /opt/app/

ENV PATH=/usr/local/nvidia/bin:${PATH}

# Add entrypoint script
COPY entrypoint.sh record.sh /
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]