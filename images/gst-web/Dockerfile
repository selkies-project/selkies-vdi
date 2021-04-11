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
    apk add -u --no-cache imagemagick bash

WORKDIR /usr/share/nginx/html/lib
COPY src/lib/*.js ./

WORKDIR /usr/share/nginx/html
COPY src/*.js src/*.html src/manifest.json ./

# Patch index.html to fetch latest version of javascript source
RUN sed -i 's|script src="\(.*\)?ts=.*"|script src="\1?ts='$(date +%s)'"|g' index.html

# Patch the service worker with a new cache version so that it is refreshed.
RUN sed -i "s|CACHE_VERSION|$(date +%s)|g" sw.js

ENV GST_WEB_PORT 80
ENV PATH_PREFIX /

COPY entrypoint.sh /entrypoint.sh
CMD /entrypoint.sh
