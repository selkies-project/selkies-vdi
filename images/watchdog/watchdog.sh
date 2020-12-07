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

# This script is called by a watchdog trigger to shutdown the user pod
# by calling the DELETE method on the pod broker.

set +x
echo "Waiting for X server"
until [[ -e /var/run/appconfig/xserver_ready ]]; do sleep 1; done
[[ -f /var/run/appconfig/.Xauthority ]] && cp /var/run/appconfig/.Xauthority ${HOME}/
echo "X server is ready"
set -x

echo "INFO: Shutting down ${APP_NAME?} pod for user ${POD_USER?} through pod broker" >&2

if [[ ${IN_CLUSTER:-"true"} == "true" ]]; then
    curl -s -f -v -H "Cookie: ${BROKER_COOKIE?}" -H "Host: ${BROKER_HOST?}" -X DELETE ${IN_CLUSTER_BROKER_ENDPOINT}/${APP_NAME?}/
else
    ID_TOKEN=$(curl -s -f -H "Metadata-Flavor: Google" "http://metadata/computeMetadata/v1/instance/service-accounts/default/identity?audience=${CLIENT_ID?}&format=full")
    curl -s -f -H "Cookie: ${BROKER_COOKIE?}" -H "Authorization: Bearer ${ID_TOKEN}" -X DELETE ${BROKER_ENDPOINT?}/${APP_NAME?}/
fi
