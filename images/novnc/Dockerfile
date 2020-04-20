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

FROM alpine:3.9
# Install noVNC, patch to support redirecting with path prefix and add shutdown button.
RUN apk add -u git bash python nodejs nodejs-npm && \
    git clone --branch=v1.0.0 --depth 1 https://github.com/novnc/noVNC.git /root/noVNC && \
    git clone --branch=v0.8.0 --depth 1 https://github.com/novnc/websockify.git /root/noVNC/utils/websockify && \
    sed -i -- "s/ps -p/ps -o pid | grep/g" /root/noVNC/utils/launch.sh && \
    sed -i '/<div id="noVNC_buttons">/a <a href="/"><input type=button value="Shutdown" class="noVNC_shown"></a>' /root/noVNC/vnc_lite.html && \
    echo '<script type="text/javascript">window.location.href = window.location.origin + window.location.pathname + "vnc_lite.html?path=" + window.location.pathname.substr(1) + "websockify";</script>' > /root/noVNC/index.html
WORKDIR /root/noVNC
CMD ./utils/launch.sh --listen 8081 --vnc localhost:5901