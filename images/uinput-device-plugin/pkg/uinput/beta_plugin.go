// Copyright 2017 Google Inc. All Rights Reserved.
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

package uinput

import (
	"fmt"
	"net"
	"path"
	"strings"
	"time"

	"github.com/golang/glog"
	"golang.org/x/net/context"
	"google.golang.org/grpc"
	pluginapi "k8s.io/kubernetes/pkg/kubelet/apis/deviceplugin/v1beta1"
)

type pluginServiceV1Beta1 struct {
	uim *uinputManager
}

func (s *pluginServiceV1Beta1) GetDevicePluginOptions(ctx context.Context, e *pluginapi.Empty) (*pluginapi.DevicePluginOptions, error) {
	return &pluginapi.DevicePluginOptions{}, nil
}

func (s *pluginServiceV1Beta1) ListAndWatch(emtpy *pluginapi.Empty, stream pluginapi.DevicePlugin_ListAndWatchServer) error {
	glog.Infoln("device-plugin: ListAndWatch start")
	changed := true
	for {
		if changed {
			resp := new(pluginapi.ListAndWatchResponse)

			if s.uim.pluginMode == PluginModeDevices {
				for _, dev := range s.uim.eventDevices {
					resp.Devices = append(resp.Devices, &pluginapi.Device{ID: dev.ID, Health: dev.Health})
				}
			} else {
				for id := range s.uim.controlMounts {
					resp.Devices = append(resp.Devices, &pluginapi.Device{ID: id, Health: pluginapi.Healthy})
				}
			}

			glog.Infof("ListAndWatch: send devices %v\n", resp)
			if err := stream.Send(resp); err != nil {
				glog.Errorf("device-plugin: cannot update device states: %v\n", err)
				s.uim.grpcServer.Stop()
				return err
			}
		}
		time.Sleep(5 * time.Second)
		changed = s.uim.CheckDeviceStates()
	}
}

func (s *pluginServiceV1Beta1) Allocate(ctx context.Context, requests *pluginapi.AllocateRequest) (*pluginapi.AllocateResponse, error) {
	resps := new(pluginapi.AllocateResponse)
	for _, rqt := range requests.ContainerRequests {
		resp := new(pluginapi.ContainerAllocateResponse)

		if s.uim.pluginMode == PluginModeDevices {
			for devNum, id := range rqt.DevicesIDs {
				dev, ok := s.uim.eventDevices[id]
				if !ok {
					return nil, fmt.Errorf("invalid allocation request with non-existing device %s", id)
				}
				if dev.Health != pluginapi.Healthy {
					return nil, fmt.Errorf("invalid allocation request with unhealthy device %s", id)
				}
				// Add evdev device to container.
				resp.Devices = append(resp.Devices, &pluginapi.DeviceSpec{
					HostPath:      path.Join(s.uim.devDirectory, id),
					ContainerPath: path.Join(s.uim.devDirectory, id),
					Permissions:   "mrw",
				})

				// Also add the evdev devce to the /dev/input/evdev/ mount
				resp.Devices = append(resp.Devices, &pluginapi.DeviceSpec{
					HostPath:      path.Join(s.uim.devDirectory, id),
					ContainerPath: path.Join(s.uim.devDirectory, "evdev", fmt.Sprintf("%s%d", strings.Split(s.uim.resourceName, "/")[1], devNum)),
					Permissions:   "mrw",
				})

				// Add input device to container
				resp.Devices = append(resp.Devices, &pluginapi.DeviceSpec{
					HostPath:      path.Join(s.uim.devDirectory, s.uim.inputDevices[id].ID),
					ContainerPath: path.Join(s.uim.devDirectory, fmt.Sprintf("%s%d", strings.Split(s.uim.resourceName, "/")[1], devNum)),
					Permissions:   "mrw",
				})

				// Add device control socket to mounts
				resp.Mounts = append(resp.Mounts, &pluginapi.Mount{
					HostPath:      path.Join(s.uim.socketDirectory, id),
					ContainerPath: path.Join(s.uim.socketDirectory, fmt.Sprintf("%s%dctl", strings.Split(s.uim.resourceName, "/")[1], devNum)),
					ReadOnly:      false,
				})
			}
		} else {
			for _, id := range rqt.DevicesIDs {
				dev, ok := s.uim.controlMounts[id]
				if !ok {
					return nil, fmt.Errorf("invalid allocation request with non-existing device: %s", id)
				}

				// Add uinput control socket to mounts
				resp.Mounts = append(resp.Mounts, &pluginapi.Mount{
					HostPath:      dev.HostPath,
					ContainerPath: dev.ContainerPath,
					ReadOnly:      false,
				})

				// only 1 request allowed.
				break
			}

			// add the /dev/uinput device, used to create new devices.
			resp.Devices = append(resp.Devices, &pluginapi.DeviceSpec{
				HostPath:      "/dev/uinput",
				ContainerPath: "/dev/uinput",
				Permissions:   "mrw",
			})
		}

		// Add any additional mounts
		for _, mountPath := range s.uim.mountPaths {
			resp.Mounts = append(resp.Mounts, &pluginapi.Mount{
				HostPath:      mountPath.HostPath,
				ContainerPath: mountPath.ContainerPath,
				ReadOnly:      true,
			})
		}
		resps.ContainerResponses = append(resps.ContainerResponses, resp)

	}
	return resps, nil
}

func (s *pluginServiceV1Beta1) PreStartContainer(ctx context.Context, r *pluginapi.PreStartContainerRequest) (*pluginapi.PreStartContainerResponse, error) {
	glog.Errorf("device-plugin: PreStart should NOT be called for GKE uinput device plugin\n")
	return &pluginapi.PreStartContainerResponse{}, nil
}

func (s *pluginServiceV1Beta1) RegisterService() {
	pluginapi.RegisterDevicePluginServer(s.uim.grpcServer, s)
}

// TODO: remove this function once we move to probe based registration.
func RegisterWithV1Beta1Kubelet(kubeletEndpoint, pluginEndpoint, resourceName string) error {
	conn, err := grpc.Dial(kubeletEndpoint, grpc.WithInsecure(),
		grpc.WithDialer(func(addr string, timeout time.Duration) (net.Conn, error) {
			return net.DialTimeout("unix", addr, timeout)
		}))
	if err != nil {
		return fmt.Errorf("device-plugin: cannot connect to kubelet service: %v", err)
	}
	defer conn.Close()
	client := pluginapi.NewRegistrationClient(conn)

	request := &pluginapi.RegisterRequest{
		Version:      pluginapi.Version,
		Endpoint:     pluginEndpoint,
		ResourceName: resourceName,
	}

	if _, err = client.Register(context.Background(), request); err != nil {
		return fmt.Errorf("device-plugin: cannot register to kubelet service: %v", err)
	}
	return nil
}
