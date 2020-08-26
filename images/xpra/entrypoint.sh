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

if [[ "${XPRA_ARGS}" =~ use-display=yes ]]; then
    set +x
    echo "Waiting for host X server at ${DISPLAY}"
    until [[ -e /var/run/appconfig/xserver_ready ]]; do sleep 1; done
    echo "Host X server is ready"
fi

# Workaround for vulkan initialization
# https://bugs.launchpad.net/ubuntu/+source/nvidia-graphics-drivers-390/+bug/1769857
[[ -c /dev/nvidiactl ]] && (cd /tmp && sudo LD_LIBRARY_PATH=${LD_LIBRARY_PATH} DISPLAY=${DISPLAY} vulkaninfo >/dev/null || true)

# Write html5 client default settings
if [[ -n "${XPRA_HTML5_DEFAULT_SETTINGS}" ]]; then
  echo "INFO: echo writing HTML5 default-settings.txt"
  sudo rm -f /usr/share/xpra/www/default-settings.txt.*
  echo "${XPRA_HTML5_DEFAULT_SETTINGS}" | sudo tee /usr/share/xpra/www/default-settings.txt
fi

if [[ -n "${XPRA_CONF}" ]]; then
  echo "INFO: echo writing xpra conf to /etc/xpra/conf.d/99_appconfig.conf"
  echo "${XPRA_CONF}" | sudo tee /etc/xpra/conf.d/99_appconfig.conf
fi

# Start dbus
sudo rm -rf /var/run/dbus
dbus-uuidgen | sudo tee /var/lib/dbus/machine-id
sudo mkdir -p /var/run/dbus
sudo dbus-daemon --system

echo "Starting CUPS"
sudo cupsd
sudo sed -i 's/^add-printer-options = -u .*/add-printer-options = -u allow:all/g' /etc/xpra/conf.d/16_printing.conf

echo "Starting xpra"
xpra ${XPRA_START:-"start"} ${DISPLAY} \
    --resize-display=no \
    --user=app \
    --bind-tcp=0.0.0.0:${XPRA_PORT:-8082} \
    --html=on \
    --daemon=no \
    --no-pulseaudio \
    --clipboard=yes \
    --clipboard-direction=${XPRA_CLIPBOARD_DIRECTION:-"both"} \
    --file-transfer=${XPRA_FILE_TRANSFER:-"on"} \
    --open-files=${XPRA_OPEN_FILES:-"on"} \
    ${XPRA_ARGS} &
PID=$!

# Wait for Xpra client
set +x
echo "Waiting for Xpra client"
until xpra info $XPRA 2>&1 >/dev/null; do sleep 1; done
clients=0
while [[ $clients -lt 1 ]]; do
    clients=$(xpra info $XPRA | grep clients= | cut -d'=' -f2)
    sleep 1
done
echo "Xpra is ready"
set -x

xhost +
touch /var/run/appconfig/xserver_ready
touch /var/run/appconfig/xpra_ready

# Start script to force the window size of full desktop environments like xfdesktop
# to match the client window size.
/desktop_resizer.sh 2>&1 | tee /tmp/desktop-resizer.log >/dev/null &
DRPID=$!

wait $PID

kill -9 $DRPID

sleep 2