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
    apk add -u --no-cache imagemagick

WORKDIR /usr/share/nginx/html

COPY src/* ./

# Patch index.html to fetch latest version of javascript source
RUN sed -i 's|script src="\(.*\)?ts=.*"|script src="\1?ts='$(date +%s)'"|g' index.html

COPY entrypoint.sh /entrypoint.sh
CMD /entrypoint.sh
