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

### signaling

[Singaling service](https://github.com/centricular/gstwebrtc-demos/tree/master/signalling) for WebRTC pipeline.

### xpra

[Xpra](http://xpra.org/) image for hybrid streaming and CPU-only streaming.

### xserver

Image for container running xorg server with fully configured NVIDIA drivers. Shares the X11 socket with the rest of the pod.