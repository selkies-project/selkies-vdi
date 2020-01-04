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

set -e

if [[ -z "${CRD_REDIRECT_URL}" || -z "${CRD_CODE}" || -z "${CRD_PIN}" ]]; then
    echo "Missing CRD_REDIRECT_URL, CRD_CODE or CRD_PIN env vars. sleeping."
    while true; do sleep 1000; done
fi

# Pipe audio from pamon to fifo read by chrome remote desktop
mkdir -p /tmp/.pulse
mkfifo -m a=rw /tmp/.pulse/pulse_fifo_output
PULSE_SERVER=127.0.0.1:4713 pamon /tmp/.pulse/pulse_fifo_output &

# Start chrome remote desktop host
/opt/google/chrome-remote-desktop/start-host \
    --name=$(hostname) \
    --redirect-url="${CRD_REDIRECT_URL}" \
    --code="${CRD_CODE}" \
    --pin="${CRD_PIN}"

# foreground process, tail logs.
tail -F /tmp/chrome_remote_desktop_*