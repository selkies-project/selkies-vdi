# Copyright 2019 Google Inc. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

PROJECT=$(shell gcloud config get-value project 2>/dev/null)

PACKER_GCB_REPO_DIR=/tmp/cloud-builders-community

all: image

image: cloudbuild.yaml packer-gcb
	gcloud builds submit \
        --project $(PROJECT) \
        --timeout=3600 \
        --config $<

enable-cloudbuild:
	gcloud services enable --project $(PROJECT) compute.googleapis.com
	gcloud services enable --project $(PROJECT) cloudbuild.googleapis.com

packer-gcb-image:
	$(eval GCB_IMAGE := $(shell gcloud container images list --project $(PROJECT) --filter name=gcr.io/$(PROJECT)/packer --format='value(name)'))

packer-gcb-iam:
	CLOUD_BUILD_ACCOUNT=$$(gcloud projects get-iam-policy --project $(PROJECT) $(PROJECT) --filter="(bindings.role:roles/cloudbuild.builds.builder)"  --flatten="bindings[].members[]" --limit=1 --format="value(bindings.members[])") && \
	gcloud projects add-iam-policy-binding --project $(PROJECT) $(PROJECT) \
	  --member $${CLOUD_BUILD_ACCOUNT} \
	  --role roles/editor >/dev/null

packer-ssh-rule:
	$(eval PACKER_FIREWALL := $(shell gcloud compute firewall-rules list --project $(PROJECT) --filter="name~packer-allow-ssh" --format='value(name)'))

packer-create-ssh-rule: packer-ssh-rule
	if test -z "$(PACKER_FIREWALL)"; then \
	gcloud compute firewall-rules create --project $(PROJECT) packer-allow-ssh --allow=tcp:22 --source-ranges=0.0.0.0/0 --target-tags=packer; fi

$(PACKER_GCB_REPO_DIR):
	cd /tmp && git clone https://github.com/GoogleCloudPlatform/cloud-builders-community.git

packer-gcb: $(PACKER_GCB_REPO_DIR) enable-cloudbuild packer-create-ssh-rule packer-gcb-image packer-gcb-iam
	if test -z "$(GCB_IMAGE)"; then \
	cd $(PACKER_GCB_REPO_DIR)/packer && \
	gcloud builds submit --project $(PROJECT) --config cloudbuild.yaml && \
	rm -rf /tmp/cloud-builders-community; else echo "packer cloud build image exists"; fi

packer-gcb-image-test:
	echo $(GCB_IMAGE)

image-name:
	$(eval export IMAGE_NAME = $(shell gcloud compute images list --project=$${SOURCE_PROJECT:-$(PROJECT)} --filter 'family = gpu-accel-webrtc' --sort-by='~creationTimestamp' --format='csv[no-heading](name)' --limit=1 | cut -d ',' -f1))
	@if test -z "$${IMAGE_NAME}"; then echo "ERROR: failed to find image in source project." && exit 1; fi
