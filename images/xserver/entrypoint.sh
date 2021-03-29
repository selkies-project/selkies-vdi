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

set -ex

function finish {
    rm -f /var/run/appconfig/xserver_ready
}
trap finish EXIT

# Symlink for X11 virtual terminal
ln -sf /dev/ptmx /dev/tty7

# Forward mouse input control socket to shared pod volume.
if [[ -S /tmp/.uinput/mouse0ctl ]]; then
    echo "Forwarding socket /tmp/.uinput/mouse0ctl to /var/run/appconfig/mouse0ctl"
    nohup socat UNIX-RECV:/var/run/appconfig/mouse0ctl,reuseaddr UNIX-CLIENT:/tmp/.uinput/mouse0ctl &
fi

# Start dbus
rm -rf /var/run/dbus
dbus-uuidgen | tee /var/lib/dbus/machine-id
mkdir -p /var/run/dbus
dbus-daemon --config-file=/usr/share/dbus-1/system.conf --print-address

export RESOLUTION=${RESOLUTION:-"1920x1080"}
export PID=$$
if [[ "${X11_DRIVER:-"nvidia"}" == "nvidia" ]]; then
    echo "Starting X11 server with NVIDIA GPU driver."

    # Find PCI bus ID and update Xorg.conf
    BUS_ID=$(lspci | grep NVIDIA | cut -d' ' -f1)
    [[ -z "${BUS_ID}" ]] && echo "ERROR: Failed to find NVIDIA device PCI bus id" && exit 1
    # Extract PCI bus ID from lspci output.
    XORG_BUS_ID=$(printf "PCI:0:%.0f:0" ${BUS_ID/*:/})
    echo "Updating /etc/X11/xorg.conf with NVIDIA device BusId ${XORG_BUS_ID}"
    # Patch Xorg.conf
    sed -i 's/BusId.*/BusId          "'${XORG_BUS_ID}'"/g' /etc/X11/xorg.conf

    # Start xorg in background
    # The MIT-SHM extension here is important to achieve full frame rates
    Xorg ${DISPLAY} -novtswitch -sharevts -nolisten tcp +extension MIT-SHM vt7 &
    PID=$!
else
    echo "Starting X11 server with software video driver."
    Xvfb -screen ${DISPLAY} 8192x4096x24 +extension RANDR +extension GLX +extension MIT-SHM -nolisten tcp -noreset -shmem &
    PID=$!
fi

# Wait for X11 to start
set +x
echo "Waiting for X socket"
until [[ -S /tmp/.X11-unix/X${DISPLAY/:/} ]]; do sleep 1; done
echo "X socket is ready"
set -x

echo "Waiting for X11 startup"
until xhost + >/dev/null 2>&1; do sleep 1; done
echo "X11 startup complete"

if [[ "${X11_DRIVER:-"nvidia"}" != "nvidia" ]]; then
    # Add default modes
    for res in 1280x720 1920x1080 2560x1440; do
        echo "INFO: Adding default mode: $res"
        IFS="x" read -ra toks <<< "$res"
        xrandr --newmode ${res} 0.00 ${toks[0]} 0 0 0 ${toks[1]} 0 0 0 -hsync +vsync
        xrandr --addmode screen ${res}
    done
fi

echo "INFO: Setting mode to: ${RESOLUTION}"
xrandr -s "${RESOLUTION}"

# Notify sidecar containers
if [[ ${DISPLAY} == ":0" ]]; then
    touch /var/run/appconfig/xserver_ready
else
    touch /var/run/appconfig/xserver_${DISPLAY}_ready
fi

# Wait for background process
wait $PID