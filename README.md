# VDI Addon for Selkies

[![Discord](https://img.shields.io/discord/798699922223398942?logo=discord)](https://discord.gg/wDNGDeSW5F)

## Description

Selkies addon for deploying VDI and app streaming workloads.

## Dependencies

- App Launcher: v1.0.0+

## Features

- Deploy apps as StatefulSet for persistence, or as Deployment, for always-ready ephemeral pods.
- Hybrid desktop environment with Xpra HTML5 client.
- Full desktop streaming at up to 15-20fps with WebRTC and software encoder.
- Full desktop streaming at 60+fps with WebRTC and NVIDIA GPU encoder.
- WebRTC TURN infrastructure provided by selkies-gstreamer repo.
- Individual app streaming with Xpra or WebRTC, software or hardware encoder.
- GPU sharing, multiple users per node sharing the same GPU.
- Persistent home directories with VolumeClaimTemplates and dynamic resizing.
- Shared storage with NFS, SMB and CephFS.
- Docker-in-Docker support.
- Audio support with WebRTC.
- Stream recording to GCS.
- Idle detection and automatic shutdown.
- Traffic filtering with NetworkPolicy or Squid sidecar.
- File manager sidecar with tinyfilemanager.
- Windows app supoprt with Proton.
- Secure TCP tunnel creation with the Selkies Connector.
- Per-application web preview ports 3000, 8000, and 8080.
- Custom host aliases
- Bind mounts from root filesystem to persistent home directory.

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

[![Open in Cloud Shell](https://gstatic.com/cloudssh/images/open-btn.svg)](https://ssh.cloud.google.com/cloudshell/editor?cloudshell_git_repo=https://github.com/selkies-project/selkies&cloudshell_git_branch=master&cloudshell_tutorial=setup/README.md)

## Platform verification

1. Verify that the gpu-cos node pool has been created:

```bash
gcloud container node-pools list --cluster broker-${REGION?} --region ${REGION?} --filter name~gpu-cos
```

> If no node-pool is listed, return to the App Launcher tutorial and re-run the infrastructure section with the gpu node pool enabled.

## Deploy infrastructure and manifests

1. Verify that submodules are up to date:

```bash
git submodule update --init --recursive
```

2. Build build-images and install infrastructure:

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
