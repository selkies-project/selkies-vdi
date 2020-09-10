package uinput

import (
	"io"
	"time"
)

type EventType int

type MonitorEvent struct {
	Type      EventType
	Timestamp time.Time
	Data      map[string]string
}

// Enumerated event types
const (
	EventTypeInvalid           EventType = 0
	EventTypeUdevDeviceAdded   EventType = 1
	EventTypeUdevDeviceRemoved EventType = 2
	EventTypeUdevDeviceOpened  EventType = 3
	EventTypeUdevDeviceClosed  EventType = 4
)

var (
	EventTypeEnum map[EventType]string = map[EventType]string{
		0: "EVENT_TYPE_INVALID",
		1: "EVENT_TYPE_UDEV_DEVICE_ADDED",
		2: "EVENT_TYPE_UDEV_DEVICE_REMOVED",
		3: "EVENT_TYPE_UDEV_DEVICE_OPENED",
		4: "EVENT_TYPE_UDEV_DEVICE_CLOSED",
	}
)

const udevEventPattern = `^KERNEL\[([0-9.]+)\] (add|remove)\s+.*?input[0-9]+(/.*[0-9]+) \(input\).*$`

type UdevEvent struct {
	Timestamp time.Time
	Action    string
	Path      string
}

type interceptor struct {
	forward   io.Writer
	intercept func(p []byte)
}
