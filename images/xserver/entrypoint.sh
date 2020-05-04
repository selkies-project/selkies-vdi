#!/bin/bash

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

set -e

# Symlink for X11 virtual terminal
ln -sf /dev/ptmx /dev/tty7

# Forward mouse input control socket to shared pod volume.
if [[ -S /tmp/.uinput/mouse0ctl ]]; then
    echo "Forwarding socket /tmp/.uinput/mouse0ctl to /var/run/appconfig/mouse0ctl"
    nohup socat UNIX-RECV:/var/run/appconfig/mouse0ctl,reuseaddr UNIX-CLIENT:/tmp/.uinput/mouse0ctl &
fi

# Start xorg in background
# The MIT-SHM extension here is important to achieve full frame rates
nohup Xorg ${DISPLAY} -novtswitch -sharevts -nolisten tcp +extension MIT-SHM vt7 &

# Wait for X11 to start
echo "Waiting for X socket"
until [[ -S /tmp/.X11-unix/X${DISPLAY/:/} ]]; do sleep 1; done
echo "X socket is ready"

echo "Waiting for X11 startup"
until xhost + >/dev/null 2>&1; do sleep 1; done
echo "X11 startup complete"

# Notify sidecar containers
touch /var/run/appconfig/xserver_ready

# Foreground process, tail logs
tail -F /var/log/Xorg.${DISPLAY/:/}.log