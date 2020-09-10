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

FROM golang:1.10-alpine as builder
RUN apk add -u git
WORKDIR /go/src/github.com/google
RUN git clone --depth 1 https://github.com/danisla/huproxy.git -b iap
RUN cd huproxy && go get ./... && \
    env GOOS=linux GARCH=amd64 CGO_ENABLED=0 go build -o /opt/huproxy huproxy.go

ARG BROKER_CLIENT_ID=BROKER_CLIENT_ID
ARG DESKTOP_CLIENT_ID=DESKTOP_APP_CLIENT_ID
ARG DESKTOP_CLIENT_SECRET=DESKTOP_APP_CLIENT_SECRET
ARG DEFAULT_ENDPOINT=broker.endpoints.PROJECT_ID.cloud.goog
WORKDIR /go/src/github.com/selkies.io/selkies-connector
COPY cli/client.go ./
RUN sed -i \
    -e "s|defaultAudience = .*|defaultAudience = \"${BROKER_CLIENT_ID}\"|g" \
    -e "s|defaultClientID = .*|defaultClientID = \"${DESKTOP_CLIENT_ID}\"|g" \
    -e "s|defaultClientSecret = .*|defaultClientSecret = \"${DESKTOP_CLIENT_SECRET}\"|g" \
    -e "s|DEFAULT_ENDPOINT|${DEFAULT_ENDPOINT}|g" \
    client.go

RUN go get ./... && \
    (cd /go/src/github.com/salrashid123/oauth2oidc && git checkout 7ab57e8bab8ff320c63bfc2313552c25b1b897eb) && \
    env GOOS=linux GARCH=amd64 CGO_ENABLED=0 go build -o /opt/selkies_connector_linux_amd64 client.go && \
    env GOOS=darwin GARCH=amd64 CGO_ENABLED=0 go build -o /opt/selkies_connector_darwin_amd64 client.go && \
    env GOOS=windows GARCH=amd64 CGO_ENABLED=0 go build -o /opt/selkies_connector_win64.exe client.go

FROM alpine:3.12

# Install dependencies
RUN apk add -u \
        darkhttpd \
        jq \
        bash \
        curl

# Copy web content
COPY index.html /var/www/localhost/htdocs/

# Copy huproxy from builder
COPY --from=builder /opt/huproxy /opt/huproxy
COPY --from=builder /opt/selkies_connector_linux_amd64 /var/www/localhost/htdocs/selkies_connector_linux_amd64
COPY --from=builder /opt/selkies_connector_darwin_amd64 /var/www/localhost/htdocs/selkies_connector_darwin_amd64
COPY --from=builder /opt/selkies_connector_win64.exe /var/www/localhost/htdocs/selkies_connector_win64.exe
RUN cd /opt && ln -s /var/www/localhost/htdocs/selkies_connector* ./

COPY entrypoint.sh /

WORKDIR /opt

ENTRYPOINT ["/entrypoint.sh"]