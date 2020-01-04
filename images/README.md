# Images

Images used by the deployment.

To build all images:

```bash
gcloud builds submit
```

## Image descriptions

### app-streaming

Minimal container for streaming applications. Should work for most accelerated workloads.

Includes support for:

- GLX
- EGL
- Vulkan
- Pulseaudio

To use this image, set the `EXEC_CMD` environment variable to your entrypoint.

Example Dockerfile:

```
FROM gcr.io/cloud-solutions-images/gpu-accel-webrtc-app-streaming:latest

ADD q2rtx-1.1.0.tar.gz /opt/app/

WORKDIR /opt/app/q2rtx

ENV EXEC_CMD /opt/app/q2rtx/q2rtx.sh
```

### chromoting

[Chrome Remote Destkop headless](https://remotedesktop.google.com/headless) build with patch to connect to existing X11 session and pulse audio stream.

Connects to X server using shared X11 socket runnnig in the xserver pod container.

Uses pamon to stream audio from TCP pulseaudio server running in desktop container to FIFO that Chrome Remote Desktop process streams from.

## coturn

STUN/TURN server powered by OSS [coturn](https://github.com/coturn/coturn/wiki/turnserver) and custom golang based RTC config JSON generator service.

Intended for deployment to separate node pool, requires hostNetworking on the pod.

### desktop

Full desktop environment image that user works in with all graphics libraries installed.

Connects to X server using shared X11 socket running in xserver pod container.

### gst-base

Gstreamer base image with Gstreamer and plugins built from [source tree](https://gitlab.freedesktop.org/gstreamer).

### gst-webrtc-app

Gstreamer WebRTC app image with gst-base as base image.

Runs hardware accelerated [NvEnc encoder](https://gitlab.freedesktop.org/gstreamer/gst-plugins-bad/tree/master/sys/nvenc) and pipeline to stream X11 with [WebRTC](https://gstreamer.freedesktop.org/data/doc/gstreamer/head/gst-plugins-bad-plugins/html/gst-plugins-bad-plugins-webrtcbin.html).

### gst-web

Web interface for WebRTC streaming demo.

### novnc

NoVNC container for comparing with other technologies like WebRTC and Chromoting.

Connects to X11VNC process running in the xserver container over port 5901, provides websocket and web interface.

### webrtc-signalling

[Singalling service](https://github.com/centricular/gstwebrtc-demos/tree/master/signalling) for WebRTC pipeline.

### xserver

Image for container running xorg server with fully configured NVIDIA drivers. Shares the X11 socket with the rest of the pod.