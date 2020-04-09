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

/*global GamepadManager, Input*/

/*eslint no-unused-vars: ["error", { "vars": "local" }]*/

/**
 * @typedef {Object} WebRTCDemo
 * @property {function} ondebug - Callback fired when new debug message is set.
 * @property {function} onstatus - Callback fired when new status message is set.
 * @property {function} onerror - Callback fired when new error message is set.
 * @property {function} onconnectionstatechange - Callback fired when peer connection state changes.
 * @property {function} ondatachannelclose - Callback fired when data channel is closed.
 * @property {function} ondatachannelopen - Callback fired when data channel is opened.
 * @property {function} onplayvideorequired - Callback fired when user interaction is required before playing video.
 * @property {function} onclipboardcontent - Callback fired when clipboard content from the remote host is received.
 * @property {function} getConnectionStats - Returns promise that resolves with connection stats.
 * @property {Objet} rtcPeerConfig - RTC configuration containing ICE servers and other connection properties.
 * @property {boolean} forceTurn - Force use of TURN server.
 * @property {fucntion} sendDataChannelMessage - Send a message to the peer though the data channel.
 */
class WebRTCDemo {
    /**
     * Interface to WebRTC demo.
     *
     * @constructor
     * @param {WebRTCDemoSignalling} [signalling]
     *    Instance of WebRTCDemoSignalling used to communicate with signalling server.
     * @param {Element} [element]
     *    video element to attach stream to.
     */
    constructor(signalling, element) {
        /**
         * @type {WebRTCDemoSignalling}
         */
        this.signalling = signalling;

        /**
         * @type {Element}
         */
        this.element = element;

        /**
         * @type {boolean}
         */
        this.forceTurn = false;

        /**
         * @type {Object}
         */
        this.rtcPeerConfig = {
            "lifetimeDuration": "86400s",
            "iceServers": [
                {
                    "urls": [
                        "stun:stun.l.google.com:19302"
                    ]
                },
            ],
            "blockStatus": "NOT_BLOCKED",
            "iceTransportPolicy": "all"
        };

        /**
         * @type {RTCPeerConnection}
         */
        this.peerConnection = null;

        /**
         * @type {function}
         */
        this.onstatus = null;

        /**
         * @type {function}
         */
        this.ondebug = null;

        /**
         * @type {function}
         */
        this.onerror = null;

        /**
         * @type {function}
         */
        this.onconnectionstatechange = null;

        /**
         * @type {function}
         */
        this.ondatachannelopen = null;

        /**
         * @type {function}
         */
        this.ondatachannelclose = null;

        /**
         * @type {function}
         */
        this.ongpustats = null;

        /**
         * @type {function}
         */
        this.onplayvideorequired = null;

        /**
         * @type {function}
         */
        this.onclipboardcontent = null;

        /**
         * @type {function}
         */
        this.onsystemaction = null;

        // Bind signalling server callbacks.
        this.signalling.onsdp = this._onSDP.bind(this);
        this.signalling.onice = this._onSignallingICE.bind(this);

        /**
         * @type {boolean}
         */
        this._connected = false;

        /**
         * @type {RTCDataChannel}
         */
        this._send_channel = null;

        /**
         * @type {Input}
         */
        this.input = new Input(element, (data) => {
            if (this._connected) {
                this._setDebug("data channel: " + data);
                this._send_channel.send(data);
            }
        })
    }

    /**
     * Sets status message.
     *
     * @private
     * @param {String} message
     */
    _setStatus(message) {
        if (this.onstatus !== null) {
            this.onstatus(message);
        }
    }

    /**
     * Sets debug message.
     *
     * @private
     * @param {String} message
     */
    _setDebug(message) {
        if (this.ondebug !== null) {
            this.ondebug(message);
        }
    }

    /**
     * Sets error message.
     *
     * @private
     * @param {String} message
     */
    _setError(message) {
        if (this.onerror !== null) {
            this.onerror(message);
        }
    }

    /**
     * Sets connection state
     * @param {String} state
     */
    _setConnectionState(state) {
        if (this.onconnectionstatechange !== null) {
            this.onconnectionstatechange(state);
        }
    }

    /**
     * Handles incoming ICE candidate from signalling server.
     *
     * @param {RTCIceCandidate} icecandidate
     */
    _onSignallingICE(icecandidate) {
        this._setDebug("received ice candidate from signalling server: " + JSON.stringify(icecandidate));
        if (this.forceTurn && JSON.stringify(icecandidate).indexOf("relay") < 0) { // if no relay address is found, assuming it means no TURN server
            this._setDebug("Rejecting non-relay ICE candidate: " + JSON.stringify(icecandidate));
            return;
        }
        this.peerConnection.addIceCandidate(icecandidate).catch(this._setError);
    }

    /**
     * Handler for ICE candidate received from peer connection.
     * If ice is null, then all candidates have been received.
     *
     * @event
     * @param {RTCPeerConnectionIceEvent} event - The event: https://developer.mozilla.org/en-US/docs/Web/API/RTCPeerConnectionIceEvent
     */
    _onPeerICE(event) {
        if (event.candidate === null) {
            this._setStatus("Completed ICE candidates from peer connection");
            return;
        }
        this.signalling.sendICE(event.candidate);
    }

    /**
     * Handles incoming SDP from signalling server.
     * Sets the remote description on the peer connection,
     * creates an answer with a local description and sends that to the peer.
     *
     * @param {RTCSessionDescription} sdp
     */
    _onSDP(sdp) {
        if (sdp.type != "offer") {
            this._setError("received SDP was not type offer.");
            return
        }
        console.log("Received remote SDP", sdp);
        this.peerConnection.setRemoteDescription(sdp).then(() => {
            this._setDebug("received SDP offer, creating answer");
            this.peerConnection.createAnswer()
                .then((local_sdp) => {
                    console.log("Created local SDP", local_sdp);
                    this.peerConnection.setLocalDescription(local_sdp).then(() => {
                        this._setDebug("Sending SDP answer");
                        this.signalling.sendSDP(this.peerConnection.localDescription);
                    });
                }).catch(() => {
                    this._setError("Error creating local SDP");
                });
        })
    }

    /**
     * Handles local description creation from createAnswer.
     *
     * @param {RTCSessionDescription} local_sdp
     */
    _onLocalSDP(local_sdp) {
        this._setDebug("Created local SDP: " + JSON.stringify(local_sdp));
    }

    /**
     * Handles incoming track event from peer connection.
     *
     * @param {Event} event - Track event: https://developer.mozilla.org/en-US/docs/Web/API/RTCTrackEvent
     */
    _ontrack(event) {
        this._setStatus("Received incoming " + event.track.kind + " stream from peer");
        if (!this.streams) this.streams = [];
        this.streams.push([event.track.kind, event.streams]);
        if (event.track.kind === "video") {
            this.element.srcObject = event.streams[0];
            this.playVideo();
        }
    }

    /**
     * Handles incoming data channel events from the peer connection.
     *
     * @param {RTCdataChannelEvent} event
     */
    _onPeerdDataChannel(event) {
        this._setStatus("Peer data channel created: " + event.channel.label);

        // Bind the data channel event handlers.
        this._send_channel = event.channel;
        this._send_channel.onmessage = this._onPeerDataChannelMessage.bind(this);
        this._send_channel.onopen = () => {
            if (this.ondatachannelopen !== null)
                this.ondatachannelopen();
        }
        this._send_channel.onclose = () => {
            if (this.ondatachannelclose !== null)
                this.ondatachannelclose();
        }
    }

    /**
     * Handles messages from the peer data channel.
     *
     * @param {MessageEvent} event
     */
    _onPeerDataChannelMessage(event) {
        // Attempt to parse message as JSON
        var msg;
        try {
            msg = JSON.parse(event.data);
        } catch (e) {
            if (e instanceof SyntaxError) {
                this._setError("error parsing data channel message as JSON: " + event.data);
            } else {
                this._setError("failed to parse data channel message: " + event.data);
            }
            return;
        }

        this._setDebug("data channel message: " + event.data);

        if (msg.type === 'pipeline') {
            this._setStatus(msg.data.status);
        } else if (msg.type === 'gpu_stats') {
            if (this.ongpustats !== null) {
                this.ongpustats(msg.data);
            }
        } else if (msg.type === 'clipboard') {
            if (msg.data !== null) {
                var content = atob(msg.data.content);
                this._setDebug("received clipboard contents, length: " + content.length);

                if (this.onclipboardcontent !== null) {
                    this.onclipboardcontent(content);
                }
            }
        } else if (msg.type === 'system') {
            if (msg.action !== null) {
                this._setDebug("received system msg, action: " + msg.data.action);
                var action = msg.data.action;
                if (this.onsystemaction !== null) {
                    this.onsystemaction(action);
                }
            }
        } else {
            this._setError("Unhandled message recevied: " + msg.type);
        }
    }

    /**
     * Handler for peer connection state change.
     * Possible values for state:
     *   connected
     *   disconnected
     *   failed
     *   closed
     * @param {String} state
     */
    _handleConnectionStateChange(state) {
        switch (state) {
            case "connected":
                this._setStatus("Connection complete");
                this._connected = true;
                break;

            case "disconnected":
                this._setError("Peer connection disconnected");
                this.element.load();
                break;

            case "failed":
                this._setError("Peer connection failed");
                this.element.load();
                break;
            default:
        }
    }

    /**
     * Sends message to peer data channel.
     *
     * @param {String} message
     */
    sendDataChannelMessage(message) {
        if (this._send_channel.readyState === 'open') {
            this._send_channel.send(message);
        } else {
            this._setError("attempt to send data channel message before channel was open.");
        }
    }

    /**
     * Handler for gamepad disconnect message.
     *
     * @param {number} gp_num - the gamepad number
     */
    onGamepadDisconnect(gp_num) {
        this._setStatus("gamepad: " + gp_num + ", disconnected");
    }

    /**
     * Returns promise that resolves with connection stats.
     */
    getConnectionStats() {
        var pc = this.peerConnection;

        var connectionDetails = {};   // the final result object.

        if (window.chrome) {  // checking if chrome

            var reqFields = [
                'googLocalCandidateType',
                'googRemoteCandidateType',
                'packetsReceived',
                'packetsLost',
                'bytesReceived',
                'googFrameRateReceived',
                'googFrameRateOutput',
                'googCurrentDelayMs',
                'googFrameHeightReceived',
                'googFrameWidthReceived',
                'codecImplementationName',
                'googCodecName',
                'googAvailableReceiveBandwidth'
            ];

            return new Promise(function (resolve, reject) {
                pc.getStats(function (stats) {
                    var filteredVideo = stats.result().filter(function (e) {
                        if ((e.id.indexOf('Conn-video') === 0 && e.stat('googActiveConnection') === 'true') ||
                            (e.id.indexOf('ssrc_') === 0 && e.stat('mediaType') === 'video') ||
                            (e.id == 'bweforvideo')) return true;
                    });
                    if (!filteredVideo) return reject('Something is wrong...');
                    filteredVideo.forEach((f) => {
                        reqFields.forEach((e) => {
                            var statValue = f.stat(e);
                            if (statValue != "") {
                                connectionDetails['video' + e.replace('goog', '')] = statValue;
                            }
                        });
                    });
                    var filteredAudio = stats.result().filter(function (e) {
                        if ((e.id.indexOf('Conn-audio') === 0 && e.stat('googActiveConnection') === 'true') ||
                            (e.id.indexOf('ssrc_') === 0 && e.stat('mediaType') === 'audio') ||
                            (e.id == 'bweforaudio')) return true;
                    });
                    if (!filteredAudio) return reject('Something is wrong...');
                    filteredAudio.forEach((f) => {
                        reqFields.forEach((e) => {
                            var statValue = f.stat(e);
                            if (statValue != "") {
                                connectionDetails['audio' + e.replace('goog', '')] = statValue;
                            }
                        });
                    });
                    resolve(connectionDetails);
                });
            });

        } else {
            this._setError("unable to fetch connection stats for brower, only Chrome is supported.");
        }
    }

    /**
     * Starts playing the video stream.
     * Note that this must be called after some DOM interaction has already occured.
     * Chrome does not allow auto playing of videos without first having a DOM interaction.
     */
    // [START playVideo]
    playVideo() {
        this.element.load();

        var playPromise = this.element.play();
        if (playPromise !== undefined) {
            playPromise.then(() => {
                this._setDebug("Video stream is playing.");
            }).catch(() => {
                if (this.onplayvideorequired !== null) {
                    this.onplayvideorequired();
                } else {
                    this._setDebug("Video play failed and no onplayvideorequired was bound.");
                }
            });
        }
    }
    // [END playVideo]

    /**
     * Initiate connection to signalling server.
     */
    connect() {
        // Create the peer connection object and bind callbacks.
        this.peerConnection = new RTCPeerConnection(this.rtcPeerConfig);
        this.peerConnection.ontrack = this._ontrack.bind(this);
        this.peerConnection.onicecandidate = this._onPeerICE.bind(this);
        this.peerConnection.ondatachannel = this._onPeerdDataChannel.bind(this);

        this.peerConnection.onconnectionstatechange = () => {
            // Local event handling.
            this._handleConnectionStateChange(this.peerConnection.connectionState);

            // Pass state to event listeners.
            this._setConnectionState(this.peerConnection.connectionState);
        };

        if (this.forceTurn) {
            this._setStatus("forcing use of TURN server");
            var config = this.peerConnection.getConfiguration();
            config.iceTransportPolicy = "relay";
            this.peerConnection.setConfiguration(config);
        }
        this.signalling.connect();
    }

    capture_setup() {
        this.capture_canvas = document.getElementById("capture");
        this.capture_context = this.capture_canvas.getContext('2d');
        this.capture_canvas.width = this.input.m.frameW;
        this.capture_canvas.height = this.input.m.frameH;
    }

    capture() {
        this.capture_context.drawImage(this.element, 0, 0, this.capture_canvas.width, this.capture_canvas.height);
        var contextImageData = this.capture_context.getImageData(
            0,
            this.capture_canvas.height * 0.99,
            this.capture_canvas.width * 0.01,
            this.capture_canvas.height * 0.01,
        );
        return contextImageData.data;
    }

    send_escape_key() {
        this.sendDataChannelMessage("kd,65307");
        this.sendDataChannelMessage("ku,65307");
    }

    async sleep(milliseconds) {
        await new Promise((resolve, reject) => {
            setTimeout(() => {
                resolve();
            }, milliseconds);
        });
    }

    async fun() {
        this.capture_setup();
        this.have_fun = true;
        while (this.have_fun) {
            console.log('Capturing...');
            this.send_escape_key();
            const average_frame_brightnesses = [];
            const frame_durations = [];
            for (let frame_index = 0; frame_index < 20; frame_index++) {
                const frame_start = Date.now();
                const image_data = this.capture();
                const pixel_brightnesses = [];
                for (let pixel_index = 0; pixel_index < image_data.length / 4; pixel_index += 1) {
                    const r = image_data[pixel_index * 4 + 0];
                    const g = image_data[pixel_index * 4 + 1];
                    const b = image_data[pixel_index * 4 + 2];
                    const pixel_brightness = (r + g + b) / (255 * 3);
                    pixel_brightnesses.push(pixel_brightness);
                }
                const total_pixel_brightness = pixel_brightnesses.reduce((a, b) => a + b, 0);
                const average_pixel_brightness = total_pixel_brightness / pixel_brightnesses.length;
                average_frame_brightnesses.push(average_pixel_brightness);
                const frame_end = Date.now();
                frame_durations.push(frame_end - frame_start);
            }
            console.log('Average frame brightnesses over time (bottom-left 1% of screen):', average_frame_brightnesses.map(x => Math.round(100 * x)));
            const average_frame_durations = frame_durations.reduce((a, b) => a + b, 0) / frame_durations.length;
            console.log('Average milliseconds between capture frames:', Math.round(average_frame_durations));
            await this.sleep(1000);
        }
    }
}