#!/bin/bash

# Copyright 2021 The Selkies Authors
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

# Update PWA manifest.json with app info and route.
sed -i \
    -e "s|PWA_APP_NAME|${PWA_APP_NAME:-WebRTC}|g" \
    -e "s|PWA_APP_PATH|${PWA_APP_PATH:-webrtc-desktop}|g" \
  /usr/share/nginx/html/manifest.json

if [[ -n "${PWA_ICON_URL}" ]]; then
  echo "INFO: Converting icon to PWA standard"
  if [[ "${PWA_ICON_URL}" =~ "data:image/png;base64" ]]; then
    echo "${PWA_ICON_URL}" | cut -d ',' -f2 | base64 -d | tee /usr/share/nginx/html/icon.png >/dev/null
  else
    curl -s -L "${PWA_ICON_URL}" | \
      convert -size 512x512 - /usr/share/nginx/html/icon.png
  fi
fi

sed -i \
    -e 's/listen.*80;/listen '${GST_WEB_PORT}';/g' \
    -e 's|location /|location '${PATH_PREFIX}'|g' \
    -e 's|root.*/usr/share/nginx/html.*|alias /usr/share/nginx/html/;|g' \
  /etc/nginx/conf.d/default.conf

echo "INFO: Starting web server"
exec nginx -g 'daemon off;'
