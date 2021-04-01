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

[[ $UID -ne 0 ]] && echo "ERROR: this script must be run as root" && exit 1

CERTFILE="/var/run/docker-certs/cert.pem"
KEYFILE="/var/run/docker-certs/key.pem"
CAFILE="/var/run/docker-certs/ca.pem"

[[ ! -f $CERTFILE ]] && echo "ERROR: Missing $CERTFILE" && exit 1
[[ ! -f $KEYFILE ]] && echo "ERROR: Missing $KEYFILE" && exit 1
[[ ! -f $CAFILE ]] && echo "ERROR: Missing $CAFILE" && exit 1

DOCKER_HOST=${DOCKER_HOST:-"tcp://localhost:2376"}
DOCKER_HOST=${DOCKER_HOST//tcp:\/\/}

DOCKER_SOCK="/var/run/docker.sock"

rm -f ${DOCKER_SOCK}

nohup socat -d -d UNIX-LISTEN:${DOCKER_SOCK?},fork,reuseaddr,perm=0777 ssl:${DOCKER_HOST?},verify=1,cert=${CERTFILE?},key=${KEYFILE?},cafile=${CAFILE?} > /var/log/docker-unix-proxy.log &
