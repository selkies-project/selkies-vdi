// Copyright 2019 Google Inc. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package main

import (
	"flag"
	"os"

	"github.com/danisla/uinput-device-plugin/pkg/uinput"
	"github.com/golang/glog"
)

var (
	socketPath = flag.String("server", "/tmp/.uinput/uinputctl", "The unix socket to connect to")
)

func main() {
	flag.Parse()

	hostname, err := os.Hostname()
	if err != nil {
		glog.Fatalf("failed to get hostname: %v", err)
	}

	if err := uinput.StartUdevDeviceWatch(*socketPath, hostname); err != nil {
		glog.Errorf("%v", err)
	}
}
