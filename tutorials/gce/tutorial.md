## Streaming GPU-accelerated linux applications with GStreamer and WebRTC 

This tutorial shows how to deploy a virtual GPU-accelerated desktop environment for Linux using open source software. The WebRTC based streaming stack used in this tutorial can also be deployed to an existing instance with an attached NVIDIA GPU accelerator.

Example use cases:

- Drop-in browser-based WebRTC streaming solution for new or existing instances.
- Remote interactive visualization of large datasets for scientific and oil and gas industries.
- Accelerated game streaming to a web browser.
- Lightweight, low-cost virtual workstations for content creators such as VFX, animation, or design.

While there are many commercial remote access solutions designed for high performance Virtual Desktop Infrastructure (VDI) such as Teradici PC-over-IP (PCoIP), Citrix HDX, and Chrome Remote Desktop, this tutorial is focused only on free and open-source browser-based streaming that can be customized for your specific use case.

## Architecture overview

In this example, client browsers connect to an OAuth2 authenticated session through a Cloud Load Balancer. Request routing to web-based streaming components is done with [Traefik](https://traefik.io/), a flexible and HTTP aware router. The [signalling service](https://github.com/centricular/gstwebrtc-demos/tree/master/signalling) establishes a session between the [GStreamer](https://gstreamer.freedesktop.org/) application and the browser client and exchanges Interactive Connectivity Establishment ([ICE](https://tools.ietf.org/html/rfc5245)) candidates. The ICE candidates are Session Traversal Utilities for NAT ([STUN](https://tools.ietf.org/html/rfc5389)) and Traversal Using Relays around NAT ([TURN](https://tools.ietf.org/html/rfc5766)) servers provided by the coTURN service. After the ICE negotiation discovers a suitable network path, a peer-to-peer WebRTC connection is created, encrypted using Datagram Transport Layer Security ([DTLS](https://hpbn.co/webrtc/#secure-communication-with-dtls)). Traffic between the browser and the STUN/TURN server transports the encoded stream.

<img src="https://github.com/GoogleCloudPlatform/gpu-accel-webrtc/raw/master/tutorials/gce/diagram.png" width="800px"></img>

## Objectives

- Create an instance using pre-built image.
- Configure the instance for OAuth authentication.
- Connect to environment using Chrome web browser.
- Run GPU-accelerated demos.
- Connect a HTML5 compatible Gamepad and play SuperTuxKart.

## Costs

This tutorial uses the following billable resources:

- Compute Engine Instance
- GPU Accelerator

The total cost for running this tutorial for [2 hours is $4.80](https://cloud.google.com/products/calculator/#id=ba56bdfa-8b7a-4dff-af6f-0b64c94d9ecd).

## Before you begin

This tutorial assumes you already have a basic understanding of how WebRTC and GStreamer work. For context, see the resources listed below:

- [WebRTC](https://webrtc.org/)
- [GStreamer](https://gstreamer.freedesktop.org/) and the [webrtcbin plugin](https://gstreamer.freedesktop.org/data/doc/gstreamer/head/gst-plugins-bad-plugins/html/gst-plugins-bad-plugins-webrtcbin.html)
- [GStreamer WebRTC demos](https://github.com/centricular/gstwebrtc-demos)
- [NVIDIA NvENC](https://developer.nvidia.com/nvidia-video-codec-sdk)

[![button](http://gstatic.com/cloudssh/images/open-btn.png)](https://console.cloud.google.com/cloudshell/open?git_repo=https://source.developers.google.com/p/gke-accel-vdi/r/gce-accel-webrtc&working_dir=./&tutorial=tutorials/gce/tutorial.md)

## Set up your environment

1. If you did not click the Open in Cloud Shell button, clone the source repository:

```
cd $HOME && gcloud source repos clone gpu-accel-webrtc --project=gke-accel-vdi
```

2. Change to the `gce` subdirectory:

```bash
cd ${HOME}/gce-accel-webrtc/gce
```

3. Set the project, replace `YOUR_PROJECT` with your project ID:

```
gcloud config set project YOUR_PROJECT
```

4. Enable Google APIs:

```
gcloud services enable cloudbuild.googleapis.com
gcloud services enable compute.googleapis.com
gcloud services enable servicemanagement.googleapis.com
```

## Build the compute engine image

1. Use the provided `Makefile` to build the image with a desktop environment and the WebRTC containers in your project:

```bash
make
```

> NOTE: this will take 30-45 minutes to complete.

## Create firewall rules for instance

1. Create firewall rule for STUN/TURN server and web access:

```
gcloud compute firewall-rules create webrtc \
  --allow tcp:3478,udp:3478,udp:49152-50000 \
  --target-tags webrtc \
  --source-ranges 0.0.0.0/0
```

```
gcloud compute firewall-rules create webrtc-web \
  --allow tcp:443,tcp:80 \
  --target-tags webrtc \
  --source-ranges 0.0.0.0/0
```

## OAuth Task 1/3 - Configure OAuth consent screen

1. Go to the [OAuth consent screen](https://console.cloud.google.com/apis/credentials/consent).
2. Under __Application name__, enter `WebRTC Tutorial`.
3. Under __Support email__, select the email address you want to display as a public contact. This must be your email address, or a Google Group you own.
4. Under __Authorized Domains__, 

add the output of the following

```
PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
echo ${PROJECT_ID}.cloud.goog
```

Press __Enter__ in the box to add the entry.
5. Add any optional details you’d like.
6. Click __Save__.

## OAuth Task 2/3 - Create OAuth credentials

1. Go to the [Credentials page](https://console.cloud.google.com/apis/credentials)
2. Click __Create Credentials > OAuth client ID__,
3. Under __Application type__, select __Web application__. In the __Name__ box, enter `WebRTC Tutorial`, and in the __Authorized redirect URIs__ box, enter the URLs from the output below and then press __enter__ to add the entry to the list:

```
PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
echo "https://webrtc.endpoints.${PROJECT_ID}.cloud.goog/_oauth"
```

4. When you are finished, click __Create__. After your credentials are created, make note of the client ID and client secret that appear in the OAuth client window.

## OAuth Task 3/3 - Save credentials and create whitelist

1. In Cloud Shell, save your OAuth credentials obtained earlier to variables:

```bash
export CLIENT_ID=YOUR_CLIENT_ID
```

```bash
export CLIENT_SECRET=YOUR_CLIENT_SECRET
```

2. Create variable containing secret used for secure auth cookie:

```bash
export COOKIE_SECRET=$(openssl rand -base64 15)
```

3. Create a comma-separated whitelist of user emails allowed to connect, defaulting to your user:

```bash
export WHITELIST=$(gcloud config get-value account)
```

4. Create variable containing Let's Encrypt email address used to send renewal notices:

```bash
export ACME_EMAIL=$(gcloud config get-value account)
```

5. Save these values to a file for later reference:

```
cat | tee webrtc_env <<EOF
CLIENT_ID=${CLIENT_ID}
CLIENT_SECRET=${CLIENT_SECRET}
COOKIE_SECRET=${COOKIE_SECRET}
WHITELIST=${WHITELIST}
ACME_EMAIL=${ACME_EMAIL}
EOF
```

## Create instance using image

1. Use the provided helper script to choose a zone and accelerator type for your instance, this should be in a region closest to you to reduce latency:

```bash
eval $(${HOME}/gce-accel-webrtc/scripts/find_gpu.sh)
```

> NOTE: Make sure that you have [quota](https://console.cloud.google.com/iam-admin/quotas?project=_&service=compute.googleapis.com&metric=NVIDIA%20P100%20GPUs) for the accelerator type in the region you have chosen.

> NOTE: This command will automatically export the required variables, `REGION`, `ZONE`, and `ACCELERATOR_TYPE`, to your environment when completed, you can also set them manually.

2. In Cloud Shell, create a static IP used by the instance:

```bash
gcloud compute addresses create webrtc --region ${REGION}
```

3. Save the external IP to a variable:

```bash
EXTERNAL_IP=$(gcloud compute addresses describe webrtc --region ${REGION} --format='value(address)')
```

```bash
ENDPOINT="webrtc.endpoints.$(gcloud config get-value project 2>/dev/null).cloud.goog"
```

4. Create a Cloud Endpoint DNS record for your external IP:

```bash
${HOME}/gce-accel-webrtc/scripts/create_cloudep.sh webrtc ${EXTERNAL_IP}
```

5. Set the project for the source image:

```bash
IMAGE_PROJECT=$(gcloud config get-value project 2>/dev/null)
```

6. Add variables to saved environment file:

```
cat | tee -a webrtc_env <<EOF
REGION=${REGION}
ZONE=${ZONE}
ACCELERATOR_TYPE=${ACCELERATOR_TYPE}
IMAGE_PROJECT=${IMAGE_PROJECT}
EXTERNAL_IP=${EXTERNAL_IP}
ENDPOINT=${ENDPOINT}
EOF
```

7. Source the saved environment variables:

```bash
source webrtc_env
```

8. Create a GCE instance using the selected image and accelerator type:

```
gcloud compute instances create gpu-accel-webrtc \
  --machine-type=n1-standard-8 \
  --min-cpu-platform="Intel Skylake" \
  --zone=${ZONE?missing env} \
  --address=${EXTERNAL_IP?missing env} \
  --tags=webrtc \
  --accelerator=count=1,type=${ACCELERATOR_TYPE?missing env} \
  --maintenance-policy=TERMINATE \
  --boot-disk-type=pd-ssd \
  --boot-disk-size=50G \
  --image-project=${IMAGE_PROJECT?missing env} \
  --image-family=gpu-accel-webrtc \
  --metadata-from-file=startup-script=scripts/startup_script.sh \
  --metadata=\
oauth_client_id=${CLIENT_ID?missing env},\
oauth_client_secret=${CLIENT_SECRET?missing env},\
cookie_secret=${COOKIE_SECRET?missing env},\
whitelist=${WHITELIST?missing env},\
acme_email=${ACME_EMAIL?missing env},\
endpoint=${ENDPOINT?missing env}
```

> NOTE: The instance will take 1-2 minutes to boot. The startup-script will obtain a Let's Encrypt certificate and start the WebRTC components automatically.

## Connect to the web interface

1. Open the URL displayed in the command below in your browser:

```
echo "Open: https://webrtc.endpoints.$(gcloud config get-value project 2>/dev/null).cloud.goog/"
```

> After the web app connects, you should be able to see and interact with an XFCE desktop.

2. In the WebRTC demo web interface, open the Valley demo by clicking on the desktop icon.

## Connect Gamepad

1. Connect Gamepad to your local computer and press a button on the controller.

2. In the WebRTC web interface, verify that the gamepad icon in the top right of the WebRTC demo UI changes from grey to black. 

3. In the WebRTC streaming desktop session, open jstest-gtk under __Applications__ -> __System__->0 __jstest-gtk__

> The joystick should show up as __python-uinput__, click the __Refresh__ if the list is empty.

4. Select the python-uinput joystick then click the __Properties__ button, click the __Mapping__ button and the __Revert__ button to reset the mapping. 

## Play SuperTuxKart with Gamepad

[SuperTuxKart](https://supertuxkart.net/Main_Page) is a free and open-source 3D kart racing game with Linux and open source themed characters. 

1. Launch SuperTuxKart by clicking on the __Application_ menu -> __Games__ -> __SuperTuxKart__

2. From within the game settings, configure the graphics to the highest settings at 1080p 16:9 fullscreen resolution.

3. From the within the game settings, configure and controls to map the gamepad buttons.

4. Have fun!

## Cleanup

1. From Cloud shell, delete the instance:

```bash
PROJECT=$(gcloud config get-value project 2>/dev/null)
```

```bash
ZONE=us-west1-b
```

```bash
gcloud compute instances delete gpu-accel-webrtc --project ${PROJECT} --zone ${ZONE}
```

2. Delete the static IP:

```bash
REGION=us-west1
```

```bash
gcloud compute addresses delete webrtc --region ${REGION}
```

3. Delete the firewall rules:

```bash
gcloud compute firewall-rules delete webrtc webrtc-web
```

4. Go to the [Credentials](https://console.cloud.google.com/apis/credentials) page and delete the __WebRTC Tutorial__ web application client you created earlier.

## Whats next

- Play Linux and Windows games from Steam, Origin, Battle.net and more with [Lutris ](https://lutris.net/downloads/), an open source gaming platform for Linux.