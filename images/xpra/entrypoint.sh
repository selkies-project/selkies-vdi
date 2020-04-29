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
echo "Waiting for host X server at ${DISPLAY}"
until [[ -e /var/run/appconfig/xserver_ready ]]; do sleep 1; done
echo "Host X server is ready"

[[ -c /dev/nvidiactl ]] && (cd /tmp && sudo LD_LIBRARY_PATH=${LD_LIBRARY_PATH} DISPLAY=${DISPLAY} vulkaninfo >/dev/null)

echo "Starting xpra"
xpra ${XPRA_START:-"start"} ${DISPLAY} \
    --use-display=yes \
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

touch /var/run/appconfig/xpra_ready

wait $PID

sleep 2