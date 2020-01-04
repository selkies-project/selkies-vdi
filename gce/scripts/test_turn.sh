#!/bin/bash

# Copyright 2019 Google Inc.
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
set -x

ENDPOINT=${1?USAGE $0 <endpoint>}
DATA=$(curl -sf -H "x-forwarded-user: ${USER}" ${ENDPOINT})
TURN_USER=$(echo "${DATA}" | jq -r '.iceServers[1].username')
TURN_PASSWORD=$(echo "${DATA}" | jq -r '.iceServers[1].credential')
TURN_SERVER=$(echo "${DATA}" | jq -r '.iceServers[1].urls[0]' | cut -d ':' -f2)
turnutils_uclient -u ${TURN_USER} -w ${TURN_PASSWORD} ${TURN_SERVER}