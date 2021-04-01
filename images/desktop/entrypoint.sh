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
[[ -f /var/run/appconfig/.Xauthority ]] && cp /var/run/appconfig/.Xauthority ${HOME}/
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
[[ -c /dev/nvidiactl ]] && (cd /tmp && sudo LD_LIBRARY_PATH=${LD_LIBRARY_PATH} DISPLAY=${DISPLAY} vulkaninfo >/dev/null || true)

# Start dbus
sudo rm -rf /var/run/dbus
dbus-uuidgen | sudo tee /var/lib/dbus/machine-id
sudo mkdir -p /var/run/dbus
sudo dbus-daemon --system

echo "Setting resolution"
RESOLUTION=${RESOLUTION:-1920x1080}
xrandr -s ${RESOLUTION}
xrandr --fb ${RESOLUTION}

# Configure docker unix socket proxy
if [[ "${USE_DIND,,}" == "true" ]]; then
    echo "INFO: Waiting for docker sidecar"
    CERTFILE="/var/run/docker-certs/cert.pem"
    until [[ -f ${CERTFILE} ]]; do sleep 1; done
    echo "INFO: Docker sidecar is ready, starting unix socket proxy"
    sudo /usr/share/cloudshell/start-docker-unix-proxy.sh
fi

echo "Starting apps"
while true; do
    # Create default desktop shortcuts.
    mkdir -p ${HOME}/Desktop
    find /etc/skel/Desktop -name "*.desktop" -exec ln -sf {} ${HOME}/Desktop/ \; || true

    # Copy autostart shortcuts
    mkdir -p ${HOME}/.config/autostart
    find /etc/skel/Autostart -name "*.desktop" -exec ln -sf {} ${HOME}/.config/autostart/ \; || true
    
    eval ${ENTRYPOINT:-"xfce4-session"}
    sleep 5
done