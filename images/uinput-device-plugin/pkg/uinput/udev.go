package uinput

import (
	"bufio"
	"fmt"
	"io/ioutil"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"time"

	"github.com/golang/glog"
)

// Write will intercept the incoming stream, and forward
// the contents to its `forward` Writer.
func (i *interceptor) Write(p []byte) (n int, err error) {
	if i.intercept != nil {
		i.intercept(p)
	}

	return i.forward.Write(p)
}

func StartUdevMon(eventChan chan<- MonitorEvent) error {
	reEvent := regexp.MustCompile(udevEventPattern)
	logFile, err := os.Create("/var/log/udevmon.log")
	if err != nil {
		return err
	}

	cmd := exec.Command("udevadm", "monitor", "--subsystem-match", "input")
	cmd.Stderr = &interceptor{forward: logFile}
	stdout, _ := cmd.StdoutPipe()
	scanner := bufio.NewScanner(stdout)
	go func() {
		for scanner.Scan() {
			res := reEvent.FindSubmatch(scanner.Bytes())
			if len(res) > 0 {
				udevAction := string(res[2])
				udevPath := string(res[3])

				var monitorEventType EventType
				if udevAction == "add" {
					monitorEventType = EventTypeUdevDeviceAdded
				} else if udevAction == "remove" {
					monitorEventType = EventTypeUdevDeviceRemoved
				} else {
					glog.Warningf("unsupported udev monitor event type: %s", udevAction)
					return
				}

				event := MonitorEvent{
					Timestamp: time.Now(),
					Type:      monitorEventType,
					Data: map[string]string{
						"path": udevPath,
					},
				}

				// Send the event to the channel
				eventChan <- event
			}
		}
	}()

	err = cmd.Start()
	if err != nil {
		return fmt.Errorf("Failed to tail udevadm output: %v", err)
	}

	return nil
}

func getDeviceInfo(eventDevice, sysFSPrefix string) (int, int, error) {
	var devMajor, devMinor int

	eventDevFilePathPattern := fmt.Sprintf("%s/sys/devices/virtual/input/*/%s/dev", sysFSPrefix, eventDevice)
	files, err := filepath.Glob(eventDevFilePathPattern)
	if err != nil {
		return devMajor, devMinor, fmt.Errorf("failed to glob path to find dev path in pattern '%s': %v", eventDevFilePathPattern, err)
	}
	if len(files) != 1 {
		return devMajor, devMinor, fmt.Errorf("failed to find input device dev file at: %s", eventDevFilePathPattern)
	}

	dat, err := ioutil.ReadFile(files[0])
	if err != nil {
		return devMajor, devMinor, fmt.Errorf("failed to read device dev file at: %s: %v", eventDevFilePathPattern, err)
	}
	toks := strings.Split(strings.TrimSpace(string(dat)), ":")
	if len(toks) != 2 {
		return devMajor, devMinor, fmt.Errorf("invalid dev file content, expected 'maj:min' format in file, found: %s", string(dat))
	}
	devMajor, _ = strconv.Atoi(toks[0])
	devMinor, _ = strconv.Atoi(toks[1])

	return devMajor, devMinor, nil
}
