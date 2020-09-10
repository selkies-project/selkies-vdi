package main

import (
	"flag"
	"fmt"
	"os"
	"path"
	"strconv"

	"github.com/danisla/uinput-device-plugin/pkg/uinput"
	docker "github.com/docker/docker/client"
	"github.com/golang/glog"
)

var (
	socketDirectory = flag.String("socket-dir", "/tmp/.uinput", "Directory to create control sockets in")
	numSockets      = flag.Int("num-sockets", 16, "The number of control sockets to create")
	readyFile       = flag.String("ready-file", "/tmp/.uinput/ctl_devices_ready", "File to create once all sockets have been created.")
	sysFSPrefix     = flag.String("sys-prefix", "/hostfs", "prefix where /sys/fs is mounted to")
	deviceFileMode  = flag.String("device-file-mode", "0666", "default mode for device files created in containers.")
)

func main() {
	flag.Parse()

	// Parse octal device mode
	devMode, err := strconv.ParseUint(*deviceFileMode, 8, 64)
	if err != nil {
		glog.Fatalf("%v", err)
	}

	// Channel for events
	eventChan := make(chan uinput.MonitorEvent)

	// Connect to docker
	cli, err := docker.NewEnvClient()
	if err != nil {
		glog.Fatalf("%v", err)
	}

	os.Remove(*readyFile)

	// Start all socket servers
	for i := 0; i < *numSockets; i++ {
		socketName := fmt.Sprintf("uinputctl%d", i)
		socketPath := path.Join(*socketDirectory, socketName)
		go uinput.StartHostServer(cli, socketPath, eventChan)
	}

	// Start the udev monitor
	if err := uinput.StartUdevMon(eventChan); err != nil {
		glog.Fatalf("failed to start udev montor: %v", err)
	}

	// Create static files used to indicate to the receiving containers
	// what mode the plugin is being used as, container or whole pod.
	for _, fname := range []string{"uinput_type_container", "uinput_type_pod"} {
		dest := path.Join(*socketDirectory, fname)
		f, err := os.Create(dest)
		if err != nil {
			glog.Fatalf("failed to create mode indicator file %s: %v", fname, err)
		}
		f.Close()
	}

	// Signal ready by touching ready file.
	f, err := os.Create(*readyFile)
	if err != nil {
		glog.Fatalf("failed to open ready file: %v", err)
	}
	f.Close()

	glog.Infoln("initialized uinput device monitor, waiting for events from uinput-helper")

	// Process all received events
	uinput.HandleMonitorEvents(cli, eventChan, *sysFSPrefix, os.FileMode(devMode))
}
