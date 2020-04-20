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

import asyncio
import math
import sys
import time
import os

from Xlib import X, XK, display
from Xlib.ext import record
from Xlib.protocol import rq

import logging
logger = logging.getLogger("xserver_watchdog")

"""Watchdog that monitors X input events

Events:

    on_idle: called when idle is detected
    on_timeout: called whn watchdog expires.
"""


class XServerWatchdogError(Exception):
    pass


class XServerWatchdog:
    def __init__(self, idle=10, timeout=600):
        """Initializes watchdog

        Keyword Arguments:
            idle {int} -- idle detection time in seconds (default: {10})
            timeout {int} -- timeout in seconds (default: {600})
        """

        self.__local_dpy = display.Display()
        self.__record_dpy = display.Display()
        self.__ctx = None

        self.idle = idle
        self.timeout = timeout
        self.last_event_time = time.time()
        self.running = False
        self.is_idle = False
        self.on_idle = lambda: logger.warning("unhandled on_idle")
        self.on_timeout = lambda: logger.warning("unhandled on_timeout")

    def stroke(self):
        """Strokes the watchdog

        Sets the last event time to the current time. 
        Must be called periodically before timeout occurs. 
        Called by self.monitor()
        """

        t = time.time()
        logger.debug("saw event at %f" % t)
        self.last_event_time = t

    def __record_callback(self, reply):
        """Handler for Xlib event recorder

        Detects any events and strokes the watchdog.

        Arguments:
            reply {event} -- the x event
        """

        if reply.category != record.FromServer:
            return
        if reply.client_swapped:
            logger.warning(
                "* received swapped protocol data, cowardly ignored")
            return
        if not len(reply.data) or reply.data[0] < 2:
            # not an event
            return

        # Stroke the watchdog
        self.stroke()

    def start(self):
        """Starts watching for x events using recorder extension

        Starts monitoring events and passes them to self.__record_callback
        Blocks until self.stop() is called.

        Raises:
            XServerWatchdogError -- raised if X server does not support RECORD extension.
        """

        # Check if the extension is present
        if not self.__record_dpy.has_extension("RECORD"):
            raise XServerWatchdogError("RECORD extension not found")
        r = self.__record_dpy.record_get_version(0, 0)
        logger.info("RECORD extension version %d.%d" %
                    (r.major_version, r.minor_version))

        # Create a recording context; we only want key and mouse events
        self.__ctx = self.__record_dpy.record_create_context(
            0,
            [record.AllClients],
            [{
                'core_requests': (0, 0),
                'core_replies': (0, 0),
                'ext_requests': (0, 0, 0, 0),
                'ext_replies': (0, 0, 0, 0),
                'delivered_events': (0, 0),
                'device_events': (X.KeyPress, X.MotionNotify),
                'errors': (0, 0),
                'client_started': False,
                'client_died': False,
            }])

        logger.info("Starting Xserver watchdog with idle=%ds and timeout=%ds" % (
            self.idle, self.timeout))

        # Enable the context; this only returns after a call to record_disable_context,
        # while calling the callback function in the meantime
        self.__record_dpy.record_enable_context(
            self.__ctx, self.__record_callback)

        # Finally free the context
        self.__record_dpy.record_free_context(self.__ctx)

    def stop(self):
        """Stops watching x events.
        """

        if self.__ctx is not None:
            self.__local_dpy.record_disable_context(self.__ctx)
            self.__local_dpy.flush()
        self.running = False

    def ttl(self):
        """Computes time to live for idle and timeouts

        Returns:
            [int] -- seconds until idle is triggered
            [int] -- seconds until timeout is triggered
        """

        delta = int(time.time() - self.last_event_time)
        return max(0, self.idle - delta), max(0, self.timeout - delta)

    def monitor(self):
        """Main timeout monitor loop

        Monitors for idle and timeout states.
        Blocks and returns after watchdog expires due to timeout exceeded.
        Calls any bound event handlers in the meantime.

        Events:
            on_idle: called when idle state is detected
            on_timeout: called when watchdog expires.
        """

        self.running = True
        idle_ttl, timeout_ttl = self.ttl()
        last_idle_ttl = idle_ttl

        while self.running:
            # Change detection
            if self.is_idle and idle_ttl == self.idle and idle_ttl != last_idle_ttl:
                logger.info("watchdog reset")
                self.is_idle = False

            # Detect idle state
            if idle_ttl <= 0 and idle_ttl != last_idle_ttl:
                logger.info(
                    "idle detected, watchdog expires in %d seconds" % timeout_ttl)
                self.is_idle = True
                self.on_idle()

            # Detect watchdog expiration
            if timeout_ttl <= 0:
                logger.info("watchdog expired")
                self.on_timeout()
                self.stop()

            time.sleep(0.5)

            last_idle_ttl = idle_ttl

            idle_ttl, timeout_ttl = self.ttl()

        logger.debug("monitor loop completed")


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser()
    parser.add_argument('--idle', type=int, default=10,
                        help='seconds until idle is detected, default: 5')
    parser.add_argument('--timeout', type=int, default=int(os.getenv("WATCHDOG_TIMEOUT", 3600)),
                        help='seconds until watchdog expires, default: 3600, -1 implies infinite timeout')
    parser.add_argument('--on_idle', default=':',
                        help='script to run when watchdog expires')
    parser.add_argument('--on_timeout', default='echo "handling watchdog timeout"',
                        help='script to run when watchdog expires')
    parser.add_argument('--debug', action='store_true',
                        help='Enable debug logging')
    args = parser.parse_args()

    # Set log level
    if args.debug:
        logging.basicConfig(level=logging.DEBUG)
    else:
        logging.basicConfig(level=logging.INFO)

    if args.timeout == -1:
        logger.info("Timeout is -1, spinning")
        while True:
            time.sleep(1)
    else:
        w = XServerWatchdog(idle=args.idle, timeout=args.timeout)
        w.on_idle = lambda: os.system(args.on_idle)
        w.on_timeout = lambda: os.system(args.on_timeout)

        try:
            tasks = [
                asyncio.get_event_loop().run_in_executor(None, lambda: w.start()),
                asyncio.get_event_loop().run_in_executor(None, lambda: w.monitor()),
            ]
            asyncio.get_event_loop().run_until_complete(asyncio.wait(tasks))
        finally:
            w.stop()
