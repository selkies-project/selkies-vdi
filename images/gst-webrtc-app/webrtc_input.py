# Copyright 2019 Google LLC
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

from Xlib import X, XK, display, ext
import base64
import pynput
import uinput
import os
import msgpack
import re
import subprocess
from subprocess import Popen, PIPE, STDOUT
import socket
import time

import logging
logger = logging.getLogger("webrtc_input")

JS_BTNS = (
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

JS_AXES = (
    uinput.ABS_X + (-32768, 32767, 0, 0),
    uinput.ABS_Y + (-32768, 32767, 0, 0),
    uinput.ABS_RX + (-32768, 32767, 0, 0),
    uinput.ABS_RY + (-32768, 32767, 0, 0),
    uinput.ABS_Z + (-32768, 32767, 0, 0),
    uinput.ABS_RZ + (-32768, 32767, 0, 0),
    uinput.ABS_HAT0X + (-1, 1, 0, 0),
    uinput.ABS_HAT0Y + (-1, 1, 0, 0),
)

# Local enumerations for mouse actions.
MOUSE_POSITION = 10
MOUSE_MOVE = 11
MOUSE_SCROLL_UP = 20
MOUSE_SCROLL_DOWN = 21
MOUSE_BUTTON_PRESS = 30
MOUSE_BUTTON_RELEASE = 31
MOUSE_BUTTON = 40
MOUSE_BUTTON_LEFT = 41
MOUSE_BUTTON_MIDDLE = 42
MOUSE_BUTTON_RIGHT = 43

# Local map for uinput and pynput buttons
MOUSE_BUTTON_MAP = {
    MOUSE_BUTTON_LEFT: {
        "uinput": uinput.BTN_LEFT,
        "pynput": pynput.mouse.Button.left,
    },
    MOUSE_BUTTON_MIDDLE: {
        "uinput": uinput.BTN_MIDDLE,
        "pynput": pynput.mouse.Button.middle,
    },
    MOUSE_BUTTON_RIGHT: {
        "uinput": uinput.BTN_RIGHT,
        "pynput": pynput.mouse.Button.right,
    },
}

class WebRTCInputError(Exception):
    pass


class WebRTCInput:
    def __init__(self, uinput_mouse_socket_path="", uinput_js_socket_path="", enable_clipboard=""):
        """Initializes WebRTC input instance
        """
        self.clipboard_running = False
        self.uinput_mouse_socket_path = uinput_mouse_socket_path
        self.uinput_mouse_socket = None

        self.uinput_js_socket_path = uinput_js_socket_path
        self.uinput_js_socket = None

        self.enable_clipboard = enable_clipboard

        self.mouse = None
        self.joystick = None
        self.xdisplay = None
        self.button_mask = 0

        self.on_video_encoder_bit_rate = lambda bitrate: logger.warn(
            'unhandled on_video_encoder_bit_rate')
        self.on_audio_encoder_bit_rate = lambda bitrate: logger.warn(
            'unhandled on_audio_encoder_bit_rate')
        self.on_mouse_pointer_visible = lambda visible: logger.warn(
            'unhandled on_mouse_pointer_visible')
        self.on_clipboard_read = lambda data: logger.warn(
            'unhandled on_clipboard_read')
        self.on_set_fps = lambda fps: logger.warn(
            'unhandled on_set_fps')
        self.on_set_enable_audio = lambda enable_audio: logger.warn(
            'unhandled on_set_enable_audio')
        self.on_client_fps = lambda fps: logger.warn(
            'unhandled on_client_fps')
        self.on_client_latency = lambda latency: logger.warn(
            'unhandled on_client_latency')
        self.on_resize = lambda res: logger.warn(
            'unhandled on_resize')

    def __mouse_connect(self):
        if self.uinput_mouse_socket_path:
            # Proxy uinput mouse commands through unix domain socket.
            logger.info("Connecting to uinput mouse socket: %s" % self.uinput_mouse_socket_path)
            self.uinput_mouse_socket = socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM)

        self.mouse = pynput.mouse.Controller()

    def __mouse_disconnect(self):
        if self.mouse:
            del self.mouse

    def __mouse_emit(self, *args, **kwargs):
        if self.uinput_mouse_socket_path:
            cmd = {"args": args, "kwargs": kwargs}
            data = msgpack.packb(cmd, use_bin_type=True)
            self.uinput_mouse_socket.sendto(data, self.uinput_mouse_socket_path)

    def __js_connect(self, num_axes, num_buttons):
        """Connect virtual joystick

        Arguments:
            num_axes {integer} -- number of joystick axes
            num_buttons {integer} -- number of joystick buttons
        """

        if self.uinput_js_socket_path:
            # Proxy uinput joystick commands through unix domain socket
            logger.info("Connecting to uinput joystick socket: %s" % self.uinput_js_socket_path)
            self.uinput_js_socket = socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM)
        else:
            logger.info("initializing joystick with %d buttons and %d axes" %
                        (num_buttons, num_axes))
            axes = JS_AXES[:min(len(JS_AXES), num_axes)]
            btns = JS_BTNS[:min(len(JS_BTNS), num_buttons)]
            self.joystick = uinput.Device(btns + axes,
                                        vendor=0x045e,
                                        product=0x028e,
                                        version=0x110,
                                        name="Microsoft X-Box 360 pad")

    def __js_disconnect(self):
        if self.joystick:
            del self.joystick

    def __js_emit(self, *args, **kwargs):
        if self.uinput_js_socket_path:
            cmd = {"args": args, "kwargs": kwargs}
            data = msgpack.packb(cmd, use_bin_type=True)
            self.uinput_js_socket.sendto(data, self.uinput_js_socket_path)
        else:
            if self.joystick is not None:
                self.joystick.emit(*args, **kwargs)

    async def connect(self):
        """Connects to X server

        The target X server is determiend by the DISPLAY environment variable.
        """

        self.xdisplay = display.Display()

        # Clear any stuck modifier keys
        self.reset_keyboard()

        self.__mouse_connect()

    def disconnect(self):
        self.__js_disconnect()
        self.__mouse_disconnect()

    def reset_keyboard(self):
        """Resets any stuck modifier keys
        """

        logger.info("Resetting keyboard modifiers.")

        lctrl = 65507
        lshift = 65505
        lalt = 65513

        rctrl = 65508
        rshift = 65506
        ralt = 65027

        lmeta = 65511
        rmeta = 65512

        keyf = 102
        keyF = 70

        keym = 109
        keyM = 77

        escape = 65307

        for k in [lctrl, lshift, lalt, rctrl, rshift, ralt, lmeta, rmeta, keyf, keyF, keym, keyM, escape]:
            self.send_x11_keypress(k, down=False)

    def send_mouse(self, action, data):
        if action == MOUSE_POSITION:
            # data is a tuple of (x, y)
            # using X11 mouse even when virtual mouse is enabled for non-relative actions.
            self.mouse.position = data
        elif action == MOUSE_MOVE:
            # data is a tuple of (x, y)
            x, y = data
            if self.uinput_mouse_socket_path:
                # Send relative motion to uinput device.
                # syn=False delays the sync until the second command.
                self.__mouse_emit(uinput.REL_X, x, syn=False)
                self.__mouse_emit(uinput.REL_Y, y)
            else:
                self.mouse.move(x, y)
        elif action == MOUSE_SCROLL_UP:
            # Scroll up
            if self.uinput_mouse_socket_path:
                self.__mouse_emit(uinput.REL_WHEEL, 1)
            else:
                self.mouse.scroll(0, -1)
        elif action == MOUSE_SCROLL_DOWN:
            # Scroll down
            if self.uinput_mouse_socket_path:
                self.__mouse_emit(uinput.REL_WHEEL, -1)
            else:
                self.mouse.scroll(0, 1)
        elif action == MOUSE_BUTTON:
            # Button press/release, data is a tuple of (MOUSE_BUTTON_PRESS|MOUSE_BUTTON_RELEASE, MOUSE_BUTTON_enum)
            if self.uinput_mouse_socket_path:
                btn = MOUSE_BUTTON_MAP[data[1]]["uinput"]
            else:
                btn = MOUSE_BUTTON_MAP[data[1]]["pynput"]

            if data[0] == MOUSE_BUTTON_PRESS:
                if self.uinput_mouse_socket_path:
                    self.__mouse_emit(btn, 1)
                else:
                    self.mouse.press(btn)
            else:
                if self.uinput_mouse_socket_path:
                    self.__mouse_emit(btn, 0)
                else:
                    self.mouse.release(btn)

    def send_x11_keypress(self, keysym, down=True):
        """Sends keypress to X server

        The key sym is converted to a keycode using the X server library.

        Arguments:
            keysym {integer} -- the key symbol to send

        Keyword Arguments:
            down {bool} -- toggle key down or up (default: {True})
        """

        keycode = self.xdisplay.keysym_to_keycode(keysym)
        if down:
            ext.xtest.fake_input(self.xdisplay, X.KeyPress, keycode)
        else:
            ext.xtest.fake_input(self.xdisplay, X.KeyRelease, keycode)

        self.xdisplay.sync()

    def send_x11_mouse(self, x, y, button_mask, relative=False):
        """Sends mouse events to the X server.

        The mouse button mask is stored locally to keep track of press/release state.

        Relative motion is sent to the uninput device for improved tracking.

        Arguments:
            x {integer} -- mouse position X
            y {integer} -- mouse position Y
            button_mask {integer} -- mask of 5 mouse buttons, button 1 is at the LSB.
        """

        # Mouse motion
        if relative:
            self.send_mouse(MOUSE_MOVE, (x, y))
        else:
            self.send_mouse(MOUSE_POSITION, (x, y))

        # Button press and release
        if button_mask != self.button_mask:
            max_buttons = 5
            for i in range(0, max_buttons):
                if (button_mask ^ self.button_mask) & (1 << i):

                    action = MOUSE_BUTTON
                    btn_action = MOUSE_BUTTON_PRESS
                    btn_num = MOUSE_BUTTON_LEFT

                    if (button_mask & (1 << i)):
                        btn_action = MOUSE_BUTTON_PRESS
                    else:
                        btn_action = MOUSE_BUTTON_RELEASE

                    # Remap middle and right buttons in relative mode.
                    if i == 1:
                        btn_num = MOUSE_BUTTON_MIDDLE
                    elif i == 2:
                        btn_num = MOUSE_BUTTON_RIGHT
                    elif i == 3:
                        # Wheel up
                        action = MOUSE_SCROLL_UP
                    elif i == 4:
                        # Wheel down
                        action = MOUSE_SCROLL_DOWN

                    data = (btn_action, btn_num)
                    self.send_mouse(action, data)

            # Update the button mask to remember positions.
            self.button_mask = button_mask

        if not relative:
            self.xdisplay.sync()

    def read_clipboard(self):
        return subprocess.getoutput("xclip -out")

    def write_clipboard(self, data):
        cmd = ['xclip', '-selection', 'clipboard', '-in']
        p = Popen(cmd, stdin=PIPE)
        p.communicate(input=data.encode())
        p.wait()

    def start_clipboard(self):
        if self.enable_clipboard in ["true", "out"]:
            logger.info("starting clipboard monitor")
            self.clipboard_running = True
            last_data = ""
            while self.clipboard_running:
                curr_data = self.read_clipboard()
                if curr_data and curr_data != last_data:
                    logger.info("sending clipboard content, length: %d" % len(curr_data))
                    self.on_clipboard_read(curr_data)
                    last_data = curr_data
                time.sleep(0.5)
        else:
            logger.info("skipping outbound clipboard service.")

    def stop_clipboard(self):
        logger.info("stopping clipboard monitor")
        self.clipboard_running = False

    def on_message(self, msg):
        """Handles incoming input messages

        Bound to a data channel, handles input messages.

        Message format: <command>,<data>

        Supported message commands:
          kd: key down event, data is keysym
          ku: key up event, data is keysym
          m: mouse event, data is csv of: x,y,button mask
          b: bitrate event, data is the desired encoder bitrate in bps.
          js: joystick connect/disconnect/button/axis event

        Arguments:
            msg {string} -- the raw data channel message packed in the <command>,<data> format.
        """

        toks = msg.split(",")
        if toks[0] == "kd":
            # Key down
            self.send_x11_keypress(int(toks[1]), down=True)
        elif toks[0] == "ku":
            # Key up
            self.send_x11_keypress(int(toks[1]), down=False)
        elif toks[0] == "kr":
            # Keyboard reset
            self.reset_keyboard()
        elif toks[0] in ["m", "m2"]:
            # Mouse action
            # x,y,button_mask
            relative = False
            if toks[0] == "m2":
                relative = True
            self.send_x11_mouse(*[int(i) for i in toks[1:]], relative)
        elif toks[0] == "p":
            # toggle mouse pointer visibility
            visible = bool(int(toks[1]))
            logger.info("Setting pointer visibility to: %s" % str(visible))
            self.on_mouse_pointer_visible(visible)
        elif toks[0] == "vb":
            # Set video bitrate
            bitrate = int(toks[1])
            logger.info("Setting video bitrate to: %d" % bitrate)
            self.on_video_encoder_bit_rate(bitrate)
        elif toks[0] == "ab":
            # Set audio bitrate
            bitrate = int(toks[1])
            logger.info("Setting audio bitrate to: %d" % bitrate)
            self.on_audio_encoder_bit_rate(bitrate)
        elif toks[0] == "js":
            # Joystick
            # init: i,<type>,<num axes>,<num buttons>
            # button: b,<btn_num>,<value>
            # axis: a,<axis_num>,<value>
            if toks[1] == 'c':
                num_axes = int(toks[2])
                num_btns = int(toks[3])
                try:
                    self.__js_connect(num_axes, num_btns)
                except Exception as e:
                    logger.error("Failed to initialize joystick: %s", e)
            elif toks[1] == 'd':
                self.__js_disconnect()
            elif toks[1] == 'b':
                btn_num = int(toks[2])
                btn_on = toks[3] == '1'
                self.__js_emit((uinput.BTN_0[0], btn_num), btn_on)
            elif toks[1] == 'a':
                axis_num = int(toks[2])
                axis_val = int(toks[3])
                self.__js_emit((uinput.ABS_X[0], axis_num), axis_val)
            else:
                logger.warning('unhandled joystick command: %s' % toks[1])
        elif toks[0] == "cr":
            # Clipboard read
            if self.enable_clipboard in ["true", "out"]:
                data = self.read_clipboard()
                if data:
                    logger.info("read clipboard content, length: %d" % len(data))
                    self.on_clipboard_read(data)
                else:
                    logger.warning("no clipboard content to send")
            else:
                logger.warning("rejecting clipboard read because outbound clipboard is disabled.")
        elif toks[0] == "cw":
            # Clipboard write
            if self.enable_clipboard in ["true", "in"]:
                data = base64.b64decode(toks[1]).decode()
                self.write_clipboard(data)
                logger.info("set clipboard content, length: %d" % len(data))
            else:
                logger.warning("rejecting clipboard write because inbound clipboard is disabled.")
        elif toks[0] == "r":
            # resize event
            res = toks[1]
            if not re.match(re.compile(r'^\d+x\d+$'), res):
                logger.warning("rejecting resolution change: %s" % res)
            # Make sure resolution is divisible by 2
            x, y = [int(i) + int(i)%2 for i in res.split("x")]
            # scale to min/max size for resolution
            x = min(3840, max(100, x))
            y = min(2160, max(100, y))
            self.on_resize("%dx%d" % (x, y))
        elif toks[0] == "_arg_fps":
            # Set framerate
            fps = int(toks[1])
            logger.info("Setting framerate to: %d" % fps)
            self.on_set_fps(fps)
        elif toks[0] == "_arg_audio":
            # Set audio enabled
            enabled = toks[1].lower() == "true"
            logger.info("Setting enable_audio to: %s" % str(enabled))
            self.on_set_enable_audio(enabled)
        elif toks[0] == "_f":
            # Reported FPS from client.
            fps = int(toks[1])
            self.on_client_fps(fps)
        elif toks[0] == "_l":
            # Reported latency from client.
            latencty_ms = int(toks[1])
            self.on_client_latency(latencty_ms)
        else:
            logger.info('unknown data channel message: %s' % msg)
