package uinput

import (
	"fmt"
	"net"
	"os"
	"path"
	"time"

	docker "github.com/docker/docker/client"
	"github.com/golang/glog"
	"golang.org/x/net/context"
	"google.golang.org/grpc"
)

type HostServer struct {
	eventChan  chan<- MonitorEvent
	socketPath string
	cli        *docker.Client
}

func StartHostServer(cli *docker.Client, socketPath string, eventChan chan<- MonitorEvent) {
	os.Remove(socketPath)

	lis, err := net.Listen("unix", socketPath)
	if err != nil {
		glog.Errorf("%v", err)
		return
	}

	srv := HostServer{
		eventChan:  eventChan,
		socketPath: socketPath,
		cli:        cli,
	}
	grpcServer := grpc.NewServer()
	RegisterHostServiceServer(grpcServer, &srv)
	if err := grpcServer.Serve(lis); err != nil {
		glog.Errorf("%v", err)
		return
	}

	if err := grpcServer.Serve(lis); err != nil {
		glog.Errorf("failed to serve: %s", err)
	}
}

func (srv *HostServer) UinputTriggerOpen(ctx context.Context, in *UinputTriggerMessage) (*UinputTriggerResponse, error) {
	resp := &UinputTriggerResponse{}
	if err := srv.enqueueMonitorEvent(EventTypeUdevDeviceOpened, in.PluginMode); err != nil {
		return resp, err
	}
	return &UinputTriggerResponse{}, nil
}

func (srv *HostServer) UinputTriggerClose(ctx context.Context, in *UinputTriggerMessage) (*UinputTriggerResponse, error) {
	resp := &UinputTriggerResponse{}
	if err := srv.enqueueMonitorEvent(EventTypeUdevDeviceClosed, in.PluginMode); err != nil {
		return resp, err
	}
	return &UinputTriggerResponse{}, nil
}

func (srv *HostServer) enqueueMonitorEvent(eventType EventType, pluginMode UinputTriggerMessage_PluginMode) error {
	container, err := findContainerWithMount(srv.cli, srv.socketPath)
	if err != nil || container == nil {
		return fmt.Errorf("failed to find container with mounted socket path '%s': %v", srv.socketPath, err)
	}

	srv.eventChan <- MonitorEvent{
		Timestamp: time.Now(),
		Type:      eventType,
		Data: map[string]string{
			"container": container.ID,
			"mode":      UinputTriggerMessage_PluginMode_name[int32(pluginMode)],
		},
	}

	return nil
}

func HandleMonitorEvents(cli *docker.Client, events <-chan MonitorEvent, sysFSPrefix string, deviceFileMode os.FileMode) {

	type groupedEventItem struct {
		UinputEvent  MonitorEvent
		DeviceEvents []MonitorEvent
	}

	windowLength := time.Duration(20 * time.Millisecond)
	prevGroupTimestamp := time.Now().Add(-20 * time.Millisecond)
	loopPeriod := time.Duration(5 * time.Millisecond)
	var groupItem groupedEventItem
	var event MonitorEvent

	// use a map to memorize the major and minor numbers since
	// we won't know them when removing the cgroup permission.
	type devNumberCacheItem struct {
		Major int
		Minor int
	}
	devNumberMap := map[string]devNumberCacheItem{}

	for {
		// Non-blocking channel read
		var ok, valid bool
		select {
		case event, valid = <-events:
			ok = true
		default:
			ok = false
		}

		if ok && valid {
			glog.Infof("[%d] Saw MonitorEvent %s: '%s'", event.Timestamp.UnixNano(), EventTypeEnum[event.Type], event.Data)

			switch event.Type {
			case EventTypeUdevDeviceOpened, EventTypeUdevDeviceClosed:
				groupItem.UinputEvent = event
			case EventTypeUdevDeviceAdded, EventTypeUdevDeviceRemoved:
				groupItem.DeviceEvents = append(groupItem.DeviceEvents, event)
			}
		}

		if time.Now().Sub(prevGroupTimestamp) > windowLength {
			if groupItem.UinputEvent.Type != EventTypeInvalid {
				addAction := false
				if groupItem.UinputEvent.Type == EventTypeUdevDeviceOpened {
					addAction = true
				}

				for _, deviceEvent := range groupItem.DeviceEvents {
					devicePath := path.Join("/dev/input", path.Base(deviceEvent.Data["path"]))
					containerID := groupItem.UinputEvent.Data["container"]
					containers := []string{containerID}

					// When device mode is 'pod', add device to all containers, otherwise just the creating container.
					if groupItem.UinputEvent.Data["mode"] == UinputTriggerMessage_PluginMode_name[int32(UinputTriggerMessage_POD)] {
						podContainers, err := getPodContainerIDs(sysFSPrefix, containerID)
						if err != nil {
							glog.Errorf("%v", err)
						} else {
							containers = podContainers
						}
					}

					for _, containerID := range containers {
						if addAction {
							// Add device to container.
							devMajor, devMinor, err := getDeviceInfo(path.Base(devicePath), sysFSPrefix)
							if err != nil {
								glog.Errorf("%v", err)
								continue
							}
							devNumberMap[devicePath] = devNumberCacheItem{
								Major: devMajor,
								Minor: devMinor,
							}
							go addDeviceToContainer(cli, containerID, devicePath, sysFSPrefix, devMajor, devMinor, deviceFileMode)
						} else {
							// Remove device from container
							devMajor := devNumberMap[devicePath].Major
							devMinor := devNumberMap[devicePath].Minor
							go removeDeviceFromContainer(cli, containerID, devicePath, sysFSPrefix, devMajor, devMinor, deviceFileMode)
						}
					}

					if addAction {
						glog.Infof("added device %s to %d containers", devicePath, len(containers))
					} else {
						glog.Infof("removed device %s from %d containers", devicePath, len(containers))
					}
				}

				// new group
				prevGroupTimestamp = groupItem.UinputEvent.Timestamp
				groupItem = groupedEventItem{}
			}
		}
		time.Sleep(loopPeriod)
	}
}
