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
set -x

sudo /bin/chown 1000:1000 /home/coder

if [[ -f ${HOME}/.local/share/cloudshell/home_init_complete ]]; then
    echo "persistent directory already initialized."
    exit 0
fi

# Copy default tmux conf
cp /usr/share/code-server/tmux.conf ${HOME}/.tmux.conf

# Copy default bashrc if not already set.
if [[ -f ${HOME}/.bashrc ]]; then
    cat /usr/share/code-server/tmux.bashrc \
        /usr/share/code-server/cloudshell.bashrc \
        ${HOME}/.bashrc \
            > ${HOME}/.bashrc.new
    mv ${HOME}/.bashrc.new ${HOME}/.bashrc
else
    cat /usr/share/code-server/tmux.bashrc \
        /usr/share/code-server/cloudshell.bashrc \
            > ${HOME}/.bashrc
fi

# Touchfile to indicate that home directory has been initialized
mkdir -p ${HOME}/.local/share/cloudshell
touch ${HOME}/.local/share/cloudshell/home_init_complete

sudo /bin/chown 1000:1000 /home/coder -R