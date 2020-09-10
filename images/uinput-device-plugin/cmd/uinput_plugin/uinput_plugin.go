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
	"fmt"
	"path"
	"strings"
	"time"

	"github.com/golang/glog"

	uinputmanager "github.com/danisla/uinput-device-plugin/pkg/uinput"
)

const (
	// Device plugin settings.
	kubeletEndpoint      = "kubelet.sock"
	pluginEndpointPrefix = "uinputDevice"
	devDirectory         = "/dev/input"
	sysDirectory         = "/sys/devices/virtual/input"
	socketDirectory      = "/tmp/.uinput"
	helperHostPath       = "/var/lib/kubelet/device-plugins/uinput-helper"
)

var (
	pluginMountPath = flag.String("plugin-directory", "/device-plugin", "The directory path to create plugin socket")
	resourceName    = flag.String("resource-name", "uinput.dev/mouse", "Name of the kubernetes resource to register, either 'uinput.dev/mouse' or 'uinput.dev/js'")
	devicePattern   = flag.String("device-pattern", "^mouse[0-9]+$", "Regular expression for matching devices in /dev/input/")
)

func main() {
	flag.Parse()
	glog.Infoln("device-plugin started")

	mountPaths := []uinputmanager.MountPath{}

	pluginMode := uinputmanager.PluginModeDevices

	switch *resourceName {
	case "uinput.dev/pod", "uinput.dev/container":
		pluginMode = uinputmanager.PluginModeUinputControl

		pluginModeFile := path.Join(socketDirectory, "uinput_type_container")
		if strings.Split(*resourceName, "/")[1] == "pod" {
			pluginModeFile = path.Join(socketDirectory, "uinput_type_pod")
		}

		mountPaths = []uinputmanager.MountPath{
			uinputmanager.MountPath{
				HostPath:      pluginModeFile,
				ContainerPath: pluginModeFile,
			},
			uinputmanager.MountPath{
				HostPath:      helperHostPath,
				ContainerPath: path.Join(socketDirectory, "uinput-helper"),
			},
		}
	}

	uim := uinputmanager.NewUInputManager(pluginMode, devDirectory, sysDirectory, socketDirectory, *resourceName, *devicePattern, mountPaths)
	// Keep on trying until success. This is required
	// because Nvidia drivers may not be installed initially.
	for {
		err := uim.Start()
		if err == nil {
			break
		}
		// Use non-default level to avoid log spam.
		glog.V(3).Infof("uinputManager.Start() failed: %v", err)
		time.Sleep(5 * time.Second)
	}
	uim.Serve(*pluginMountPath, kubeletEndpoint, fmt.Sprintf("%s-%s-%d.sock", pluginEndpointPrefix, path.Base(*resourceName), time.Now().Unix()))
}
