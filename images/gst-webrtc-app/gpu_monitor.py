# Google LLC 2019
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

import GPUtil
import time

import logging
logger = logging.getLogger("gpu_monitor")


class GPUMonitor:
    def __init__(self, period=1):
        self.period = period
        self.running = False

        self.on_stats = lambda load, memoryTotal, memoryUsed: logger.warn(
            "unhandled on_stats")

    def start(self):
        self.running = True
        while self.running:
            gpu = GPUtil.getGPUs()[0]
            self.on_stats(gpu.load, gpu.memoryTotal, gpu.memoryUsed)
            time.sleep(self.period)

    def stop(self):
        self.running = False
