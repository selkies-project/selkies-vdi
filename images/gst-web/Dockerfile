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

FROM nginx:alpine

# Install dependencies
RUN \
    apk add -u --no-cache imagemagick bash patch

WORKDIR /usr/share/nginx/html

# Download and patch Guacamole Keyboard module.
COPY fix-guacamole-keyboard-repeat.patch /tmp/
RUN curl -o guacamole-keyboard.js -L https://raw.githubusercontent.com/padarom/guacamole-common-js/glyptodon/1.4/guacamole-common-js/src/main/webapp/modules/Keyboard.js && \
    patch -p0 < /tmp/fix-guacamole-keyboard-repeat.patch && \
    rm /tmp/fix-guacamole-keyboard-repeat.patch

# Download CDN dependencies
RUN curl -o webrtc-adapter.js -L https://raw.githubusercontent.com/webrtcHacks/adapter/v7.7.1/release/adapter.js
RUN curl -o vue.min.js -L https://cdnjs.cloudflare.com/ajax/libs/vue/2.6.9/vue.min.js
RUN curl -o vuetify.min.js -L https://cdnjs.cloudflare.com/ajax/libs/vuetify/1.5.14/vuetify.min.js
RUN curl -o vue-spinner.min.js -L https://cdn.jsdelivr.net/npm/vue-spinner@1.0.3/dist/vue-spinner.min.js

COPY src/* ./

# Patch index.html to fetch latest version of javascript source
RUN sed -i 's|script src="\(.*\)?ts=.*"|script src="\1?ts='$(date +%s)'"|g' index.html

COPY entrypoint.sh /entrypoint.sh
CMD /entrypoint.sh
