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

cd /opt/app

if [[ -e /tmp/.uinput/uinput-helper ]]; then
    # Start udevd to send uinput udev device events, requires capability NET_ADMIN
    /usr/lib/systemd/systemd-udevd --daemon

    /tmp/.uinput/uinput-helper -logtostderr 2>/var/log/uinput-helper.log &
fi

while true; do
    python3 /opt/app/main.py ${EXTRA_FLAGS}
    sleep 1
done