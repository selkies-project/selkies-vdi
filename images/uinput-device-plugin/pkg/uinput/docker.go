package uinput

import (
	"context"
	"fmt"
	"io/ioutil"
	"os"
	"path"
	"path/filepath"
	"strconv"

	types "github.com/docker/docker/api/types"
	docker "github.com/docker/docker/client"
	"github.com/golang/glog"
)

func findContainerWithMount(cli *docker.Client, sourcePath string) (*types.Container, error) {
	ctx := context.Background()
	list, err := cli.ContainerList(ctx, types.ContainerListOptions{})
	if err != nil {
		return nil, err
	}

	for _, container := range list {
		for _, mount := range container.Mounts {
			if mount.Source == sourcePath {
				return &container, nil
			}
		}
	}
	return nil, nil
}

func getPodContainerIDs(sysFSPrefix, testContainerID string) ([]string, error) {
	containerIDs := []string{}
	containerPathPattern := fmt.Sprintf("%s/sys/fs/cgroup/devices/kubepods/burstable/*/%s", sysFSPrefix, testContainerID)
	files, err := filepath.Glob(containerPathPattern)
	if err != nil || len(files) != 1 {
		return containerIDs, fmt.Errorf("failed to glob path to find containers in pattern '%s': %v", containerPathPattern, err)
	}
	podPath := path.Dir(files[0])
	podContainerPathPattern := path.Join(podPath, "*", "devices.allow")
	files, err = filepath.Glob(podContainerPathPattern)
	if err != nil {
		return containerIDs, fmt.Errorf("failed to glob path to find pod containers in pattern '%s': %v", podContainerPathPattern, err)
	}

	for _, f := range files {
		containerIDs = append(containerIDs, path.Base(path.Dir(f)))
	}
	return containerIDs, nil
}

func addDeviceToContainer(cli *docker.Client, containerID, devicePath, sysFSPrefix string, devMajor, devMinor int, deviceFileMode os.FileMode) {
	// Add device to cgroup
	cgroupPathPattern := fmt.Sprintf("%s/sys/fs/cgroup/devices/kubepods/burstable/*/%s/devices.allow", sysFSPrefix, containerID)
	files, err := filepath.Glob(cgroupPathPattern)
	if err != nil {
		glog.Errorf("failed to glob path to find cgroup path in pattern '%s': %v", cgroupPathPattern, err)
	}
	if len(files) == 1 {
		// Write the device node to the devices.allow cgroup sys file.
		cgroupPerms := fmt.Sprintf("c %d:%d rwm", devMajor, devMinor)
		if err := ioutil.WriteFile(files[0], []byte(cgroupPerms), deviceFileMode); err != nil {
			glog.Errorf("failed to write cgroup permissions to %s", cgroupPathPattern)
		}
	} else {
		glog.Errorf("failed to find single cgroup devices.allow at: %s, expected 1, found %d", cgroupPathPattern, len(files))
	}

	// Add device to container using docker exec.
	cmd := []string{
		"/bin/sh",
		"-c",
		fmt.Sprintf(
			"mkdir -p /dev/input; mknod -m %s %s c %d %d",
			strconv.FormatUint(uint64(deviceFileMode), 8),
			devicePath,
			devMajor,
			devMinor,
		),
	}
	if err := execContainer(cli, containerID, cmd); err != nil {
		glog.Errorf("%v", err)
	}
}

func removeDeviceFromContainer(cli *docker.Client, containerID, devicePath, sysFSPrefix string, devMajor, devMinor int, deviceFileMode os.FileMode) {
	// Remove device from cgroup
	cgroupPathPattern := fmt.Sprintf("%s/sys/fs/cgroup/devices/kubepods/burstable/*/%s/devices.deny", sysFSPrefix, containerID)
	files, err := filepath.Glob(cgroupPathPattern)
	if err != nil {
		glog.Errorf("failed to glob path to find cgroup path in pattern '%s': %v", cgroupPathPattern, err)
	}
	if len(files) == 1 {
		// Write the device node to the devices.deny cgroup sys file.
		cgroupPerms := fmt.Sprintf("c %d:%d rwm", devMajor, devMinor)
		if err := ioutil.WriteFile(files[0], []byte(cgroupPerms), deviceFileMode); err != nil {
			glog.Errorf("failed to write cgroup permissions to %s", cgroupPathPattern)
		}
	} else {
		glog.Errorf("failed to find single cgroup devices.deny at: %s, expected 1, found %d", cgroupPathPattern, len(files))
	}

	// Remove device to container using docker exec.
	cmd := []string{
		"/bin/rm",
		"-f",
		devicePath,
	}
	if err := execContainer(cli, containerID, cmd); err != nil {
		glog.Errorf("%v", err)
	}
}

func execContainer(cli *docker.Client, containerID string, cmd []string) error {
	ctx := context.Background()
	createExecResp, err := cli.ContainerExecCreate(ctx, containerID, types.ExecConfig{
		User: "root",
		Cmd:  cmd,
	})
	if err != nil {
		return fmt.Errorf("failed to create container exec for container %s: %v", containerID, err)
	}
	if err := cli.ContainerExecStart(ctx, createExecResp.ID, types.ExecStartCheck{}); err != nil {
		return fmt.Errorf("failed to exec rm in container %s: %v", containerID, err)
	}
	return nil
}
