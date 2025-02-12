GVNIC_NETWORK_PREFIX=a3ultra-gvnic
PROJECT=gpu-launchpad-playground
RDMA_NETWORK_PREFIX=a3ultra-rdma
REGION=europe-west1
ZONE=europe-west1-b

gcloud container clusters create CLUSTER_NAME \
  --project=PROJECT_ID \
  --region=COMPUTE_REGION [--zone=COMPUTE_ZONE] \
  --cluster-version=CLUSTER_VERSION \
  --enable-dataplane-v2 --enable-ip-alias --enable-multi-networking \
  [--services-ipv4-cidr=SERVICE_CIDR \
  --cluster-ipv4-cidr=POD_CIDR]

gcloud container node-pools create a3-ultra-h200 \
  --region $REGION --cluster gke-a3ultra-manual \
  --node-locations $ZONE \
  --accelerator type=nvidia-h200-141gb,count=8,gpu-driver-version=latest \
  --machine-type a3-ultragpu-8g \
  --num-nodes=0 \
  --enable-autoscaling --num-nodes=0 --min-nodes=0 --max-nodes=4 \
  --enable-autoupgrade \
  --disk-type hyperdisk-balanced \
  --reservation-affinity=specific \
  --reservation=gpu-launchpad-gsc  \
  --additional-node-network network=${GVNIC_NETWORK_PREFIX}-net,subnetwork=${GVNIC_NETWORK_PREFIX}-sub \
  --additional-node-network network=${RDMA_NETWORK_PREFIX}-net,subnetwork=${RDMA_NETWORK_PREFIX}-sub-0 \
  --additional-node-network network=${RDMA_NETWORK_PREFIX}-net,subnetwork=${RDMA_NETWORK_PREFIX}-sub-1 \
  --additional-node-network network=${RDMA_NETWORK_PREFIX}-net,subnetwork=${RDMA_NETWORK_PREFIX}-sub-2 \
  --additional-node-network network=${RDMA_NETWORK_PREFIX}-net,subnetwork=${RDMA_NETWORK_PREFIX}-sub-3 \
  --additional-node-network network=${RDMA_NETWORK_PREFIX}-net,subnetwork=${RDMA_NETWORK_PREFIX}-sub-4 \
  --additional-node-network network=${RDMA_NETWORK_PREFIX}-net,subnetwork=${RDMA_NETWORK_PREFIX}-sub-5 \
  --additional-node-network network=${RDMA_NETWORK_PREFIX}-net,subnetwork=${RDMA_NETWORK_PREFIX}-sub-6 \
  --additional-node-network network=${RDMA_NETWORK_PREFIX}-net,subnetwork=${RDMA_NETWORK_PREFIX}-sub-7
