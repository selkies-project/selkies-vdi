#!/bin/bash

# Copyright 2022 The Selkies Authors
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

if [[ "${VDI_enableXpra:-false}" == true ]]; then
    echo "Waiting for Xpra"
    until [[ -e /var/run/appconfig/xpra_ready ]]; do sleep 1; done
    echo "Xpra server is ready"
fi

echo "INFO: Fetching session metadata for ${APP_NAME?} pod for user ${POD_USER?} through pod broker" >&2
mkdir -p /var/run/appconfig/

if [[ ${IN_CLUSTER:-"true"} == "true" ]]; then
    curl -s -f -v -H "Cookie: ${BROKER_COOKIE?}" -H "Host: ${BROKER_HOST?}" -X GET ${IN_CLUSTER_BROKER_ENDPOINT}/${APP_NAME?}/ | tee /var/run/appconfig/session_metadata.json
else
    ID_TOKEN=$(curl -s -f -H "Metadata-Flavor: Google" "http://metadata/computeMetadata/v1/instance/service-accounts/default/identity?audience=${CLIENT_ID?}&format=full")
    curl -s -f -H "Cookie: ${BROKER_COOKIE?}" -H "Authorization: Bearer ${ID_TOKEN}" -X DELETE ${BROKER_ENDPOINT?}/${APP_NAME?}/ | tee /var/run/appconfig/session_metadata.json
fi

# Notify sidecars that startup is complete
touch /var/run/appconfig/session_metadata_ready# XProp of Eclipse IDE Launcher window
