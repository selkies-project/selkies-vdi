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

SCRIPT_DIR=$(dirname $(readlink -f $0 2>/dev/null) 2>/dev/null || echo "${PWD}/$(dirname $0)")

sudo apt-get update

# Set default boot to multi-user mode, to disable automatic startup of the X server
sudo systemctl set-default multi-user.target

# Install the XFCE linux desktop environment and terminal emulator:
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
      xubuntu-desktop \
      terminator \
      gdebi-core

# Install the Chrome browser
curl -sfLO https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb && \
    sudo gdebi -n google-chrome-stable_current_amd64.deb && \
    rm google-chrome-stable_current_amd64.deb

# Disable error reporting dialog popups
sudo sed -i 's/enabled=1/enabled=0/g' /etc/default/apport

# Patch pulseaudio config to allow TCP access
sudo apt-get remove -y pulseaudio-module-bluetooth >/dev/null
sudo sed -i 's/^#load-module module-native-protocol-tcp/load-module module-native-protocol-tcp auth-anonymous=1/g' /etc/pulse/default.pa
systemctl --user enable pulseaudio

# add user to the input group for gamepad support
sudo usermod -a -G input ${USER}
sudo usermod -a -G games ${USER}

# Copy the startup script
mkdir -p ${HOME}/bin

cp ${SCRIPT_DIR}/../config/start_desktop.sh ${HOME}/bin/

# Copy the user service to start desktop on boot
mkdir -p ${HOME}/.config/systemd/user
cp ${SCRIPT_DIR}/../config/desktop.service ${HOME}/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable desktop.service

# Clear out the XFCE config.
rm -Rf /home/${USR}/.config/xfce4

# Allow systemd units for user to start at boot
#sudo loginctl enable-linger webrtc
sudo mkdir -p /var/lib/systemd/linger
sudo touch /var/lib/systemd/linger/$USER
