# for L4 and spot node-pools
export PROJECT_ID=<your-project-id>
export HF_TOKEN=<paste-your-own-token>

export REGION=us-central1
export ZONE_1=${REGION}-a # You may want to change the zone letter based on the region you selected above
export ZONE_2=${REGION}-b # You may want to change the zone letter based on the region you selected above
export CLUSTER_NAME=pytorch-cluster

gcloud config set project "$PROJECT_ID"
gcloud config set compute/region "$REGION"
gcloud config set compute/zone "$ZONE_1"

gcloud container clusters create $CLUSTER_NAME --location ${REGION} \
  --workload-pool ${PROJECT_ID}.svc.id.goog \
  --enable-image-streaming --enable-shielded-nodes \
  --shielded-secure-boot --shielded-integrity-monitoring \
  --enable-ip-alias \
  --node-locations=$REGION-b \
  --workload-pool=${PROJECT_ID}.svc.id.goog \
  --addons GcsFuseCsiDriver   \
  --no-enable-master-authorized-networks \
  --machine-type n2d-standard-4 \
  #--cluster-version 1.27.5-gke.200 \
  --num-nodes 1 --min-nodes 1 --max-nodes 3 \
  --ephemeral-storage-local-ssd=count=2 \
  --scopes="gke-default,storage-rw"

PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format='value(projectNumber)')
GCE_SA="${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"
for role in monitoring.metricWriter stackdriver.resourceMetadata.writer; do
  gcloud projects add-iam-policy-binding $PROJECT_ID --member=serviceAccount:${GCE_SA} --role=roles/${role}
done

##create nodepool with 1L4 per node
gcloud container node-pools create l4-node-pool --cluster \
$CLUSTER_NAME --accelerator type=nvidia-l4,count=1,gpu-driver-version=default   --machine-type g2-standard-8 \
--ephemeral-storage-local-ssd=count=1   --enable-autoscaling --enable-image-streaming   --num-nodes=0 --min-nodes=0 --max-nodes=3 \
--shielded-secure-boot   --shielded-integrity-monitoring --node-locations $ZONE_1,$ZONE_2 --region $REGION --spot

##create nodepool with 2L4 per node
gcloud container node-pools create l4-2-node-pool --cluster \
$CLUSTER_NAME --accelerator type=nvidia-l4,count=2,gpu-driver-version=latest   --machine-type g2-standard-24 \
--ephemeral-storage-local-ssd=count=0   --enable-autoscaling --enable-image-streaming   --num-nodes=0 --min-nodes=0 --max-nodes=3 \
--shielded-secure-boot   --shielded-integrity-monitoring --node-locations $ZONE_1,$ZONE_2 --region $REGION --spot

#Create nodepool with 4 A100 1g, 
 gcloud container node-pools create a2-a100-1g --cluster $CLUSTER_NAME --accelerator type=nvidia-tesla-a100,count=1,gpu-driver-version=latest \
  --machine-type a2-highgpu-1g --ephemeral-storage-local-ssd=count=0   --enable-autoscaling --enable-image-streaming   \
  --num-nodes=0 --min-nodes=0 --max-nodes=4 --shielded-secure-boot   --shielded-integrity-monitoring --node-locations $REGION-a --region $REGION --spot

# Create nodepool with 1 A100 8g, 
 gcloud container node-pools create a2-a100-1g --cluster $CLUSTER_NAME --accelerator type=nvidia-tesla-a100,count=8,gpu-driver-version=latest \
  --machine-type a2-highgpu-8g --ephemeral-storage-local-ssd=count=0   --enable-autoscaling --enable-image-streaming   \
  --num-nodes=0 --min-nodes=0 --max-nodes=1 --shielded-secure-boot   --shielded-integrity-monitoring --node-locations $REGION-a --region $REGION --spot



kubectl annotate serviceaccount $NAMESPACE \
    --namespace $NAMESPACE \
    iam.gke.io/gcp-service-account=$GCE_SA

kubectl create secret generic huggingface --from-literal="HF_TOKEN=$HF_TOKEN" -n $NAMESPACE