export CLUSTER_NAME=rick-a3-mega-spot
export REGION=asia-northeast1
export ZONE=$REGION-b
export PREFIX=rick-a3-mega-spot-gpu
gcloud beta container node-pools create dws-a3-mega \
    --cluster=$CLUSTER_NAME \
    --node-locations $ZONE --region $REGION \
    --enable-queued-provisioning \
    --accelerator type=nvidia-h100-mega-80gb,count=8,gpu-driver-version=latest \
    --machine-type=a3-megagpu-8g \
    --additional-node-network network=$PREFIX-0,subnetwork=$PREFIX-0 \
    --additional-node-network network=$PREFIX-1,subnetwork=$PREFIX-1 \
    --additional-node-network network=$PREFIX-2,subnetwork=$PREFIX-2 \
    --additional-node-network network=$PREFIX-3,subnetwork=$PREFIX-3 \
    --additional-node-network network=$PREFIX-4,subnetwork=$PREFIX-4 \
    --additional-node-network network=$PREFIX-5,subnetwork=$PREFIX-5 \
    --additional-node-network network=$PREFIX-6,subnetwork=$PREFIX-6 \
    --additional-node-network network=$PREFIX-7,subnetwork=$PREFIX-7 \
    --enable-gvnic \
    --no-enable-autoupgrade \
    --scopes "https://www.googleapis.com/auth/cloud-platform" \
    --enable-autoscaling \
    --num-nodes=0 \
    --total-max-nodes 3 \
    --location-policy=ANY \
    --reservation-affinity=none \
    --no-enable-autorepair