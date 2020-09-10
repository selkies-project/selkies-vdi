# App Proxy and Selkies Connector client

Image for running modified huproxy as sidecar in user pod to create secure tunnels into pod.

## Setup

1. Set your project ID

```bash
export PROJECT_ID=$(gcloud config get-value project)
```

## Create Desktop App client ID

1. From the [API Credentials](https://console.cloud.google.com/apis/credentials) Cloud Console page, create a new __Desktop app__ type OAuth client named "Selkies Connector" 
2. Note the newly created client ID and secret for later use.
3. Note your Selkies __Web application__ client ID for later use (created automatically during initial deployment).

## Building the image

1. Set variables containing oauth and project properties:

```
export IAP_CLIENT_ID=YOUR_SELKIES_WEB_APP_CLIENT_ID
export DESKTOP_CLIENT_ID=YOUR_DESKTOP_APP_CLIENT_ID
export DESKTOP_CLIENT_SECRET=YOUR_DESKTOP_APP_CLIENT_SECRET
```

> NOTE: Replace the values of the variables with the respective values obtained earlier.

2. Build the image with the build-args:

```bash
docker build -t gcr.io/${PROJECT_ID?}/webrtc-gpu-streaming-app-proxy:latest --build-arg BROKER_CLIENT_ID=${IAP_CLIENT_ID?} --build-arg DESKTOP_CLIENT_ID=${DESKTOP_CLIENT_ID?} --build-arg DESKTOP_CLIENT_SECRET=${DESKTOP_CLIENT_SECRET?} --build-arg DEFAULT_ENDPOINT=broker.endpoints.${PROJECT_ID?}.cloud.goog .
```

3. Push the image:

```bash
docker push gcr.io/${PROJECT_ID?}/webrtc-gpu-streaming-app-proxy:latest
```

## Upate BrokerAppConfig

1. Edit your BrokerAppConfig and add the following to `spec.appParams`:

```yaml
appParams:
  - name: enableAppProxy
    default: "true"
```

2. Shutdown and restart your app.
3. The app should start with a new sidecar named `proxy`

## Download and the connector binary

1. After launching the app, navigate to the Selkies Connect setup url:

```
echo "https://broker.endpoints.${PROJECT_ID?}.cloud.goog/APP_NAME/connect/
```
> NOTE: Replace APP_NAME with your launched app name.

2. Follow the instructions on the Selkies Connect setup page to download the binary and run it.