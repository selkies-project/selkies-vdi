import argparse
import socket
import sys
import os
import msgpack
import uinput
import time

import logging
logger = logging.getLogger("uinput_client")

class ClientTest:
    def __init__(self, socket_path):
        self.socket_path = socket_path
        self.sock = None
    
    def send(self, data):
        self.sock.sendto(data, self.socket_path)
    
    def connect(self):
        logger.info("Connecting to socket: %s" % self.socket_path)
        self.sock = socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM)

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument('--socket',
                        default=os.environ.get(
                            'UINPUT_SOCKET', ""),
                        help='Path to unix domain socket.')
    parser.add_argument('--device-type', help='Type of device, mouse or js')
    parser.add_argument('--debug', action='store_true',
                        help='Enable debug logging')
    args = parser.parse_args()

    # Set log level
    if args.debug:
        logging.basicConfig(level=logging.DEBUG)
    else:
        logging.basicConfig(level=logging.INFO)
    
    if len(args.socket) == 0:
        logger.error("Missing --socket or UINPUT_SOCKET")
        sys.exit(1)

    if not os.path.exists(args.socket):
        logger.error("socket not found: %s" % args.socket)
        sys.exit(1)
    
    if not args.device_type in ["mouse", "js"]:
        logger.error("unknown device type: %s" % args.device_type)
        sys.exit(1)

    c = ClientTest(args.socket)
    c.connect()

    if args.device_type == "mouse":
        # Test mouse button
        cmd = {"args": [uinput.BTN_LEFT, 1], "kwargs": {"syn": True}}
        logger.info("sending: %s" % cmd)
        c.send(msgpack.packb(cmd))

        time.sleep(0.2)

        cmd = {"args": [uinput.BTN_LEFT, 0], "kwargs": {"syn": True}}
        logger.info("sending: %s" % cmd)
        c.send(msgpack.packb(cmd))
    elif args.device_type == "js":
        # Test joystick button
        cmd = {"args": [uinput.BTN_GAMEPAD, 1], "kwargs": {"syn": True}}
        logger.info("sending %s" % cmd)
        c.send(msgpack.packb(cmd))

        time.sleep(0.2)

        cmd = {"args": [uinput.BTN_GAMEPAD, 0], "kwargs": {"syn": True}}
        logger.info("sending %s" % cmd)
        c.send(msgpack.packb(cmd))

    time.sleep(1)