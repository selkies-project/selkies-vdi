/**
 * Copyright 2020 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

// Adds auto fullscreen feature of default_settings.auto_fullscreen is found.
XpraClient.prototype.request_redraw_orig = XpraClient.prototype.request_redraw;
XpraClient.prototype.request_redraw = function (win) {
    if (default_settings !== undefined && default_settings.auto_fullscreen !== undefined && default_settings.auto_fullscreen.length > 0) {
        var pattern = new RegExp(".*" + default_settings.auto_fullscreen + ".*");
        if (win.fullscreen === false && win.metadata.title.match(pattern)) {
            clog("auto fullscreen window: " + win.metadata.title);
            win.set_fullscreen(true);
        }
    }
    // Call original function.
    return client.request_redraw_orig(win);
};