#!/bin/bash -ex

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

set +x
echo "Waiting for X server"
until [[ -e /var/run/appconfig/xserver_ready ]]; do sleep 1; done
echo "X server is ready"
set -x

# Forward js input control socket to shared pod volume.
if [[ -S /tmp/.uinput/js0ctl ]]; then
    echo "Forwarding socket /tmp/.uinput/js0ctl to /var/run/appconfig/js0ctl"
    sudo chown root:1000 /tmp/.uinput/js*ctl
    sudo chown root:1000 /dev/input/js* /dev/input/event* /dev/input/evdev/js*
    nohup sudo socat UNIX-RECV:/var/run/appconfig/js0ctl,reuseaddr UNIX-CLIENT:/tmp/.uinput/js0ctl &
fi

# Workaround for vulkan initialization
# https://bugs.launchpad.net/ubuntu/+source/nvidia-graphics-drivers-390/+bug/1769857
sudo LD_LIBRARY_PATH=${LD_LIBRARY_PATH} vulkaninfo >/dev/null

echo "Starting xpra"
xhost +

xpra start :0 \
    --use-display=yes \
    --user=app \
    --bind-tcp=0.0.0.0:${XPRA_PORT:-8082} \
    --html=on \
    --daemon=no \
    --no-pulseaudio \
    --clipboard=yes \
    --clipboard-direction=${XPRA_CLIPBOARD_DIRECTION:-"both"} \
    --file-transfer=${XPRA_FILE_TRANSFER:-"on"} \
    --open-files=${XPRA_OPEN_FILES:-"on"} \
    --video-encoders=nvenc ${XPRA_ARGS}

sleep 2