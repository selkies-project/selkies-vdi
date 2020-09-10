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
	"io/ioutil"
	"net"
	"os"
	"path"
	"regexp"
	"sync"
	"time"

	"github.com/golang/glog"
	"google.golang.org/grpc"

	pluginapi "k8s.io/kubernetes/pkg/kubelet/apis/deviceplugin/v1beta1"
)

type PluginMode uint32

const (
	PluginModeInvalid       PluginMode = 0
	PluginModeDevices       PluginMode = 1
	PluginModeUinputControl PluginMode = 2
)

const (
	inputRE                   = `^input[0-9]+$`
	eventRE                   = `^event[0-9]+$`
	devCheckInterval          = 10 * time.Second
	pluginSocketCheckInterval = 1 * time.Second
)

type MountPath struct {
	HostPath      string
	ContainerPath string
	Health        string
}

// uinputManager manages uinput devices.
type uinputManager struct {
	pluginMode         PluginMode
	devDirectory       string
	sysDirectory       string
	socketDirectory    string
	resourceName       string
	devicePattern      string
	inputDevices       map[string]pluginapi.Device
	eventDevices       map[string]pluginapi.Device
	controlMounts      map[string]MountPath
	mountPaths         []MountPath
	grpcServer         *grpc.Server
	socket             string
	stop               chan bool
	eventDevicesMutex  sync.Mutex
	inputDevicesMutex  sync.Mutex
	controlMountsMutex sync.Mutex
}

func NewUInputManager(mode PluginMode, devDirectory, sysDirectory, socketDirectory, resourceName, devicePattern string, mountPaths []MountPath) *uinputManager {
	return &uinputManager{
		pluginMode:      mode,
		devDirectory:    devDirectory,
		sysDirectory:    sysDirectory,
		socketDirectory: socketDirectory,
		resourceName:    resourceName,
		devicePattern:   devicePattern,
		inputDevices:    make(map[string]pluginapi.Device),
		eventDevices:    make(map[string]pluginapi.Device),
		controlMounts:   make(map[string]MountPath),
		mountPaths:      mountPaths,
		stop:            make(chan bool),
	}
}

func (uim *uinputManager) hasAdditionalDevicesInstalled() bool {
	uim.inputDevicesMutex.Lock()
	originalDeviceCount := len(uim.inputDevices)
	uim.inputDevicesMutex.Unlock()
	deviceCount, err := uim.discoverNumInputs()
	if err != nil {
		glog.Errorln(err)
		return false
	}

	if deviceCount != originalDeviceCount {
		glog.Infof("Number of devices found has changed. Stopping device-plugin server.")
		return true
	}
	return false
}

func (uim *uinputManager) discoverNumInputs() (int, error) {
	regInput := regexp.MustCompile(inputRE)
	regEvent := regexp.MustCompile(eventRE)
	regDevice := regexp.MustCompile(uim.devicePattern)
	deviceCount := 0

	sysFiles, err := ioutil.ReadDir(uim.sysDirectory)
	if err != nil {
		return deviceCount, err
	}
	for _, f := range sysFiles {
		var eventName string
		var deivceFound bool

		if f.IsDir() && regInput.MatchString(f.Name()) {
			inputFiles, err := ioutil.ReadDir(path.Join(uim.sysDirectory, f.Name()))
			if err != nil {
				return deviceCount, err
			}
			for _, f2 := range inputFiles {
				if f2.IsDir() {
					if regEvent.MatchString(f2.Name()) {
						eventName = f2.Name()
					} else if regDevice.MatchString(f2.Name()) {
						deivceFound = true
					}
				}
			}
			if deivceFound && len(eventName) > 0 {
				deviceCount++
			}
		}
	}
	return deviceCount, nil
}

// Discovers all uinput devices by walking the sysDirectory and mapping
// the inputs to devices in the devDirectory
func (uim *uinputManager) discoverInputs() error {
	regInput := regexp.MustCompile(inputRE)
	regEvent := regexp.MustCompile(eventRE)
	regDevice := regexp.MustCompile(uim.devicePattern)

	glog.Infof("looking for devices in: %s\n", uim.sysDirectory)

	sysFiles, err := ioutil.ReadDir(uim.sysDirectory)
	if err != nil {
		return err
	}
	for _, f := range sysFiles {
		var eventName string
		var deviceName string

		if f.IsDir() && regInput.MatchString(f.Name()) {
			inputFiles, err := ioutil.ReadDir(path.Join(uim.sysDirectory, f.Name()))
			if err != nil {
				return err
			}
			for _, f2 := range inputFiles {
				if f2.IsDir() {
					if regEvent.MatchString(f2.Name()) {
						eventName = f2.Name()
					} else if regDevice.MatchString(f2.Name()) {
						deviceName = f2.Name()
					}
				}
			}
			if len(eventName) > 0 && len(deviceName) == 0 {
				// Search /dev/input/* for matching deviceName symlink and use that to derive deviceName: /dev/input/{deviceName} -> /dev/input/{eventName}
				inputLinks, err := ioutil.ReadDir(uim.devDirectory)
				if err != nil {
					return err
				}
				for _, f3 := range inputLinks {
					linkTarget, err := os.Readlink(path.Join(uim.devDirectory, f3.Name()))
					if err == nil && regDevice.MatchString(f3.Name()) && path.Base(linkTarget) == eventName {
						deviceName = path.Base(f3.Name())
					}
				}
			}

			if len(deviceName) > 0 && len(eventName) > 0 {
				glog.Infof("Found %s evdev: %q, device: %q\n", f.Name(), eventName, deviceName)
				uim.setInputDevice(eventName, deviceName, pluginapi.Healthy)
			}
		}
	}
	return nil
}

func (uim *uinputManager) setInputDevice(eventName, deviceName string, health string) {
	uim.eventDevicesMutex.Lock()
	uim.eventDevices[eventName] = pluginapi.Device{ID: eventName, Health: health}
	uim.eventDevicesMutex.Unlock()

	uim.inputDevicesMutex.Lock()
	uim.inputDevices[eventName] = pluginapi.Device{ID: deviceName, Health: health}
	uim.inputDevicesMutex.Unlock()
}

func (uim *uinputManager) hasAdditionalControlsInstalled() bool {
	uim.controlMountsMutex.Lock()
	originalControlCount := len(uim.controlMounts)
	uim.controlMountsMutex.Unlock()
	controlCount, err := uim.discoverNumControls()
	if err != nil {
		glog.Errorln(err)
		return false
	}

	if controlCount != originalControlCount {
		glog.Infof("Number of control sockets found has changed. Stopping device-plugin server.")
		return true
	}
	return false
}

func (uim *uinputManager) discoverNumControls() (int, error) {
	regSocket := regexp.MustCompile(uim.devicePattern)
	controlCount := 0
	socketFiles, err := ioutil.ReadDir(uim.socketDirectory)
	if err != nil {
		return controlCount, err
	}
	for _, f := range socketFiles {
		if regSocket.MatchString(f.Name()) {
			controlCount++
		}
	}
	return controlCount, nil
}

// Discovers all uinput control sockets by walking the socket directory and mapping
// the sockets to mountpaths
func (uim *uinputManager) discoverControls() error {
	regSocket := regexp.MustCompile(uim.devicePattern)

	glog.Infof("looking for control sockets in: %s\n", uim.socketDirectory)

	socketFiles, err := ioutil.ReadDir(uim.socketDirectory)
	if err != nil {
		return err
	}
	for _, f := range socketFiles {
		if regSocket.MatchString(f.Name()) {
			uim.setControlSocket(f.Name(), pluginapi.Healthy)
		}
	}
	return nil
}

func (uim *uinputManager) setControlSocket(socketName string, health string) {
	uim.controlMountsMutex.Lock()
	uim.controlMounts[socketName] = MountPath{
		HostPath:      path.Join(uim.socketDirectory, socketName),
		ContainerPath: path.Join(uim.socketDirectory, "uinputctl"),
		Health:        health,
	}
	uim.controlMountsMutex.Unlock()
}

func (uim *uinputManager) GetDeviceState(DeviceName string) string {
	// TODO: use uinput metadata to determine device state
	return pluginapi.Healthy
}

// Discovers devices and sets up device access environment.
func (uim *uinputManager) Start() error {
	if err := uim.discoverInputs(); err != nil {
		return err
	}

	if err := uim.discoverControls(); err != nil {
		return err
	}

	return nil
}

func (uim *uinputManager) CheckDeviceStates() bool {
	changed := false
	uim.inputDevicesMutex.Lock()
	for id, dev := range uim.inputDevices {
		state := uim.GetDeviceState(id)
		if dev.Health != state {
			changed = true
			dev.Health = state
			uim.inputDevices[id] = dev
		}
	}
	uim.inputDevicesMutex.Unlock()
	return changed
}

func (uim *uinputManager) CheckControlStates() bool {
	changed := false
	uim.controlMountsMutex.Lock()
	for id, dev := range uim.controlMounts {
		state := uim.GetDeviceState(id)
		if dev.Health != state {
			changed = true
			dev.Health = state
			uim.controlMounts[id] = dev
		}
	}
	uim.controlMountsMutex.Unlock()
	return changed
}

func (uim *uinputManager) Serve(pMountPath, kEndpoint, pluginEndpoint string) {
	if _, err := os.Stat(path.Join(pMountPath, kEndpoint)); err == nil {
		glog.Infof("alpha plugin is not supported")
	} else {
		glog.Infof("will use beta API\n")
	}

	for {
		select {
		case <-uim.stop:
			close(uim.stop)
			return
		default:
			{
				pluginEndpointPath := path.Join(pMountPath, pluginEndpoint)
				glog.Infof("starting device-plugin server at: %s\n", pluginEndpointPath)
				lis, err := net.Listen("unix", pluginEndpointPath)
				if err != nil {
					glog.Fatalf("starting device-plugin server failed: %v", err)
				}
				uim.socket = pluginEndpointPath
				uim.grpcServer = grpc.NewServer()

				pluginbeta := &pluginServiceV1Beta1{uim: uim}
				pluginbeta.RegisterService()

				var wg sync.WaitGroup
				wg.Add(1)
				// Starts device plugin service.
				go func() {
					defer wg.Done()
					// Blocking call to accept incoming connections.
					err := uim.grpcServer.Serve(lis)
					glog.Errorf("device-plugin server stopped serving: %v", err)
				}()

				// Wait till the grpcServer is ready to serve services.
				for len(uim.grpcServer.GetServiceInfo()) <= 0 {
					time.Sleep(1 * time.Second)
				}
				glog.Infoln("device-plugin server started serving")

				err = RegisterWithV1Beta1Kubelet(path.Join(pMountPath, kEndpoint), pluginEndpoint, uim.resourceName)
				if err != nil {
					uim.grpcServer.Stop()
					wg.Wait()
					glog.Fatal(err)
				}
				glog.Infoln("device-plugin registered with the kubelet")

				// This is checking if the plugin socket was deleted
				// and also if there are new devices found.
				// If so, stop the grpc server and start the whole thing again.
				devCheck := time.NewTicker(devCheckInterval)
				pluginSocketCheck := time.NewTicker(pluginSocketCheckInterval)
				defer devCheck.Stop()
				defer pluginSocketCheck.Stop()
			statusCheck:
				for {
					select {
					case <-pluginSocketCheck.C:
						if _, err := os.Lstat(pluginEndpointPath); err != nil {
							glog.Infof("stopping device-plugin server at: %s\n", pluginEndpointPath)
							glog.Errorln(err)
							uim.grpcServer.Stop()
							break statusCheck
						}
					case <-devCheck.C:
						if uim.pluginMode == PluginModeDevices && uim.hasAdditionalDevicesInstalled() {
							uim.grpcServer.Stop()
							for {
								err := uim.discoverInputs()
								if err == nil {
									break statusCheck
								}
							}
						} else if uim.hasAdditionalControlsInstalled() {
							uim.grpcServer.Stop()
							for {
								err := uim.discoverControls()
								if err == nil {
									break statusCheck
								}
							}
						}
					}
				}
				wg.Wait()
			}
		}
	}
}

func (uim *uinputManager) Stop() error {
	glog.Infof("removing device plugin socket %s\n", uim.socket)
	if err := os.Remove(uim.socket); err != nil && !os.IsNotExist(err) {
		return err
	}
	uim.stop <- true
	<-uim.stop
	return nil
}
