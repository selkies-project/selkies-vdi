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

# Source config with docker image tags
source /etc/webrtc.env

# Verify docker is installed
if ! command -v docker >/dev/null; then
    echo "INFO: Docker not found, installing from apt."
    sudo apt-get update
    sudo apt-get install -y docker.io
    sudo usermod -a -G docker $USER
fi

function get-metadata() {
    curl -sfS "http://metadata.google.internal/computeMetadata/v1/instance/attributes/$1" -H "Metadata-Flavor: Google"
}

# Stop existing services
sudo docker kill traefik traefik-forward-auth webrtc-web webrtc webrtc-signalling coturn-web coturn 2>/dev/null || true
sudo docker rm traefik traefik-forward-auth webrtc-web webrtc webrtc-signalling coturn-web coturn 2>/dev/null || true

# Create endpoint URI from current project
ENDPOINT="${ENDPOINT:-$(get-metadata endpoint)}"

# Verify that whitelist file exists and is not empty
[[ ! -s /etc/traefik-whitelist.txt ]] && echo "ERROR: Missing or empty: /etc/traefik-whitelist.txt" && exit 1

# Start Traefik forward auth service
# Listens on host port 4181
echo "INFO: Starting traefik-forward-auth"
sudo docker run --name traefik-forward-auth -d --restart=always \
    --net=host \
    --env-file=/etc/oauth_env \
    -e WHITELIST="$(sudo cat /etc/traefik-whitelist.txt)" \
    ${TRAEFIK_FORWARD_AUTH_IMAGE??missing env}

# Create the acme.json file if it does not yet exist
[[ ! -f /etc/acme.json ]] && sudo touch /etc/acme.json && sudo chmod 0600 /etc/acme.json

# Save the ACME email address used by Lets Encrypt to send renewal notices.
ACME_EMAIL=${ACME_EMAIL:-$(get-metadata acme_email)}

# Set the ACME CA server to use
ACME_CASERVER=${ACME_CASERVER:-"https://acme-v02.api.letsencrypt.org/directory"}

echo "INFO: Starting traefik"
# Start Traefik load balancer service
sudo docker run --name traefik -d --restart=always \
    --net=host \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v /etc/acme.json:/acme.json \
    ${TRAEFIK_IMAGE?missing env} \
        --logLevel=INFO \
        --docker \
        --docker.domain="docker.localhost" \
        --docker.endpoint="unix:///var/run/docker.sock" \
        --docker.watch="true" \
        --entrypoints='Name:http Address::80 redirect.entrypoint:https' \
        --entrypoints='Name:https Address::443 tls auth.forward.address:http://127.0.0.1:4181 auth.forward.authResponseHeaders:X-Forwarded-User' \
        --acme \
        --acme.acmelogging="true" \
        --acme.email="${ACME_EMAIL}" \
        --acme.caserver="${ACME_CASERVER}" \
        --acme.storage="acme.json" \
        --acme.onhostrule="true" \
        --acme.entryPoint="https" \
        --acme.httpChallenge \
        --acme.httpChallenge.entryPoint="http"

# Generate secret for coTURN API.
echo "INFO: Generating new coturn API secret"
openssl rand -hex 16 | sudo dd of=/etc/turnserver_key.secret
sudo chmod 0600 /etc/turnserver_key.secret

# Start the coTURN STUN/TURN service
# Listens on host ports 3478, 49152-50000.
echo "INFO: Starting coturn"
sudo docker run --name coturn -d --restart=always \
    --net=host \
    -e TURN_REALM="gst.webrtc.app" \
    -e TURN_SHARED_SECRET="$(sudo cat /etc/turnserver_key.secret)" \
    -e TURN_PORT="3478" \
    -e TURN_MIN_PORT="49152" \
    -e TURN_MAX_PORT="50000" \
    --mount type=tmpfs,destination=/var/lib/coturn \
    ${COTURN_IMAGE??missing env}

# Start the coTURN STUN/TURN REST API service
# Runs with host networking on port 8088
echo "INFO: Starting coturn-web"
sudo docker run --name coturn-web -d --restart=always \
    --net=host \
    -e TURN_SHARED_SECRET="$(sudo cat /etc/turnserver_key.secret)" \
    -e PORT="8088" \
    -e TURN_PORT="3478" \
    -e AUTH_HEADER_NAME="x-forwarded-user" \
    --label "traefik.enable=true" \
    --label "traefik.port=8088" \
    --label "traefik.backend=coturn-web" \
    --label "traefik.frontend.entryPoints=http,https" \
    --label "traefik.frontend.rule=Host:${ENDPOINT};PathPrefixStrip:/turn/" \
    ${COTURN_WEB_IMAGE??missing env}

# Start the signalling service
# Runs with host networking on port 8080
echo "INFO: Starting webrtc-signalling"
sudo docker run --name webrtc-signalling -d --restart=always \
    --net=host \
    --label "traefik.enable=true" \
    --label "traefik.port=8080" \
    --label "traefik.backend=signalling" \
    --label "traefik.frontend.entryPoints=http,https" \
    --label "traefik.frontend.rule=Host:${ENDPOINT};PathPrefixStrip:/webrtc/signalling/" \
    ${SIGNALLING_IMAGE?missing env}

# Start the web interface service
# Runs with bridge networking on port 80 to host port 8082
echo "INFO: Starting webrtc-web"
sudo docker run --name webrtc-web -d --restart=always \
    -p 8082:80 \
    --label "traefik.enable=true" \
    --label "traefik.port=80" \
    --label "traefik.backend=web" \
    --label "traefik.frontend.entryPoints=http,https" \
    --label "traefik.frontend.rule=Host:${ENDPOINT}" \
    ${GST_WEB_IMAGE?missing env}

# The container image is not driver specific and requires that the NVIDIA
# libraries are present at runtime. Create directory on host containing
# the local NVIDIA libraries that will be mounted to the container at runtime.
sudo mkdir -p /usr/local/nvidia/lib64

# Copy NVIDIA libraries to /usr/local/nvidia/lib64/
NVIDIA_LIB_DIR=$(dirname $(ldconfig -p  |grep libnvidia-encode.so | grep x86-64 | tr ' ' '\n' | grep / | tail -1))

if [[ ! -d "${NVIDIA_LIB_DIR}" ]]; then
    echo "ERROR: libnvidia-encode.so not found in library path, make sure the NVIDIA driver is installed."
    exit 1
fi

sudo rsync -a ${NVIDIA_LIB_DIR}/{libnv*,libcuda*} /usr/local/nvidia/lib64/

# Allow container to connect to X11 server.
export DISPLAY=${DISPLAY:-":0"}
echo "Waiting for X11 startup"
until xhost + >/dev/null 2>&1; do sleep 1; done
echo "X11 startup complete"

# Start the WebRTC container
echo "INFO: Starting webrtc"
sudo docker run --name webrtc -d --restart=always \
    --privileged \
    --tty \
    --net=host \
    --ipc=host \
    -e GST_DEBUG="*:2" \
    -e LD_LIBRARY_PATH="/usr/local/nvidia/lib64" \
    -e DISPLAY=":0" \
    -e SIGNALLING_SERVER="ws://127.0.0.1:8080" \
    -e COTURN_AUTH_HEADER_NAME="x-forwarded-user" \
    -e COTURN_WEB_URI="http://127.0.0.1:8088/" \
    -e COTURN_WEB_USERNAME="gst.webrtc.app@localhost" \
    -e ENABLE_AUDIO="true" \
    -e PULSE_SERVER="/var/run/user/${UID}/pulse/native" \
    -v /usr/local/nvidia:/usr/local/nvidia \
    -v /usr/bin/nvidia-smi:/usr/bin/nvidia-smi \
    -v /tmp/.X11-unix:/tmp/.X11-unix \
    -v /var/run/user/${UID}/pulse:/var/run/user/${UID}/pulse \
    ${GST_WEBRTC_APP_IMAGE?missing env}
    