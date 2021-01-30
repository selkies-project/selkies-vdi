#!/bin/bash -e

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

# Update PWA manifest.json with app info and route.
sudo sed -i \
  -e "s|XPRA_PWA_APP_NAME|${XPRA_PWA_APP_NAME:-Xpra Desktop}|g" \
  -e "s|XPRA_PWA_APP_PATH|${XPRA_PWA_APP_PATH:-xpra-desktop}|g" \
  '/usr/share/xpra/www/manifest.json'

if [[ -n "${XPRA_PWA_ICON_URL}" ]]; then
  echo "INFO: Converting icon to PWA standard"
  if [[ "${XPRA_PWA_ICON_URL}" =~ "data:image/png;base64" ]]; then
    echo "${XPRA_PWA_ICON_URL}" | cut -d ',' -f2 | base64 -d | sudo tee /usr/share/xpra/www/icon.png >/dev/null
  else
    curl -o /tmp/icon.png -s -f -L "${XPRA_PWA_ICON_URL}" || true
    sudo convert -size 512x512 /tmp/icon.png /usr/share/xpra/www/icon.png || true
    if [[ ! -f /usr/share/xpra/www/icon.png ]]; then
      echo "WARN: failed to download PWA icon, PWA features may not be available: ${XPRA_PWA_ICON_URL}"
    fi
    rm -f /tmp/icon.png
  fi
fi

# Start dbus
sudo rm -rf /var/run/dbus
dbus-uuidgen | sudo tee /var/lib/dbus/machine-id
sudo mkdir -p /var/run/dbus
sudo dbus-daemon --system

echo "Starting CUPS"
sudo cupsd
sudo sed -i 's/^add-printer-options = -u .*/add-printer-options = -u allow:all/g' /etc/xpra/conf.d/16_printing.conf
until lpinfo -v | grep -q xpraforwarder; do sleep 1; done
echo "CUPS is ready"

echo "Starting Xpra"
sudo mkdir -p /var/log/xpra
sudo chmod 777 /var/log/xpra
(xpra ${XPRA_START:-"start"} ${DISPLAY} \
    --resize-display=no \
    --user=app \
    --bind-tcp=0.0.0.0:${XPRA_PORT:-8082} \
    --html=on \
    --daemon=no \
    --no-pulseaudio \
    --clipboard=${XPRA_ENABLE_CLIPBOARD:-"yes"} \
    --clipboard-direction=${XPRA_CLIPBOARD_DIRECTION:-"both"} \
    --file-transfer=${XPRA_FILE_TRANSFER:-"on"} \
    --open-files=${XPRA_OPEN_FILES:-"on"} \
    --printing=${XPRA_ENABLE_PRINTING:-"yes"} \
    ${XPRA_ARGS} 2>&1 | tee /var/log/xpra/xpra.log) &
PID=$!

function watchLogs() {
  tail -n+1 -F /var/log/xpra/xpra.log | while read line; do
    ts=$(date)
    #echo "$line"
    if [[ "${line}" =~ "startup complete" ]]; then
      echo "INFO: Saw Xpra startup complete: ${line}"
      echo "$ts" > /var/run/appconfig/.xpra-startup-complete
    fi
    if [[ "${line}" =~ "connection-established" ]]; then
      echo "INFO: Saw Xpra client connected: ${line}"
      echo "$ts" > /var/run/appconfig/.xpra-client-connected
    fi
    if [[ "${line}" =~ "client display size is" ]]; then
      echo "INFO: Saw Xpra client display size change: ${line}"
      echo ${line/*client display size is /} | cut -d' ' -f1 > /var/run/appconfig/xpra_display_size
    fi
    if [[ "${line}" =~ "client root window size is" ]]; then
      echo "INFO: Saw Xpra client display size change: ${line}"
      echo ${line/*client root window size is /} | cut -d' ' -f1 > /var/run/appconfig/xpra_display_size
    fi
  done
}

# Watch the xpra logs for key events and client resolution changes
watchLogs &

# Wait for Xpra client
echo "Waiting for Xpra client"
until [[ -f /var/run/appconfig/.xpra-startup-complete ]]; do sleep 1; done
until [[ -f /var/run/appconfig/.xpra-client-connected ]]; do sleep 1; done
echo "Xpra is ready"

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