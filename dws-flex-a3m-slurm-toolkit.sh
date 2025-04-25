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

# Testing the toolkit - commands with variable names
export NETWORK_NAME_SYSNET=flexnet
export SUBNETWORK_NAME_SYSNET=sub1
export REGION=us-central1
export ZONE_PARTITION_A=us-central1-c
export CONFIG_BUCKET_NAME=test-bucket-a3mega
export PROJECT_ID=northam-ce-mlai-tpu                   # replace
export BASE_DEPLOYMENT_NAME=a3mega-flex-slurm-base
export IMAGE_DEPLOYMENT_NAME=a3mega-flex-slurm-image
export CLUSTER_DEPLOYMENT_NAME=a3mega-flex-slurm-clu
export SLURM_CLUSTER_NAME=flexclu
export FILESTORE_IP=10.33.0.2                           # change after step 2
export DISK_SIZE_GB=200
export CT_PATH=../cluster-toolkit
export BP_PATH=blueprints/a3m-toolkit-blueprints/release-candidate-multifile
export OUT_PATH=deployments/

gcloud config set project ${PROJECT_ID}

# Create config state bucket
gcloud storage buckets create gs://${CONFIG_BUCKET_NAME} \
    --project=${PROJECT_ID} \
    --default-storage-class=STANDARD \
    --location=${REGION} \
    --uniform-bucket-level-access
gcloud storage buckets update gs://${CONFIG_BUCKET_NAME} --versioning

# Deploy base (filestore + network)
${CT_PATH}/gcluster deploy -w -d ${BP_PATH}/deployment-base.yaml \
        ${BP_PATH}/slurm-a3mega-base.yaml \
        --out ${OUT_PATH} \
        --vars deployment_name=${BASE_DEPLOYMENT_NAME} \
        --vars network_name_system=${NETWORK_NAME_SYSNET} \
        --vars subnetwork_name_system=${SUBNETWORK_NAME_SYSNET} \
        --vars region=${REGION} \
        --vars project_id=${PROJECT_ID} \
        --vars zone=${ZONE_PARTITION_A}

# once applied, get the IP address for the Filestore instance and populate it 
# to the variables section above. or below.
export FILESTORE_IP=10.140.0.2

# Deploy image 
${CT_PATH}/gcluster deploy -w -d ${BP_PATH}/deployment-base.yaml \
        ${BP_PATH}/slurm-a3mega-image.yaml --auto-approve \
        --out ${OUT_PATH} \
        --vars deployment_name=${IMAGE_DEPLOYMENT_NAME} \
        --vars network_name_system=${NETWORK_NAME_SYSNET} \
        --vars subnetwork_name_system=${SUBNETWORK_NAME_SYSNET} \
        --vars region=${REGION} \
        --vars project_id=${PROJECT_ID} \
        --vars zone=${ZONE_PARTITION_A} \
        --vars server_ip_homefs=${FILESTORE_IP} \
        --vars slurm_cluster_name=${SLURM_CLUSTER_NAME} \
        --vars enable_ops_agent=true \
        --vars enable_nvidia_dcgm=true \
        --vars final_image_family=slurm-a3mega \
        --vars disk_size_gb=${DISK_SIZE_GB}

# Deploy the slurm cluster (login node, controller node, and 2x partitions - debug + a3mega)
${CT_PATH}/gcluster deploy -w -d ${BP_PATH}/deployment-base.yaml \
    ${BP_PATH}/slurm-a3mega-gcsfuse-lssd-cluster.yaml --auto-approve \
        --out ${OUT_PATH} \
        --vars deployment_name=${CLUSTER_DEPLOYMENT_NAME} \
        --vars network_name_system=${NETWORK_NAME_SYSNET} \
        --vars subnetwork_name_system=${SUBNETWORK_NAME_SYSNET} \
        --vars region=${REGION} \
        --vars project_id=${PROJECT_ID} \
        --vars zone=${ZONE_PARTITION_A} \
        --vars gcs_bucket=${CONFIG_BUCKET_NAME} \
        --vars server_ip_homefs=${FILESTORE_IP} \
        --vars slurm_cluster_name=${SLURM_CLUSTER_NAME} \
        --vars final_image_family=slurm-a3mega \
        --vars enable_ops_agent=true \
        --vars enable_nvidia_dcgm=true \
        --vars disk_size_gb=${DISK_SIZE_GB}

# ./gcluster destroy a3mega-cluster
${CT_PATH}/gcluster destroy ${OUT_PATH}/${CLUSTER_DEPLOYMENT_NAME}

# If desired, the info to put in .ssh/config
# gcloud compute config-ssh --dry-run - or you can directly SSH to the node using this
gcloud compute ssh <node_name>-login-001 --tunnel-through-iap 

# allocate a A3-mega node to ssh do one of the worker node
salloc -N 1 -p a3new # one could just do `salloc` because a3new in this case is the default partition. And -N1 is also 
# not necessary
# Force turn off node when done (if necessary - DWS flex should release 
# the node when the timeout has run out)
sudo -i -u slurm scontrol update NodeName=oliflexclu-a3mnodesetdwsf-0 State=POWER_DOWN_ASAP Reason="DWS Flex Release"

# Clean Up
# Destroy the cluster
${CT_PATH}/gcluster destroy ${OUT_PATH}/${CLUSTER_DEPLOYMENT_NAME}

# Destroy the image - you may NOT need to destroy this. The image can be leftover if  you
# need to, without incurring compute costs.
${CT_PATH}/gcluster destroy ${OUT_PATH}/${IMAGE_DEPLOYMENT_NAME}

# Destroy the base
${CT_PATH}/gcluster destroy ${OUT_PATH}/${BASE_DEPLOYMENT_NAME}

# Destroy the configuration bucket
gcloud storage buckets delete gs://${CONFIG_BUCKET_NAME}
