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

FROM debian:buster

# Install desktop environment
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        pulseaudio && \
    rm -rf /var/lib/apt/lists/*

# Enable audio
RUN echo "load-module module-native-protocol-tcp auth-anonymous=1" >> /etc/pulse/default.pa

ENTRYPOINT /usr/bin/pulseaudio --system --verbose --log-target=stderr --realtime=true --disallow-exit -F /etc/pulse/default.pa