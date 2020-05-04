# GPU-accelerated streaming with WebRTC and Gstreamer

## Description

Provides GPU accelerated WebRTC streaming and Xpra VDI support to Selkies.

## Dependencies

- App Launcher: v1.0.0+

## Features

- Full desktop streaming with WebRTC (requires GPU).
- Hybrid streaming with Xpra (no GPU required).
- App streaming with WebRTC.
- GPU sharing, multiple users per node sharing the same GPU.
- Persistent home directories with VolumeClaimTemplates and dynamic resizing.
- Manual bitrate selection, configurable in real-time.
- Manual frame rate selection.
- Resolution up to 2560x1600.
- Audio support.
- Mouse lock support.
- Fullscreen support.
- Clipboard support.
- Gamepad support.
- Stream recording to GCS.
- Idle detection and automatic shutdown.

## Quick start

1. Set the project, replace `YOUR_PROJECT` with your project ID:

```bash
export PROJECT_ID=YOUR_PROJECT
```

```bash
gcloud config set project ${PROJECT_ID?}
```

2. Set the target region:

```bash
REGION=us-west1
```

> NOTE: change this to the region of your cluster.

## Pre-requisites

This tutorial requires that you have already deployed the Kubernetes App Launcher Operator in your GKE cluster.

If you have not already deployed the operator, follow this Cloud Shell tutorial to do so:

[![Open in Cloud Shell](https://gstatic.com/cloudssh/images/open-btn.svg)](https://ssh.cloud.google.com/cloudshell/editor?cloudshell_git_repo=https://github.com/GoogleCloudPlatform/solutions-k8s-stateful-workload-operator&cloudshell_git_branch=v1.0.0&cloudshell_tutorial=setup/README.md)

## Platform verification

1. Verify that the gpu-cos node pool has been created:

```bash
gcloud container node-pools list --cluster broker-${REGION?} --region ${REGION?} --filter name~gpu-cos
```

> If no node-pool is listed, return to the App Launcher tutorial and re-run the infrastructure section with the gpu node pool enabled.

## Deploy infrastructure and manifests

1. Build build-images and install infrastructure:

```bash
gcloud builds submit --substitutions=_REGION=${REGION}
```

## Deploy sample app

1. Deploy the XFCE Desktop example with Cloud Build:

```bash
(cd examples/xfce-desktop && \
    gcloud builds submit --substitutions=_REGION=${REGION})
```

2. Open the App Launcher and launch the XFCE Desktop app.

> NOTE: the first launch may take several minutes to run as the images are pulled for the first time.

> NOTE: If the node pool has zero nodes, then it will take an additional 10 minutes to add a new node and pull the images.