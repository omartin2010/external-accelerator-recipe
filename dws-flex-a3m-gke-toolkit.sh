# Copyright 2025 "Google LLC"
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

export REGION=us-central1
export ZONE_1C=${REGION}-c
export PROJECT_ID=$(gcloud config get-value project)
export CT_PATH=../cluster-toolkit
export DEPLOYMENT_NAME=oli-gke-a3m-dwsflex

# deploy the cluster toolkit using the documentation for the toolkit
# https://cloud.google.com/cluster-toolkit/docs/setup/configure-environment
# you need this so that gcluster is actually installed. If in the same root 
# directory as this repo, the path above (CT_PATH) variable should work.

# Deploy the cluster using the parameters above
${CT_PATH}/gcluster deploy -w ${CT_PATH}/examples/gke-dws-flex-start/gke-dws-flex-start.yaml \
        --vars project_id=${PROJECT_ID} \
        --vars region=${REGION} \
        --vars zone=${ZONE_1C} \
        --vars deployment_name=${DEPLOYMENT_NAME}

# Obtain GKE cluster credentials
gcloud container clusters get-credentials ${DEPLOYMENT_NAME} \
        --location ${REGION} \
        --project ${PROJECT_ID}

# Deploy kueues resources
# (not needed when using the toolkit)
# kubectl apply -f kueues.yaml

# Install the tcpxo daemonset - (modified to add labels=tcpxo:enabled)
# (not needed if deployed with toolkit)
# kubectl apply -f nccl-tcpxo-installer.yaml

# Enable NRI
# (not needed if deployed with toolkit)
# kubectl apply -f nri.yaml

# Run sample job
# UPDATE the manifest to the proper nodepool (a3-megagpu-8g-a3megagpupool)
# TODO: use yq to update the manifest if nodepool name is modified using 
# a variable applied to the toolkit's deployment or using other methods
kubectl apply -f gpu-dws-recipes/dws-flex-nccl-test-job-a3-megagpu-us-central-1c.yaml

# JOB_NAME
export JOB_NAME=oli-dws-job-zone-c
export POD_NAME=$(kubectl get pods -l job-name=${JOB_NAME}     -o go-template='{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}' | head -n 1)
export PEER_POD_IPS=$(kubectl get pods -l job-name=${JOB_NAME} -o go-template='{{range .items}}{{.status.podIP}}{{" "}}{{end}}')

## NCCL test job all_gather.sh
kubectl exec --stdin --tty --container=nccl-test ${POD_NAME} -- /scripts/allgather.sh $PEER_POD_IPS

# Troubleshooting

# Start by looking at created objects:
kubectl get jobs
kubectl get nodes
kubectl get pods
kubectl get provreqs 
# inspect for DWS issues - and also investigate using kubectl describe provreq <>
# Then consider "describing" the objects.
# kubectl describe job <job_id>
# kubectl describe pod <pod_id> etc.

# Problem with provisioning request?
export PROVREQ=$(kubectl get provreqs -o go-template='{{range.items}}{{.metadata.name}}{{"\n"}}{{end}}' | head -n 1)
kubectl describe provreqs ${PROVREQ}

# Main workload
# Side car - add sleep infinity to manifest if issue in sidecar to troubleshoot
kubectl exec --stdin --tty --container=nccl-test ${POD_NAME_1} -- /bin/bash
kubectl exec --stdin --tty --container=nccl-test ${POD_NAME_2} -- /bin/bash

# Install net tools if needed to troubleshoot
apt update && apt upgrade -y && apt install iputils-ping -y && apt install dnsutils -y && apt install net-tools -y
