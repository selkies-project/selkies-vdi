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

FROM golang:1.17-alpine as builder

# Install huproxy binary from fork.
RUN go get github.com/danisla/huproxy@iap

ARG BROKER_CLIENT_ID=BROKER_CLIENT_ID
ARG DESKTOP_CLIENT_ID=DESKTOP_APP_CLIENT_ID
ARG DESKTOP_CLIENT_SECRET=DESKTOP_APP_CLIENT_SECRET
ARG GCIP_API_KEY=GCIP_API_KEY
ARG DEFAULT_ENDPOINT=broker.endpoints.PROJECT_ID.cloud.goog
WORKDIR /go/src/github.com/selkies.io/connector
COPY cli/* ./
RUN sed -i \
    -e "s|const defaultAudience .*= .*|const defaultAudience = \"${BROKER_CLIENT_ID}\"|g" \
    -e "s|const defaultClientID .*= .*|const defaultClientID = \"${DESKTOP_CLIENT_ID}\"|g" \
    -e "s|const defaultClientSecret .*= .*|const defaultClientSecret = \"${DESKTOP_CLIENT_SECRET}\"|g" \
    -e "s|const defaultGCIPKey .*= .*|const defaultGCIPKey = \"${GCIP_API_KEY}\"|g" \
    -e "s|DEFAULT_ENDPOINT|${DEFAULT_ENDPOINT}|g" \
    client.go

RUN env GOOS=linux GARCH=amd64 CGO_ENABLED=0 go build -o /opt/selkies_connector_linux_amd64 client.go && \
    env GOOS=darwin GARCH=amd64 CGO_ENABLED=0 go build -o /opt/selkies_connector_darwin_amd64 client.go && \
    env GOOS=windows GARCH=amd64 CGO_ENABLED=0 go build -o /opt/selkies_connector_win64.exe client.go

FROM alpine:3

# Install dependencies
RUN apk add --no-cache -u \
        lighttpd \
        jq \
        bash \
        curl

# Copy lighttpd config
COPY lighttpd.conf /etc/lighttpd/lighttpd.conf

# Copy web content
COPY web/ /var/www/localhost/htdocs/
ADD https://cdn.jsdelivr.net/npm/@mdi/font@6.x/fonts/materialdesignicons-webfont.eot?v=6.5.95 /var/www/localhost/htdocs/fonts/materialdesignicons-webfont.eot
ADD https://cdn.jsdelivr.net/npm/@mdi/font@6.x/fonts/materialdesignicons-webfont.ttf?v=6.5.95 /var/www/localhost/htdocs/fonts/materialdesignicons-webfont.ttf
ADD https://cdn.jsdelivr.net/npm/@mdi/font@6.x/fonts/materialdesignicons-webfont.woff?v=6.5.95 /var/www/localhost/htdocs/fonts/materialdesignicons-webfont.woff
ADD https://cdn.jsdelivr.net/npm/@mdi/font@6.x/fonts/materialdesignicons-webfont.woff2?v=6.5.95 /var/www/localhost/htdocs/fonts/materialdesignicons-webfont.woff2
RUN chmod go+r /var/www/localhost/htdocs/ -R

# Copy huproxy from builder
COPY --from=builder /go/bin/huproxy /opt/huproxy
COPY --from=builder /opt/selkies_connector_linux_amd64 /var/www/localhost/htdocs/selkies_connector_linux_amd64
COPY --from=builder /opt/selkies_connector_darwin_amd64 /var/www/localhost/htdocs/selkies_connector_darwin_amd64
COPY --from=builder /opt/selkies_connector_win64.exe /var/www/localhost/htdocs/selkies_connector_win64.exe
RUN cd /opt && ln -s /var/www/localhost/htdocs/selkies_connector* ./

COPY entrypoint.sh /

WORKDIR /opt

ENTRYPOINT ["/entrypoint.sh"]