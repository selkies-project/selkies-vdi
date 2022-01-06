# TURN deployment for Selkies VDI addon

Deploys coturn and coturn-web from the selkies-gstreamer repo configured for the Selkies Cluster environment.

There are 2 supported methods for deploying the TURN infrastrcture required by the WebRTC addon.

1. If you are using a public GKE cluster, then you can run the TURN service on the GKE nodes.
2. If you are using a private GKE cluster, then you can deploy the TURN servers on GCE instances and the coturn-web discovery aggretator on the private GKE cluster.

# Public GKE deployment

If you are using a public GKE cluster, then you can run the TURN service on the GKE nodes.

1. Create a TURN shared secret and save it to Secret Manager:

```bash
export TURN_SHARED_SECRET=$(openssl rand -base64 15)
gcloud secrets create selkies-turn-shared-secret --replication-policy=automatic --data-file <(echo -n ${TURN_SHARED_SECRET?})
```

2. Set the TURN_REALM to the address of your cluster:

```bash
export TURN_REALM="broker.endpoints.${PROJECT_ID?}.cloud.goog"
```

> If you changed the endpoint for your Selkies cluster, make sure to use the updated domain name.

3. Deploy on a public GKE cluster:

```bash
REGION=us-west1
```

```bash
gcloud builds submit --config cloudbuild.public-gke.yaml --project ${PROJECT_ID?} --substitutions=_TURN_REALM=${TURN_REALM?},_REGION=${REGION?}_ACTION=apply
```

# Private GKE deployment

If you are using a private GKE cluster, then you can deploy the TURN servers on GCE instances and the coturn-web discovery aggretator on the private GKE cluster.

> Note that you can also run TURN this way on a public cluster. 

1. Set the TURN_REALM to the address of your cluster:

```bash
export TURN_REALM="broker.endpoints.${PROJECT_ID?}.cloud.goog"
```

> If you changed the endpoint for your Selkies cluster, make sure to use the updated domain name.

2. Deploy on a private GKE cluster:

```bash
REGION=us-west1
```

```bash
gcloud builds submit --config cloudbuild.private-gke.yaml --project ${PROJECT_ID?} --substitutions=_TURN_REALM=${TURN_REALM?},_REGION=${REGION?}_ACTION=apply
```

### (Optional) Update pod broker with network policy support for TURN

If using the egress network policy feature, update the pod broker to support SRV record discovery of the TURN endpoints.
This is required because WebRTC will fail when an egress NetworkPolicy is applied if the public IPs of the TURN servcers is not added as an exception.

1. Create Secret Manager Secret with new pod-broker parameter:

```bash
echo 'POD_BROKER_PARAM_AddEgressSRVRecords: turn:udp:coturn-discovery.coturn.svc.cluster.local' > broker-${REGION?}-params
```

```bash
gcloud secrets create broker-${REGION?}-params \
  --replication-policy=automatic \
  --data-file broker-${REGION?}-params
```

2. Apply the paramter configuration to the Selkies cluster:

```bash
cd ${SELKIES_CORE_REPO_DIR?}/setup/manifests/

gcloud builds submit --substitutions=_REGION=${REGION?}
```