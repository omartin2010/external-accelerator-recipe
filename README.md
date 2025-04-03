## Accelerators Usage Samples 
In this repo, you will (eventually) find (several) examples of using Google Cloud's accelerators (GPU & TPU) using different provisionning methods (including spot, on demand, reservations, GKE Flex, and GKE Calendar), and also using different orchestrators (Slurm + GKE primarily)

### Recipes
1. [`dws-flex-a3m-gke-sh`](./dws-flex-a3m-gke.sh) - this recipe shows how to deploy a GKE cluster using `a3-megagpu-8g` instances using a DWS Flex Nodepool, and leveraging the [Cluster Toolkit](https://github.com/GoogleCloudPlatform/cluster-toolkit/tree/main) for deployment. The script is NOT meant to be run all in one go, but run commands separately.

