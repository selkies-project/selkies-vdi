## WebRTC GPU Streaming on GKE

This is the initial setup tutorial in the multi-part series.

Other sections include: 

- `teachme tutorials/gke/01_Deploy.md

This tutorial will walk you through the following:

- Installing the pre-requisites
- Enabling project APIs.
- Building the images

## Pre-requisites

This tutorial requires that you have already deployed the Kubernetes App Launcher Operator in your GKE cluster.

Follow this Cloud Shell tutorial to do so:

[![Open in Cloud Shell](https://gstatic.com/cloudssh/images/open-btn.svg)](https://ssh.cloud.google.com/cloudshell/editor?cloudshell_git_repo=https%3A%2F%2Fsource.developers.google.com%2Fp%2Fcloud-ce-pso-shared-code%2Fr%2Fkube-app-launcher&cloudshell_git_branch=v1.0.0&cloudshell_tutorial=setup%2FREADME.md)

## Setup

1. Set the project, replace `YOUR_PROJECT` with your project ID:

```bash
PROJECT=YOUR_PROJECT
```

```bash
gcloud config set project ${PROJECT}
```

2. Enable Google APIs

```bash
gcloud services enable cloudbuild.googleapis.com
gcloud services enable servicemanagement.googleapis.com
gcloud services enable serviceusage.googleapis.com
gcloud services enable monitoring.googleapis.com
gcloud services enable container.googleapis.com
gcloud services enable compute.googleapis.com
```

## Build images

1. Build the images using Cloud Build:

```bash
cd ~/webrtc-gpu-streaming/images
```

```bash
gcloud builds submit
```

> NOTE: this step will take 15-20 minutes to complete.

## Whats next

Open the next Cloud Shell Tutorial: __Deploy manifests__:

```bash
cd ~/webrtc-gpu-streaming
```

```bash
teachme tutorials/gke/01_Deploy.md
```