## Deploying the VDI App Bundle

This is part of a multi-part tutorial series and assumes you have run the **Setup** section already:

- `teachme tutorials/gke/00_Setup.md`

This tutorial will walk you through the following:

- Deploy the WebRTC streaming stack base manifests.
- Deploy example XFCE desktop streaming app.

## (Option 1) Deploy manifests manually

1. Deploy manifests using cloud build:

```bash
cd ~/webrtc-gpu-streaming/kubernetes/manifests
```

```bash
gcloud builds submit --substitutions=_REGION=us-west1
```

> NOTE: change the value of _REGION to target a different region.

## (Option 2) Deploy manifests GitOps pipeline

1. Run script to configure GitOps pipeline for base manifests with Cloud Source Repositories and Cloud Build:

```bash
cd ~/webrtc-gpu-streaming/kubernetes/manifests
```

```bash
./webrtc-gpu-streaming-base-gitops-init.sh
```

2. Wait for cloud build to complete.

## Verfiy deployment

1. Wait for the nvidia-driver-installer pod to complete:

```bash
kubectl -n kube-system wait pod -l k8s-app=nvidia-driver-installer --for=condition=Ready --timeout=600s
```

2. Wait for the gpu-node-init pod to complete:

```bash
kubectl -n kube-system wait pod -l app=gpu-node-init --for=condition=Ready --timeout=600s
```

3. Wait for the gpu-sharing pod to complete:

```bash
kubectl -n kube-system wait pod -l app=gpu-sharing --for=condition=Ready --timeout=600s
```

4. Verify that GPU sharing is enabled:

```bash
kubectl describe node -l cloud.google.com/gke-accelerator-initialized=true | grep nvidia.com/gpu
```

Example output:

```
 nvidia.com/gpu:             48
 nvidia.com/gpu:             48
```

> Verify that the number of availble GPUs is greater than 1.

## (Option 1) Deploy the XFCE Desktop app manually

1. Deploy manifests using cloud build:

```bash
cd ~/webrtc-gpu-streaming/kubernetes/examples/xfce-desktop
```

```bash
gcloud builds submit --substitutions=_REGION=us-west1
```

> NOTE: change the value of _REGION to target a different region.

## (Option 2) Deploy the XFCE Desktop app GitOps pipeline

1. Run script to configure GitOps pipeline for XFCE Desktop with Cloud Source Repositories and Cloud Build:

```bash
cd ~/webrtc-gpu-streaming/kubernetes/examples/xfce-desktop
```

```bash
./xfce-desktop-gitops-init.sh
```

2. Wait for cloud build to complete.

## Verify example app deployment

1. Verify that the initial image pull on the GPU nodes has completed:

```bash
POD=$(kubectl -n default get pod -l app=pod-broker-image-puller -o name | tail -1)
```

```bash
kubectl logs ${POD}
```

> Verify the following images were pulled:

```
gcr.io/PROJECT_ID/webrtc-gpu-streaming-desktop:latest
gcr.io/PROJECT_ID/webrtc-gpu-streaming-pulseaudio:latest
gcr.io/PROJECT_ID/webrtc-gpu-streaming-signaling:latest
gcr.io/PROJECT_ID/webrtc-gpu-streaming-novnc:latest
gcr.io/PROJECT_ID/webrtc-gpu-streaming-xserver:latest
gcr.io/PROJECT_ID/webrtc-gpu-streaming-chromoting:latest
gcr.io/PROJECT_ID/webrtc-gpu-streaming-gst-web:latest
gcr.io/PROJECT_ID/webrtc-gpu-streaming-gst-webrtc-app:latest
```

## Connecting to the app

1. Open the App Launcher URL

2. Launch the XFCE Desktop app.
