package uinput

import (
	"net"
	"os"
	"path"
	"time"

	"github.com/golang/glog"
	"github.com/nsaway/fsnotify"
	"golang.org/x/net/context"
	"google.golang.org/grpc"
)

func StartUdevDeviceWatch(socketPath, podName string) error {
	watcher, err := fsnotify.NewWatcher()
	if err != nil {
		return err
	}
	defer watcher.Close()

	conn, err := grpc.Dial(
		socketPath,
		grpc.WithInsecure(),
		grpc.WithDialer(func(addr string, timeout time.Duration) (net.Conn, error) {
			return net.DialTimeout("unix", socketPath, time.Second*30)
		}))
	if err != nil {
		return err
	}
	defer conn.Close()

	// Determine plugin mode by existence of indicator file.
	checkPath := path.Join(path.Dir(socketPath), "uinput_type_pod")
	pluginMode := UinputTriggerMessage_POD
	if _, err := os.Stat(checkPath); os.IsNotExist(err) {
		pluginMode = UinputTriggerMessage_CONTAINER
	}

	glog.Infof("initialized uinput helper in plugin mode: %v", pluginMode)

	cli := NewHostServiceClient(conn)

	ctx := context.Background()

	done := make(chan bool)
	go func() {
		for {
			select {
			case event, ok := <-watcher.Events:
				if !ok {
					return
				}
				// Note requires fsnotify fork from https://github.com/nsaway/fsnotify
				// to support device Open and CloseWrite events.
				if event.Op&fsnotify.Open == fsnotify.Open {
					glog.Infof("saw uinput device open, sending message to control socket")
					_, err := cli.UinputTriggerOpen(ctx, &UinputTriggerMessage{
						PodName:    podName,
						PluginMode: pluginMode,
					})
					if err != nil {
						glog.Errorf("failed to send message: %v", err)
					}
				} else if event.Op&fsnotify.CloseWrite == fsnotify.CloseWrite {
					glog.Infof("saw uinput device close, sending message to control socket")
					_, err := cli.UinputTriggerClose(ctx, &UinputTriggerMessage{
						PodName:    podName,
						PluginMode: pluginMode,
					})
					if err != nil {
						glog.Errorf("failed to send message: %v", err)
					}
				}
			case err, ok := <-watcher.Errors:
				if !ok {
					return
				}
				glog.Errorf("%v", err)
			}
		}
	}()

	err = watcher.Add("/dev/uinput")
	if err != nil {
		return err
	}
	<-done
	return nil
}
