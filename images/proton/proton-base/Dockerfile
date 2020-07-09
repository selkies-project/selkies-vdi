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

FROM ubuntu:19.10

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update

# Install 64-bit headers
RUN apt-get -y install libx11-dev libv4l-dev libvulkan-dev libmpg123-dev libgsm1-dev libgphoto2-dev libsane-dev libosmesa6-dev libpcap-dev libfontconfig1-dev libfreetype6-dev libxcursor-dev libxi-dev libxxf86vm-dev libxrandr-dev libxfixes-dev libxinerama-dev libxcomposite-dev libglu1-mesa-dev ocl-icd-opencl-dev libdbus-1-dev liblcms2-dev libpulse-dev libudev-dev libkrb5-dev libopenal-dev libldap2-dev libgettextpo-dev libjpeg-dev libcapi20-dev libtiff5-dev libva-dev libavcodec-dev \
  libcups2-dev libgnutls28-dev libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev libsdl2-dev libxml2-dev libxslt1-dev oss4-dev libgtk-3-dev

# Install 32-bit headers
RUN dpkg --add-architecture i386 && \
    apt-get update && \
    apt-get -y install libx11-dev:i386 libv4l-dev:i386 libvulkan-dev:i386 libmpg123-dev:i386 libgsm1-dev:i386 libgphoto2-dev:i386 libsane-dev:i386 libosmesa6-dev:i386 libpcap-dev:i386 libfontconfig1-dev:i386 libfreetype6-dev:i386 libxcursor-dev:i386 libxi-dev:i386 libxxf86vm-dev:i386 libxrandr-dev:i386 libxfixes-dev:i386 libxinerama-dev:i386 libxcomposite-dev:i386 libglu1-mesa-dev:i386 ocl-icd-opencl-dev:i386 libdbus-1-dev:i386 liblcms2-dev:i386 libpulse-dev:i386 libudev-dev:i386 libkrb5-dev:i386 libopenal-dev:i386 libldap2-dev:i386 libgettextpo-dev:i386 libjpeg-dev:i386 libcapi20-dev:i386 libtiff5-dev:i386 libva-dev:i386 libavcodec-dev:i386

# Ubuntu Bionic has conflicts when installing these 32-bit dev headers along with the 64-bit ones:
# # apt-get -y install libcups2-dev:i386 libgnutls28-dev:i386 libgstreamer1.0-dev:i386 libgstreamer-plugins-base1.0-dev:i386 libsdl2-dev:i386 libxml2-dev:i386 libxslt1-dev:i386 libgtk-3-dev:i386
# As a remedy, just extract the conflicting 32-bit dev headers to i386 directory (it won't do any harm).
RUN mkdir /tmp/sub; cd /tmp/sub && \
  apt-get download libcups2-dev:i386 libgnutls28-dev:i386 libgstreamer-plugins-base1.0-dev:i386 libgstreamer1.0-dev:i386 libsdl2-dev:i386 libxml2-dev:i386 libxslt1-dev:i386 libgtk-3-dev:i386 && \
  for i in $(ls *deb); do echo "Extracting $i ..."; dpkg -x $i . ; done && \
  cp -rv usr/lib/i386-linux-gnu /usr/lib/ && \
  cp -rv usr/include/i386-linux-gnu /usr/include/ && \
  rm -rf -- /tmp/sub

# Install common build deps
RUN apt-get install -y \
  gcc-8 g++-8 g++-8-multilib flex bison nasm yasm fontforge-nox \
  meson gobjc++-mingw-w64 mingw-w64 ccache wget \
  libxslt1.1 libxslt1.1:i386 \
  libcups2 libcups2:i386 \
  libsdl2-2.0-0 libsdl2-2.0-0:i386

# Install font deps
RUN apt-get install -y python3-pip && \
    pip3 install afdko

# Install misc
RUN apt-get -y install gosu less vim binutils git

# Configure gcc/g++ and POSIX mingw-w64 alternative for DXVK
RUN update-alternatives --install "$(command -v gcc)" gcc "$(command -v gcc-8)" 50 && \
  update-alternatives --set gcc "$(command -v gcc-8)" && \
  update-alternatives --install "$(command -v g++)" g++ "$(command -v g++-8)" 50 && \
  update-alternatives --set g++ "$(command -v g++-8)" && \
  update-alternatives --install "$(command -v cpp)" cpp-bin "$(command -v cpp-8)" 50 && \
  update-alternatives --set cpp-bin "$(command -v cpp-8)" && \
  sed -i 's/-gcc-7.2-/-gcc-7.3-/g' /var/lib/dpkg/alternatives/x86_64-w64-mingw32-gcc && \
  update-alternatives --set x86_64-w64-mingw32-gcc $(command -v x86_64-w64-mingw32-gcc-posix) && \
  update-alternatives --set x86_64-w64-mingw32-g++ $(command -v x86_64-w64-mingw32-g++-posix) && \
  sed -i 's/-gcc-7.2-/-gcc-7.3-/g' /var/lib/dpkg/alternatives/i686-w64-mingw32-gcc && \
  update-alternatives --set i686-w64-mingw32-gcc $(command -v i686-w64-mingw32-gcc-posix) && \
  update-alternatives --set i686-w64-mingw32-g++ $(command -v i686-w64-mingw32-g++-posix)

RUN /usr/sbin/update-ccache-symlinks

RUN echo $'export PATH="/usr/lib/ccache:$PATH"\n\
LC_ALL=C.UTF-8\n\
LANG=C.UTF-8\n\
export LC_ALL LANG\n '\
>> /root/.profile

RUN git config --global user.name "user in docker"; git config --global user.email "user@docker"

# Set unlimited number of files and size of the cache:
RUN ccache -F 0; ccache -M 0

WORKDIR /workspace

LABEL maintainer="Dan Isla <dan.isla@gmail.com>"
