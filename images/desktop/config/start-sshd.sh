#!/bin/bash

# Copyright 2020 Google LLC
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

# Generate SSH key for server
ssh-keygen -A

# Generate SSH key for user
mkdir -p ${HOME}/.ssh
ssh-keygen -t rsa -q -N "" -f ${HOME}/.ssh/selkies_vdi.key

if [[ $? -eq 0 ]]; then
    cat ${HOME}/.ssh/selkies_vdi.key.pub > ${HOME}/.ssh/authorized_keys

    # Set new user password
    USERPASSWD=$(</dev/urandom tr -dc '12345!@#$%qwertQWERTasdfgASDFGzxcvbZXCVB' | head -c10; echo "")
    echo "${USER}:${USERPASSWD}" | sudo chpasswd

    jq \
        --arg u "${USER}" \
        --arg p "${USERPASSWD}" \
        --arg key "$(cat ${HOME}/.ssh/selkies_vdi.key)" \
        '.api = {"credential_type": "ephemeral", "username": $u, "password": $p, "sshkey": $key}' <<< '{"api":{}}' > ${HOME}/.ssh/creds.json

    chmod 0600 ${HOME}/.ssh/creds.json
fi

sudo sed -i \
    -e 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/g' \
    -e 's/^#*.*AllowTcpForwarding.*/AllowTcpForwarding yes/g' \
    /etc/ssh/sshd_config

echo "INFO: Starting sshd"
sudo /usr/sbin/sshd

echo "INFO: SSH is running, credentials at: ${HOME}/.ssh/creds.json"
