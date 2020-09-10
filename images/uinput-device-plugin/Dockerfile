# Copyright 2017 Google Inc. All rights reserved.
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

FROM golang:1.12 as builder
WORKDIR /go/src/github.com/danisla/uinput-device-plugin
COPY . .
ENV GO111MODULE=on

# Get forked version of fsnotify that supports Open and CloseWrite operations.
RUN go get github.com/nsaway/fsnotify@f133d1d12072765250420b923155a2222f2b0d2c

# Install protoc
ENV PATH=${PATH}:/go/bin
RUN go get github.com/golang/protobuf/protoc-gen-go@v1.4.2
RUN cd /tmp && curl -sLO https://github.com/protocolbuffers/protobuf/releases/download/v3.13.0/protoc-3.13.0-linux-x86_64.zip && \
    python -m zipfile -e protoc-3.13.0-linux-x86_64.zip . && \
    mv bin/protoc /go/bin/ && \
    chmod +x /go/bin/protoc
RUN protoc -I pkg/uinput --go_out=plugins=grpc:pkg/uinput pkg/uinput/*.proto

# Build the binaries
RUN go build -o uinput_plugin cmd/uinput_plugin/uinput_plugin.go
RUN go build -o uinput_monitor cmd/uinput_monitor/*.go
RUN go build -o uinput_helper cmd/uinput_helper/*.go
RUN chmod a+x uinput_plugin uinput_monitor uinput_helper

# Copy binaries to thin image.
FROM python:3-stretch
COPY --from=builder /go/src/github.com/danisla/uinput-device-plugin/uinput_plugin /usr/bin/uinput-device-plugin
COPY --from=builder /go/src/github.com/danisla/uinput-device-plugin/uinput_monitor /usr/bin/uinput-monitor
COPY --from=builder /go/src/github.com/danisla/uinput-device-plugin/uinput_helper /usr/bin/uinput-helper

WORKDIR /opt/app
COPY python/* ./
RUN pip3 install -r requirements.txt
RUN apt-get update && apt-get install -y \
        udev && \
    rm -rf /var/lib/apt/lists/*

CMD ["/usr/bin/uinput-device-plugin", "-logtostderr"]