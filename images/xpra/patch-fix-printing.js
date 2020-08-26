/**
 * Copyright 2019 Google LLC
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

// Fixes issues with opening pdf content in browser.
XpraClient.prototype.print_document = function (filename, data, mimetype) {
    if (!this.printing || !this.remote_printing) {
        this.warn("Received data to print but printing is not enabled!");
        return;
    }
    if (mimetype != "application/pdf") {
        this.warn("Received unsupported print data mimetype: " + mimetype);
        return;
    }
    this.log("got " + data.length + " bytes of PDF to print");

    var file = new Blob([data], { type: 'application/pdf' });
    var fileURL = URL.createObjectURL(file);
    const win = window.open(fileURL);

    if (!win || win.closed || typeof win.closed == 'undefined') {
        this.warn("popup blocked, saving to file instead");
        Utilities.saveFile(filename, data, { type: mimetype });
    } else {
        win.print();
    }
};