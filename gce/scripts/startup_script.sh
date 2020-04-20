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

set -e

function get-metadata() {
    curl -sfS "http://metadata.google.internal/computeMetadata/v1/instance/attributes/$1" -H "Metadata-Flavor: Google"
}

export CLIENT_ID=$(get-metadata oauth_client_id)
export CLIENT_SECRET=$(get-metadata oauth_client_secret)
export COOKIE_SECRET=$(get-metadata cookie_secret)

# Create oauth file from metadata attributes
cat | sudo tee /etc/oauth_env <<EOF
CLIENT_ID=${CLIENT_ID}
CLIENT_SECRET=${CLIENT_SECRET}
SECRET=${COOKIE_SECRET}
EOF

sudo chmod 0600 /etc/oauth_env

# Create whitelist from metadata attributes
export WHITELIST=$(get-metadata whitelist)

cat | sudo tee /etc/traefik-whitelist.txt <<EOF
${WHITELIST}
EOF

# Fetch webrtc runtime variables from metadata
export ACME_EMAIL=$(get-metadata acme_email)
export ENDPOINT=$(get-metadata endpoint)

# Start WebRTC streaming stack
/usr/local/bin/start_webrtc