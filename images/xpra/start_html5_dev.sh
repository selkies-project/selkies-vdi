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

set -e
set -o pipefail

export RED='\033[1;31m'
export CYAN='\033[1;36m'
export GREEN='\033[1;32m'
export NC='\033[0m' # No Color
function log_red() { echo -e "${RED}$@${NC}"; }
function log_cyan() { echo -e "${CYAN}$@${NC}"; }
function log_green() { echo -e "${GREEN}$@${NC}"; }

SCRIPT_DIR=$(dirname $(readlink -f $0 2>/dev/null) 2>/dev/null || echo "${PWD}/$(dirname $0)")

function cleanup() {
    cd $SCRIPT_DIR
    [[ -e "${DEST_SETTINGS}.orig" ]] && mv "${DEST_SETTINGS}.orig" "${DEST_SETTINGS}"
    [[ -e "${DEST_CONNECT}.orig" ]] && mv "${DEST_CONNECT}.orig" "${DEST_CONNECT}"
    [[ -n "$port_forward2_pid" ]] && kill -9 $port_forward2_pid >/dev/null 2>&1 || true
    [[ -n "$port_forward1_pid" ]] && kill -9 $port_forward1_pid >/dev/null 2>&1  || true
}
trap cleanup EXIT

function _user_pod_select() {
    ACCOUNT=$1
    APP=$2
    [[ -z "${ACCOUNT}" ]] && echo "USAGE: _user_pod_select <user|default gcloud account> [<app name>]" && return 1
    IFS=';' read -ra items <<< "$(kubectl get pod --all-namespaces -o=jsonpath='{.items[?(@.metadata.annotations.app\.broker/user=="'${ACCOUNT?}'")].metadata}' | tr ' ' ';' | sort)"

    local count=1
    local sel=0

    [[ -z "$APP" ]] && echo "Launched pods available to tunnel to:" >&2
    for i in ${items[@]}; do
        name=$(echo "$i" | jq -r .name)
        ns=$(echo "$i" | jq -r .namespace)
        [[ -z "$APP" ]] && echo "  $count) ${ns}/${name}" >&2
        ((count=count+1))
    done
    if [[ -z "${APP}" ]]; then
        while [[ $sel -lt 1 || $sel -ge $count ]]; do
            read -p "Select a Selkies pod: " sel >&2
        done
    fi
    name=$(echo "${items[(sel-1)]}" | jq -r .name)
    ns=$(echo "${items[(sel-1)]}" | jq -r .namespace)
    echo "${ns}/${name}"
}

ACCOUNT=""
APP=""
while [[ $# -gt 0 ]]; do
    case $1 in
        -u)
            ACCOUNT="$2"
            shift
            shift
        ;;
        -a)
            APP="$2"
            shift
            shift
        ;;
        -h|*)
            echo "USAGE: $0 [-u <user email>] [-a <app name>]" && exit 1
        ;;
    esac
done

# Use default gcloud sdk account if none provided
[[ -z "${ACCOUNT}" ]] && ACCOUNT=$(gcloud config get-value account)

# Make sure app is running, if not, start it.
if [[ -n "${APP}" ]]; then
    if [[ -z $(command -v selkies-cli) ]]; then
        log_red "ERROR: Missing selkies-cli command, cannot specify app with '-a'."
        exit 1
    fi
    STATUS=$(selkies-cli status $APP | jq -r .status)
    if [[ "${STATUS}" =~ shutdown ]]; then
        log_cyan "INFO: $APP is shutdown, launching..."
        selkies-cli -u $ACCOUNT start $APP
        sleep 2
    fi
fi

NSPOD=$(_user_pod_select "${ACCOUNT}" "${APP}")
IFS="/" read -ra TOKS <<< "${NSPOD}"
NS=${TOKS[0]}
POD=${TOKS[1]}
kubectl port-forward -n ${NS} ${POD} --address 0.0.0.0 8080:8082 >/dev/null &
port_forward1_pid=$!

# Add local client git pre-commit hook so dev generated files are not committed.
cd xpra-html5
HOOK_DIR=`git rev-parse --git-dir`/hooks
cat - > "${HOOK_DIR}"/pre-commit <<'EOM'
#!/bin/sh
#
# Pre-commit hook to ensure dev generated resources are not committed. 

if git diff HEAD | grep -q "### BEGIN xpra-html5 dev"; then
        cat <<\EOF
Error: Attempt to add a dev generated file.

Verify that the following files were not added with dev-only changes:
    html5/connect.html
    html5/default-settings.txt
EOF
    exit 1
fi
EOM
chmod +x "${HOOK_DIR}"/pre-commit
cd -

export DEST_SETTINGS="${SCRIPT_DIR}/xpra-html5/html5/default-settings.txt"

# Backup settings file, restored on script exit.
cp ${DEST_SETTINGS} ${DEST_SETTINGS}.orig

# Copy default-settings from pod to local directory.
SRC_SETTINGS="/usr/share/xpra/www/default-settings.txt"
kubectl -n ${NS} cp -c xpra ${POD}:${SRC_SETTINGS} ${DEST_SETTINGS}

XPRA_URL_SETTING=""
XPRA_PORT_SETTING=""
XPRA_URL=""
WEB_URL=""
if [[ -n "${WEB_PREVIEW_PORT_8080}" && -n "${WEB_PREVIEW_PORT_8000}" ]]; then
    XPRA_URL=${WEB_PREVIEW_PORT_8080}
    XPRA_URL_SETTING=${WEB_PREVIEW_PORT_8080//https:\/\//}
    XPRA_URL_SETTING=${XPRA_URL_SETTING//\//}
    XPRA_PORT_SETTING="443"
    WEB_URL=${WEB_PREVIEW_PORT_8000}
else
    log_cyan "WARN: WEB_PREVIEW_PORT_8080 and WEB_PREVIEW_PORT_8000 not found, external access is not possible, using localhost"
    XPRA_URL="http://localhost/"
    XPRA_URL_SETTING="localhost"
    XPRA_PORT_SETTING="8080"
    WEB_URL="http://localhost:8000"
fi

cat - >> ${DEST_SETTINGS} <<EOF


### BEGIN xpra-html5 dev settings
server = ${XPRA_URL_SETTING}
port = ${XPRA_PORT_SETTING}

#debug_mouse = true
#debug_clipboard = true
### END xpra-html5 dev settings
EOF
log_cyan "INFO: wrote $(basename ${DEST_SETTINGS})"

export DEST_CONNECT=${SCRIPT_DIR}/xpra-html5/html5/connect.html

# Backup connect.html file, restored on script exit.
cp ${DEST_CONNECT} ${DEST_CONNECT}.orig

cat - > ${DEST_CONNECT} <<EOF
<html>
    <head>
        <script type="text/javascript">
            // ### BEGIN xpra-html5 dev
            var dest_url = "${XPRA_URL?}/connect.html?r=" + encodeURIComponent("${WEB_URL}");
            window.location.replace(dest_url);
            // ### END xpra-html5 dev
        </script>
    </head>
</html>
EOF
log_cyan "INFO: wrote $(basename ${DEST_CONNECT})"

cd ${SCRIPT_DIR}/xpra-html5/html5
python3 -m http.server 8000 &
port_forward2_pid=$!

sleep 1
log_green "Development web server is running at:"
log_cyan "   ${WEB_URL?}"

wait $port_forward1_pid