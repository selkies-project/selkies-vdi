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

/**
 * Fetch the value of a cookie by name.
 * @param {string} a
 */
function getCookieValue(a) {
    // https://stackoverflow.com/questions/5639346/what-is-the-shortest-function-for-reading-a-cookie-by-name-in-javascript
    var b = document.cookie.match('(^|[^;]+)\\s*' + a + '\\s*=\\s*([^;]+)');
    return b ? b.pop() : '';
}

var ScaleLoader = VueSpinner.ScaleLoader;

var app = new Vue({

    el: '#app',

    components: {
        ScaleLoader
    },

    data() {
        return {
            appName: window.location.pathname.split("/")[1] || "webrtc",
            videoBitRate: (parseInt(window.localStorage.getItem("videoBitRate")) || 2000),
            videoBitRateOptions: [
                { text: '500 kb/s', value: 500 },
                { text: '1 mbps', value: 1000 },
                { text: '2 mbps', value: 2000 },
                { text: '3 mbps', value: 3000 },
                { text: '4 mbps', value: 4000 },
                { text: '8 mbps', value: 8000 },
                { text: '20 mbps', value: 20000 },
                { text: '100 mbps', value: 100000 },
                { text: '150 mbps', value: 150000 },
                { text: '200 mbps', value: 200000 },
            ],
            videoFramerate: (parseInt(window.localStorage.getItem("videoFramerate")) || 30),
            videoFramerateOptions: [
                { text: '15 fps', value: 15 },
                { text: '30 fps', value: 30 },
                { text: '60 fps', value: 60 },
                { text: '100 fps', value: 100 },
            ],
            audioBitRate: (parseInt(window.localStorage.getItem("audioBitRate")) || 32000),
            audioBitRateOptions: [
                { text: '32 kb/s', value: 32000 },
                { text: '64 kb/s', value: 64000 },
                { text: '128 kb/s', value: 128000 },
                { text: '256 kb/s', value: 256000 },
                { text: '320 kb/s', value: 320000 },
            ],
            showStart: false,
            showDrawer: false,
            logEntries: [],
            debugEntries: [],
            status: 'connecting',
            loadingText: '',
            clipboardStatus: 'disabled',
            gamepadState: 'disconnected',
            gamepadName: 'none',
            audioEnabled: null,
            windowResolution: "",
            connectionStatType: "unknown",
            connectionLatency: 0,
            connectionVideoLatency: 0,
            connectionAudioLatency: 0,
            connectionAudioCodecName: "unknown",
            connectionAudioBitrate: 0,
            connectionPacketsReceived: 0,
            connectionPacketsLost: 0,
            connectionCodec: "unknown",
            connectionVideoDecoder: "unknown",
            connectionResolution: "",
            connectionFrameRate: 0,
            connectionVideoBitrate: 0,
            connectionAvailableBandwidth: 0,
            gpuLoad: 0,
            gpuMemoryTotal: 0,
            gpuMemoryUsed: 0,
            debug: (window.localStorage.getItem("debug") === "true"),
            turnSwitch: (window.localStorage.getItem("turnSwitch") === "true"),
            publishingAllowed: false,
            publishingIdle: false,
            publishingError: "",
            publishingAppName: "",
            publishingAppDisplayName: "",
            publishingAppDescription: "",
            publishingAppIcon: "",
            publishingValid: false,
            rules: {
                required: value => {
                    if (!value || value.length == 0)
                        return 'required.';
                    return true;
                },

                validname: value => {
                    if (value.length > 63) {
                        return 'must be less than 63 characters.';
                    }
                    if (!new RegExp('^[a-z0-9]([-a-z0-9]*[a-z0-9])?(\.[a-z0-9]([-a-z0-9]*[a-z0-9])?)*$').exec(value)) {
                        return 'invalid name'
                    }
                    if (value === this.appName) {
                        return 'must be different than current name'
                    }
                    return true;
                },
            }
        }
    },

    methods: {
        getUsername: () => {
            if (app === undefined) return "webrtc";
            return (getCookieValue("broker_" + app.appName) || "webrtc").split("#")[0];
        },
        enterFullscreen() {
            // Request full screen mode.
            webrtc.element.parentElement.requestFullscreen();
        },
        playVideo() {
            webrtc.playVideo();
            this.showStart = false;
        },
        enableClipboard() {
            navigator.clipboard.readText()
                .then(text => {
                    webrtc._setStatus("clipboard enabled");
                    webrtc.sendDataChannelMessage("cr");
                })
                .catch(err => {
                    webrtc._setError('Failed to read clipboard contents: ' + err);
                });
        },
        publish() {
            var data = {
                name: this.publishingAppName,
                displayName: this.publishingAppDisplayName,
                description: this.publishingAppDescription,
                icon: this.publishingAppIcon,
            }
            console.log("Publishing new image", data);

            fetch("/publish/" + app.appName, {
                method: "POST",
                headers: {
                    "content-type": "application/json"
                },
                body: JSON.stringify(data),
            })
                .then(function (response) {
                    return response.json();
                })
                .then((response) => {
                    if (response.code === 201) {
                        this.publishingIdle = false;
                        checkPublishing();
                    } else {
                        this.publishingError = response.status;
                    }
                });
        }
    },

    watch: {
        videoBitRate(newValue) {
            webrtc.sendDataChannelMessage('vb,' + newValue);
            window.localStorage.setItem("videoBitRate", newValue.toString());
        },
        videoFramerate(newValue) {
            console.log("video frame rate changed to " + newValue);
            webrtc.sendDataChannelMessage('_arg_fps,' + newValue);
            window.localStorage.setItem("videoFramerate", newValue.toString());
        },
        audioEnabled(newValue, oldValue) {
            console.log("audio enabled changed from " + oldValue + " to " + newValue);
            if (oldValue !== null && newValue !== oldValue) webrtc.sendDataChannelMessage('_arg_audio,' + newValue);
        },
        audioBitRate(newValue) {
            webrtc.sendDataChannelMessage('ab,' + newValue);
            window.localStorage.setItem("audioBitRate", newValue.toString());
        },
        turnSwitch(newValue) {
            window.localStorage.setItem("turnSwitch", newValue.toString());
            // Reload the page to force read of stored value on first load.
            setTimeout(() => {
                document.location.reload();
            }, 700);
        },
        debug(newValue) {
            window.localStorage.setItem("debug", newValue.toString());
            // Reload the page to force read of stored value on first load.
            setTimeout(() => {
                document.location.reload();
            }, 700);
        },
        appName(newValue) {
            document.title = "WebRTC - " + newValue;
        },
        showDrawer(newValue) {
            // Detach inputs when menu is shown.
            if (newValue === true) {
                webrtc.input.detach();
            } else {
                webrtc.input.attach();
            }
        },
    },

    updated: () => {
        document.title = "WebRTC - " + app.appName;
    },

});

var videoElement = document.getElementById("stream");

// WebRTC entrypoint, connect to the signalling server
/*global WebRTCDemoSignalling, WebRTCDemo*/
var signalling = new WebRTCDemoSignalling(new URL("wss://" + window.location.host + "/" + app.appName + "/signalling/"), 1);
var webrtc = new WebRTCDemo(signalling, videoElement);

// Function to add timestamp to logs.
var applyTimestamp = (msg) => {
    var now = new Date();
    var ts = now.getHours() + ":" + now.getMinutes() + ":" + now.getSeconds();
    return "[" + ts + "]" + " " + msg;
}

// Send signalling status and error messages to logs.
signalling.onstatus = (message) => {
    app.loadingText = message;
    app.logEntries.push(applyTimestamp("[signalling] " + message));
};
signalling.onerror = (message) => { app.logEntries.push(applyTimestamp("[signalling] [ERROR] " + message)) };

// Send webrtc status and error messages to logs.
webrtc.onstatus = (message) => { app.logEntries.push(applyTimestamp("[webrtc] " + message)) };
webrtc.onerror = (message) => { app.logEntries.push(applyTimestamp("[webrtc] [ERROR] " + message)) };

if (app.debug) {
    signalling.ondebug = (message) => { app.debugEntries.push("[signalling] " + message); };
    webrtc.ondebug = (message) => { app.debugEntries.push(applyTimestamp("[webrtc] " + message)) };
}

webrtc.ongpustats = (data) => {
    app.gpuLoad = Math.round(data.load * 100);
    app.gpuMemoryTotal = data.memory_total;
    app.gpuMemoryUsed = data.memory_used;
}

// Bind vue status to connection state.
webrtc.onconnectionstatechange = (state) => {
    app.status = state;

    if (state === "connected") {
        // Start watching stats.
        var bytesReceivedStart = 0;
        var audiobytesReceivedStart = 0;
        var statsStart = new Date().getTime() / 1000;
        var statsLoop = () => {
            webrtc.getConnectionStats().then((stats) => {
                //app.audioEnabled = (app.state === 'connected' && stats.audioCodecName) ? true : false;
                if (app.audioEnabled) {
                    app.connectionAudioLatency = parseInt(stats.audioCurrentDelayMs);
                    app.connectionAudioCodecName = stats.audioCodecName;
                    app.connectionLatency = Math.max(app.connectionAudioLatency, app.connectionVideoLatency);
                } else {
                    stats.audiobytesReceived = 0;
                    app.connectionLatency = app.connectionVideoLatency;
                }
                app.connectionStatType = stats.videoLocalCandidateType;
                app.connectionVideoLatency = parseInt(stats.videoCurrentDelayMs);
                app.connectionPacketsReceived = parseInt(stats.videopacketsReceived);
                app.connectionPacketsLost = parseInt(stats.videopacketsLost);
                app.connectionCodec = stats.videoCodecName;
                app.connectionVideoDecoder = stats.videocodecImplementationName;
                app.connectionResolution = stats.videoFrameWidthReceived + "x" + stats.videoFrameHeightReceived;
                app.connectionFrameRate = stats.videoFrameRateOutput;
                app.connectionAvailableBandwidth = (parseInt(stats.videoAvailableReceiveBandwidth) / 1e+6).toFixed(2) + " mbps";

                // Compute current video bitrate in mbps
                var now = new Date().getTime() / 1000;
                app.connectionVideoBitrate = (((parseInt(stats.videobytesReceived) - bytesReceivedStart) / (now - statsStart)) * 8 / 1e+6).toFixed(2);
                bytesReceivedStart = parseInt(stats.videobytesReceived);

                // Compute current audio bitrate in kbps
                if (app.audioEnabled) {
                    app.connectionAudioBitrate = (((parseInt(stats.audiobytesReceived) - audiobytesReceivedStart) / (now - statsStart)) * 8 / 1e+3).toFixed(2);
                    audiobytesReceivedStart = parseInt(stats.audiobytesReceived);
                }

                statsStart = now;

                // Stats refresh loop.
                setTimeout(statsLoop, 1000);
            });
        };
        statsLoop();
    }
};

webrtc.ondatachannelopen = () => {
    var video_bit_rate = app.videoBitRate || (parseInt(window.localStorage.getItem("videoBitRate")) || 2000)
    console.log("Setting initial video bit rate to: " + video_bit_rate);
    try {
        webrtc.sendDataChannelMessage('vb,' + video_bit_rate);
    } catch (e) {
        console.log("Failed to set bit rate: ", e);
    }

    var audio_bit_rate = app.audioBitRate || (parseInt(window.localStorage.getItem("audioBitRate")) || 64000)
    console.log("Setting initial audio bit rate to: " + audio_bit_rate);
    try {
        webrtc.sendDataChannelMessage('ab,' + audio_bit_rate);
    } catch (e) {
        console.log("Failed to set audio bit rate: ", e);
    }

    webrtc.input.ongamepadconnected = (gamepad_id) => {
        app.gamepadState = "connected";
        app.gamepadName = gamepad_id;
    }

    webrtc.input.ongamepaddisconnected = () => {
        app.gamepadState = "disconnected";
        app.gamepadName = "none";
    }

    webrtc.input.attach();

    // Send client-side metrics over data channel every 5 seconds
    setInterval(() => {
        webrtc.sendDataChannelMessage('_f,' + app.connectionFrameRate);
        webrtc.sendDataChannelMessage('_l,' + app.connectionLatency);
    }, 5000)
}

webrtc.ondatachannelclose = () => {
    webrtc.input.detach();
}

webrtc.input.onmenuhotkey = () => {
    app.showDrawer = !app.showDrawer;
}

webrtc.input.onfullscreenhotkey = () => {
    app.enterFullscreen();
}

webrtc.input.onresizeend = () => {
    app.windowResolution = webrtc.input.getWindowResolution();
    console.log(`Window size changed: ${app.windowResolution[0]}x${app.windowResolution[1]}`);
}

webrtc.onplayvideorequired = () => {
    app.showStart = true;
}

// Actions to take whenever window changes focus
window.addEventListener('focus', () => {
    // reset keyboard to avoid stuck keys.
    webrtc.sendDataChannelMessage("kr");

    // Send clipboard contents.
    navigator.clipboard.readText()
        .then(text => {
            webrtc.sendDataChannelMessage("cw," + btoa(text))
        })
        .catch(err => {
            webrtc._setStatus('Failed to read clipboard contents: ' + err);
        });
});
window.addEventListener('blur', () => {
    // reset keyboard to avoid stuck keys.
    webrtc.sendDataChannelMessage("kr");
});

webrtc.onclipboardcontent = (content) => {
    if (app.clipboardStatus === 'enabled') {
        navigator.clipboard.writeText(content)
            .catch(err => {
                app._setDebug('Could not copy text to clipboard: ' + err);
            });
    }
}

webrtc.onsystemaction = (action) => {
    webrtc._setStatus("Executing system action: " + action);
    if (action === 'reload') {
        setTimeout(() => {
            document.location.reload();
        }, 700);
    } else if (action.startsWith('framerate')) {
        app.videoFramerate = parseInt(action.split(",")[1]);
    } else if (action.startsWith('audio')) {
        app.audioEnabled = (action.split(",")[1].toLowerCase() === 'true');
    } else {
        webrtc._setStatus('Unhandled system action: ' + action);
    }
}

navigator.permissions.query({
    name: 'clipboard-read'
}).then(permissionStatus => {
    // Will be 'granted', 'denied' or 'prompt':
    if (permissionStatus.state === 'granted') {
        app.clipboardStatus = 'enabled';
    }

    // Listen for changes to the permission state
    permissionStatus.onchange = () => {
        if (permissionStatus.state === 'granted') {
            app.clipboardStatus = 'enabled';
        }
    };
});

// Check if editing is allowed.
var checkPublishing = () => {
    fetch("/publish/" + app.appName)
        .then((response) => {
            return response.json();
        })
        .then((response) => {
            if (response.code < 400) {
                app.publishingAllowed = true;
                app.publishingIdle = true;
            }
            if (response.code === 201) {
                app.publishingIdle = false;
                setTimeout(() => {
                    checkPublishing();
                }, 1000);
            }
        });
}
checkPublishing();

// Fetch RTC configuration containing STUN/TURN servers.
fetch("/turn/")
    .then(function (response) {
        return response.json();
    })
    .then((config) => {
        // for debugging, force use of relay server.
        webrtc.forceTurn = app.turnSwitch;

        // get initial local resolution
        app.windowResolution = webrtc.input.getWindowResolution();

        app.debugEntries.push(applyTimestamp("[app] using TURN servers: " + config.iceServers[1].urls.join(", ")));
        webrtc.rtcPeerConfig = config;
        webrtc.connect();
    });