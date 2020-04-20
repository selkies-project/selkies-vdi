#!/bin/bash

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

cat > noop.py <<EOF
import time
print("entering debug mode.")
while True:
    time.sleep(1)
EOF

cp main.py main_debug.py

cp noop.py main.py

kill $(pidof python3)

echo 'run main script manually as: '
echo 'GST_DEBUG="GST_TRACER:6" GST_TRACERS="queuelevel" python3 main_debug.py'