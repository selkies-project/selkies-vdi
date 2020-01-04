#!/bin/bash

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

export DISPLAY=:0

# Patch Xwrapper to allow users to run X servers.
sudo sed -i 's/allowed_users=.*/allowed_users=anybody/g' /etc/X11/Xwrapper.config

# Start xorg in background
# The MIT-SHM extension here is important to achieve full frame rates
[[ -e ~/xorg.log ]] && mv ~/xorg.log ~/xorg.log.old
Xorg :0 -ac -novtswitch -sharevts -nolisten tcp +extension MIT-SHM > ~/xorg.log 2>&1 &

# Wait for X11 to start
echo "Waiting for X socket"
until [[ -S /tmp/.X11-unix/X0 ]]; do sleep 1; done
echo "X socket is ready"

echo "Waiting for X11 startup"
until xhost + >/dev/null 2>&1; do sleep 1; done
echo "X11 startup complete"

# Start pulseaudio
systemctl --user restart pulseaudio

# Grant user permission to /dev/uinput for gamepad support
sudo chmod ugo+rw /dev/uinput

# Set resolution
xrandr -s ${RESOLUTION}
xrandr --fb ${RESOLUTION}

# Start apps
xfce4-session