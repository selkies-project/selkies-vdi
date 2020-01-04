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

# Install simple 3D demos
sudo apt-get install -y \
  glmark2 \
  vulkan-utils \
  vkd3d-demos \
  mesa-utils \
  mesa-utils-extra \
  mesa-vulkan-drivers \
  libxrandr-dev \
  libopenal1

# Install Unigine Valley benchmark
curl -LO https://assets.unigine.com/d/Unigine_Valley-1.0.run
sh Unigine_Valley-1.0.run
sudo mv Unigine_Valley-1.0 /opt/
rm Unigine_Valley-1.0.run

# Install jstest-gtk and SuperTuxKart
sudo apt-get install -y jstest-gtk supertuxkart

mkdir -p ${HOME}/Desktop

# Create shortcut to Valley
cat > ${HOME}/Desktop/Valley.desktop <<EOF
[Desktop Entry]
Type=Application
Exec=/opt/Unigine_Valley-1.0/valley
Path=/opt/Unigine_Valley-1.0
Name=Valley Demo
Icon=/opt/Unigine_Valley-1.0/data/launcher/icon.png
EOF

# nvidia-settings shortcut
cat > ${HOME}/Desktop/nvidia-settings.desktop <<EOF
[Desktop Entry]
Type=Application
Exec=/usr/bin/nvidia-settings
Name=NVIDIA Settings
Icon=/usr/share/pixmaps/nvidia-settings.png
EOF

# glxgears shortcut
cat > ${HOME}/Desktop/glxgears.desktop <<EOF
[Desktop Entry]
Type=Application
Exec=/usr/bin/glxgears
Name=GLX Demo
Icon=application-default-icon
EOF

# glxgears shortcut
cat > ${HOME}/Desktop/es2gears.desktop <<EOF
[Desktop Entry]
Type=Application
Exec=/usr/bin/es2gears
Name=OpenGL-ES Demo
Icon=application-default-icon
EOF

# vkcube shortcut
cat > ${HOME}/Desktop/vkcube.desktop <<EOF
[Desktop Entry]
Type=Application
Exec=/usr/bin/vkcube
Name=Vulkan Demo
Icon=application-default-icon
EOF

# glmark2 shortcut
cat > ${HOME}/Desktop/glmark2.desktop <<EOF
[Desktop Entry]
Type=Application
Exec=/usr/bin/glmark2
Name=GLMark2
Icon=application-default-icon
EOF

chmod +x ~/Desktop/*.desktop