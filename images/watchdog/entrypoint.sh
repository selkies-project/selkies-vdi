#!/bin/bash

# Copyright 2020 Google LLC
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

# Run startup script to query session metadata
/opt/app/startup.sh &

# Timeout in seconds to wait for x server before shutting down
XSERVER_TIMEOUT=${WATCHDOG_TIMEOUT:-60}

set +x
if [[ ${XSERVER_TIMEOUT} -lt 1 ]]; then
    echo "INFO: watchdog is disabled because timeout is ${XSERVER_TIMEOUT}, spinning."
    while true; do sleep 1000; done
    exit
fi
set -x

count=0
set +x
echo "Waiting for host X server at ${DISPLAY}"
until [[ -e /var/run/appconfig/xserver_ready ]]; do
    ((count=count+1))
    if [[ $count -ge ${XSERVER_TIMEOUT} ]]; then
        echo "ERROR: Timeout waiting for X server"
        /opt/app/shutdown.sh
        exit
    fi
    sleep 1
done
[[ -f /var/run/appconfig/.Xauthority ]] && cp /var/run/appconfig/.Xauthority ${HOME}/
echo "X server is ready"
set -x

exec python3 /opt/app/xserver_watchdog.py --on_timeout=/opt/app/shutdown.sh