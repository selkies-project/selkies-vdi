# Copyright 2019 Google Inc. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import argparse
import asyncio
import glob
import hashlib
import msgpack
import os
import random
import socket
import tempfile
import time
import uinput
from io import BytesIO

import logging
logger = logging.getLogger("uinput_devices")


class DeviceError(Exception):
    pass


class UInputDeviceRegistry():
    def __init__(self):
        self.devices = {}

    def refresh(self):
        """Looks for devices in the /sys/devices/virtual/input* path

        Found devices are added to the self.devices map.
        """

        event_pat = "/sys/devices/virtual/input/input*/event*"
        uevent_pat = "/sys/devices/virtual/input/input*/uevent"

        for evpath, _ in zip(glob.glob(event_pat), glob.glob(uevent_pat)):
            input_name = os.path.basename(os.path.dirname(evpath))
            evdev = os.path.basename(evpath)
            self.devices[evdev] = input_name

    def diff(self):
        old_devices = self.devices.copy()
        self.refresh()

        new_devices = []
        deleted_devices = []

        for k,v in old_devices.items():
            if k not in self.devices:
                deleted_devices.append((k,v))

        for k,v in self.devices.items():
            if k not in old_devices:
                new_devices.append((k,v))

        return new_devices, deleted_devices


class UInputProtocol(asyncio.DatagramProtocol):
    def __init__(self, input_device, loop):
        self.input_device = input_device
        self.sock_path = input_device.get_socket_path()
        self.device = input_device.device
        self.loop = loop
        self.transport = None

        self.unpacker = msgpack.Unpacker(use_list=False, raw=False)

    def _debug_log(self, msg):
        logger.debug("%s: %s" % (self.sock_path, msg))

    def _info_log(self, msg):
        logger.info("%s: %s" % (self.sock_path, msg))

    def _error_log(self, msg):
        logger.error("%s: %s" % (self.sock_path, msg))

    def connection_made(self, transport):
        self.transport = transport
        self._debug_log("transport connected")
        self.input_device.socket_ready.set()

    def connection_lost(self, exc):
        self._error_log("connection lost")
        raise DeviceError(exc)

    def error_received(self, exc):
        self._error_log("protocol error: %s" % exc)

    def datagram_received(self, data, addr):
        self.unpacker.feed(data)
        try:
            for d in self.unpacker:
                args = d.get("args", [])
                kwargs = d.get("kwargs", {})

                self._debug_log("args: %s, kwargs: %s" % (args, kwargs))

                try:
                    self.device.emit(*args, **kwargs)
                except Exception as e:
                    self._error_log("failed to emit uinput event: %s" % str(e))
        except Exception as e:
            self._error_log("failed to process message: %s" % e)

class DeviceBase:
    def __init__(self, registry=None, name="Virtual Input Device", socket_dir="/tmp/.uinput"):
        self.registry = registry
        self.name = name
        self.device_pattern = ""
        self.socket_dir = socket_dir
        self.vendor = 0
        self.product = 0
        self.version = 0

        self.events = []
        self.device = None
        self.ev_name = None
        self.device_path = None
        self.symlink_path = None
        self.sock_path = None
        self.socket_ready = asyncio.Event()

    def get_sys_input_pattern(self):
        return "/sys/devices/virtual/input/%s/%s" % (self.input_name, self.device_pattern)

    def get_sys_input_name(self):
        name_path = "/sys/devices/virtual/input/%s/name" % (self.input_name)
        if os.path.exists(name_path):
            with open(name_path, 'r') as f:
                return f.read().rstrip()
        else:
            return None

    def create_device(self):
        """Creates the uinput device
        """
        self.registry.refresh()
        self.device = uinput.Device(self.events,
                                    name=self.name,
                                    vendor=self.vendor,
                                    product=self.product,
                                    version=self.version)

        created, deleted = self.registry.diff()

        if len(created) == 0:
            raise DeviceError("failed to create uinput device, new device not found.")
        elif len(created) > 1:
            raise DeviceError("more than 1 new uinput device found after creation.")

        return created[0]

    async def wait_for_device(self):
        while True:
            res = glob.glob(self.get_sys_input_pattern())
            if res and self.get_sys_input_name() == self.name:
                self.device_path = "/dev/input/%s" % os.path.basename(res[0])
                break
            await asyncio.sleep(0.1)

    def get_socket_path(self):
        return os.path.join(self.socket_dir, self.ev_name)

    def start(self, loop):
        """Creates the device, finds the device in /dev, starts the socket.

        Raises:
            DeviceError -- If device cannot be found in /dev
        """

        # Create the uinput device
        self.ev_name, self.input_name = self.create_device()

        logger.debug("Created new uinput device: %s -> %s, %s" % (self.name, self.ev_name, self.input_name))

        return loop.create_datagram_endpoint(lambda: UInputProtocol(self, loop),
                                             local_addr=self.get_socket_path(),
                                             family=socket.AF_UNIX,
                                             reuse_address=True)
    async def wait_for_socket(self):
        await self.socket_ready.wait()

    def disconnect(self):
        if os.path.exists(self.get_socket_path()):
            os.unlink(self.get_socket_path())
        if self.device:
            del self.device


class MouseDevice(DeviceBase):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.device_pattern = "event*"
        self.events = (
            uinput.REL_X,
            uinput.REL_Y,
            uinput.BTN_LEFT,
            uinput.BTN_MIDDLE,
            uinput.BTN_RIGHT,
            uinput.REL_WHEEL,
        )


class JoystickDevice(DeviceBase):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.device_pattern = "js*"
        self.js_btns = (
            uinput.BTN_GAMEPAD,
            uinput.BTN_EAST,
            uinput.BTN_NORTH,
            uinput.BTN_WEST,
            uinput.BTN_TL,
            uinput.BTN_TR,
            uinput.BTN_SELECT,
            uinput.BTN_START,
            uinput.BTN_THUMBL,
            uinput.BTN_THUMBR,
            uinput.BTN_MODE,
        )

        self.js_axes = (
            uinput.ABS_X + (-32768, 32767, 0, 0),
            uinput.ABS_Y + (-32768, 32767, 0, 0),
            uinput.ABS_RX + (-32768, 32767, 0, 0),
            uinput.ABS_RY + (-32768, 32767, 0, 0),
            uinput.ABS_Z + (-32768, 32767, 0, 0),
            uinput.ABS_RZ + (-32768, 32767, 0, 0),
            uinput.ABS_HAT0X + (-1, 1, 0, 0),
            uinput.ABS_HAT0Y + (-1, 1, 0, 0),
        )

        self.events = self.js_btns + self.js_axes

        self.vendor = 0x045e
        self.product = 0x028e
        self.version = 0x110


def cleanup(socket_dir, mice_ready_file, js_ready_file):
    # remove the ready files
    if os.path.exists(mice_ready_file):
        os.unlink(mice_ready_file)

    if os.path.exists(js_ready_file):
        os.unlink(js_ready_file)

    # remove all sockets
    for f in glob.glob(os.path.join(socket_dir, "event*")):
        if os.path.exists(f):
            try:
                os.unlink(f)
            except:
                pass

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument('--socket_dir',
                        default=os.environ.get(
                            'SOCKET_DIR', '/tmp/.uinput'),
                        help='Path to directory where unix sockets are created for communication.')
    parser.add_argument('--num_mice',
                        default=os.environ.get(
                            'UINPUT_NUM_MICE', '16'),
                        help='Number of virtual mice to create')
    parser.add_argument('--mice_name',
                        default=os.environ.get(
                            'UINPUT_MICE_NAME', 'Virtual Input Mouse'),
                        help='Name prefix for virutal mice')
    parser.add_argument('--mice_ready_file',
                        default=os.environ.get(
                            'UINPUT_MICE_READY_FILE', '/tmp/.uinput/mouse_devices_ready'),
                        help='File to create after all mouse devices have been initialized.')
    parser.add_argument('--num_js',
                        default=os.environ.get(
                            'UINPUT_NUM_JS', '16'),
                        help='Number of virtual joysticks to create')
    parser.add_argument('--js_name',
                        default=os.environ.get(
                            'UINPUT_JS_NAME', 'Microsoft X-Box 360 pad'),
                        help='Name prefix for virutal joystick')
    parser.add_argument('--js_ready_file',
                        default=os.environ.get(
                            'UINPUT_JS_READY_FILE', '/tmp/.uinput/js_devices_ready'),
                        help='File to create after all joystick devices have been initialized.')
    parser.add_argument('--cleanup', action='store_true',
                        help='Run cleanup')
    parser.add_argument('--debug', action='store_true',
                        help='Enable debug logging')
    args = parser.parse_args()

    # Set log level
    if args.debug:
        logging.basicConfig(level=logging.DEBUG)
    else:
        logging.basicConfig(level=logging.INFO)

    if not os.path.exists(args.socket_dir):
        logger.info("Creating socket directory: %s" % args.socket_dir)
        os.makedirs(args.socket_dir)

    if args.cleanup:
        logger.info("running cleanup")
        cleanup(args.socket_dir, args.mice_ready_file, args.js_ready_file)
        sys.exit(0)

    # Always cleanup before starting.
    cleanup(args.socket_dir, args.mice_ready_file, args.js_ready_file)

    registry = UInputDeviceRegistry()
    registry.refresh()

    loop = asyncio.get_event_loop()

    num_mice = int(args.num_mice)
    logger.info("Creating %d virtual mice with control paths at: %s" % (num_mice, args.socket_dir))
    mouse_devices = []
    tmp_link_dir = tempfile.mkdtemp(dir="/dev/input")
    for i in range(num_mice):
        d = MouseDevice(registry=registry, name=args.mice_name, socket_dir=args.socket_dir)
        mouse_devices.append(d)
        asyncio.ensure_future(d.start(loop))
        logger.debug("Waiting for mouse device: %s -> %s" % (d.name, d.get_sys_input_pattern()))
        loop.run_until_complete(d.wait_for_device())
        loop.run_until_complete(d.wait_for_socket())
        d.symlink_path = "/dev/input/mouse%d" % i
        tmp_link = os.path.join(tmp_link_dir, os.path.basename(d.symlink_path))
        os.symlink(d.device_path, tmp_link)
        os.rename(tmp_link, d.symlink_path)
        logger.info("Created mouse device: %s -> %s, %s, %s" % (d.name, d.ev_name, d.device_path, d.symlink_path))
    os.rmdir(tmp_link_dir)

    # Create the ready file
    open(args.mice_ready_file, "w").close()

    num_js = int(args.num_js)
    logger.info("Creating %d virtual joysticks with control paths at: %s" % (num_js, args.socket_dir))
    js_devices = []
    for i in range(num_js):
        d = JoystickDevice(registry=registry, name=args.js_name, socket_dir=args.socket_dir)
        js_devices.append(d)
        asyncio.ensure_future(d.start(loop))
        logger.debug("Waiting for joystick device: %s -> %s" % (d.name, d.get_sys_input_pattern()))
        loop.run_until_complete(d.wait_for_device())
        loop.run_until_complete(d.wait_for_socket())
        logger.info("Created joystick device: %s -> %s, %s" % (d.name, d.ev_name, d.device_path))

    # Create the ready file.
    open(args.js_ready_file, "w").close()

    logger.info("Device creation complete, waiting for clients.")

    try:
        loop.run_forever()
    except:
        pass
    finally:
        for d in mouse_devices + js_devices:
            logger.info("Removing device: %s" % d.name)
            d.disconnect()

        cleanup(args.socket_dir, args.mice_ready_file, args.js_ready_file)
