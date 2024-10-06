export CLUSTER_NAME=pytorch-cluster
export REGION=europe-west4
export ZONE=$REGION-b
gcloud beta container node-pools create dws-a3-mega \
    --cluster=$CLUSTER_NAME \
    --node-locations $ZONE --region $REGION \
    --enable-queued-provisioning \
    --accelerator type=nvidia-h100-mega-80gb,count=8,gpu-driver-version=latest \
    --machine-type=a3-megagpu-8g \
    --enable-autoscaling  \
    --num-nodes=0   \
    --total-max-nodes 3 \
    --location-policy=ANY  \
    --reservation-affinity=none  \
    --no-enable-autorepair