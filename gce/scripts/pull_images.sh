#!/bin/bash

# Google LLC 2019
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

ENV_FILE=${ENV_FILE:-/etc/webrtc.env}

while IFS='=' read -r var val
do
    if [[ "$var" =~ _IMAGE ]]; then
        eval sudo docker pull $val
    fi
done <"$ENV_FILE"
