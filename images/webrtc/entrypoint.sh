#!/bin/bash

echo "Waiting for X server"
until [[ -e /var/run/appconfig/xserver_ready ]]; do sleep 1; done
echo "X server is ready"

# Run nvidia-smi to enable non-root device usage in container.
if [[ -e /usr/local/nvidia/bin/nvidia-smi ]]; then
  sudo LD_LIBRARY_PATH=${LD_LIBRARY_PATH} /usr/local/nvidia/bin/nvidia-smi
fi

# Update env for gstreamer
source /opt/gstreamer/gst-env
export DISPLAY=":0"
export GST_DEBUG="${GST_DEBUG:-*:2}"

# Write Progressive Web App (PWA) config.
export PWA_APP_NAME=${PWA_APP_NAME:-WebRTC}
export PWA_APP_SHORT_NAME=${PWA_APP_PATH:-selkies}
export PWA_START_URL="/${PWA_APP_SHORT_NAME}/index.html"

# Patch the PWA manifest
sudo sed -i \
    -e "s|PWA_APP_NAME|${PWA_APP_NAME}|g" \
    -e "s|PWA_APP_SHORT_NAME|${PWA_APP_SHORT_NAME}|g" \
    -e "s|PWA_START_URL|${PWA_START_URL}|g" \
    /opt/gst-web/manifest.json

# Patch the service worker
sudo sed -i \
    -e "s|PWA_CACHE|${PWA_APP_SHORT_NAME}-webrtc-pwa|g" \
    /opt/gst-web/sw.js

# Resize the icon
if [[ -n "${PWA_ICON_URL}" ]]; then
  echo "INFO: Converting icon to PWA standard"
  if [[ "${PWA_ICON_URL}" =~ "data:image/png;base64" ]]; then
    echo "${PWA_ICON_URL}" | cut -d ',' -f2 | base64 -d > /tmp/icon.png
  else
    curl -s -L "${PWA_ICON_URL}" > /tmp/icon.png
  fi
  if [[ -e /tmp/icon.png ]]; then
    echo "INFO: Creating PWA icon sizes"
    sudo convert /tmp/icon.png /opt/gst-web/icon.png
    rm -f /tmp/icon.png
    echo "192x192 512x512" | tr ' ' '\n' | \
      xargs -P4 -I{} sudo convert -resize {} -size {} /opt/gst-web/icon.png /opt/gst-web/icon-{}.png || true
  else
    echo "WARN: failed to download PWA icon, PWA features may not be available: ${PWA_ICON_URL}"
  fi
fi

if [[ -e /tmp/.uinput/uinput-helper ]]; then
    # Start udevd to send uinput udev device events, requires capability NET_ADMIN
    sudo /usr/lib/systemd/systemd-udevd --daemon

    /tmp/.uinput/uinput-helper -logtostderr 2>/var/log/uinput-helper.log &
fi

if [[ -n "${UINPUT_MOUSE_SOCKET}" ]]; then
    # Wait for socket to get mounted to container by uinput-device-plugin.
    echo "Waiting for uinput mouse socket: ${UINPUT_MOUSE_SOCKET}"
    until [[ -S ${UINPUT_MOUSE_SOCKET} ]]; do sleep 1; done
    echo "uinput mouse socket is ready"
fi

while true; do
    selkies-gstreamer ${EXTRA_FLAGS}
    sleep 1

    echo "Waiting for X server"
    until [[ -e /var/run/appconfig/xserver_ready ]]; do sleep 1; done
    echo "X server is ready"
done