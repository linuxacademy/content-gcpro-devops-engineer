# Enable API's
gcloud services enable container.googleapis.com
gcloud services enable containerregistry.googleapis.com
gcloud services enable datastore.googleapis.com

# Add project ID to a variable

export PROJECT_ID=$(gcloud config list --format 'value(core.project)')

# set default project and region/zone
gcloud config set project $PROJECT_ID
gcloud config set compute/zone us-east1-b
gcloud config set compute/region us-east1

# create GKE cluster
gcloud container clusters create demo-cluster --zone us-east1-b \
  --scopes "https://www.googleapis.com/auth/userinfo.email","cloud-platform" \
  --num-nodes 3
# get credentials for cluster
gcloud container clusters get-credentials demo-cluster

# GitHub app setup
# Create region for Datastore
gcloud app create --region us-east1
# create GCS bucket and assign public access
gsutil mb -l us-east1 gs://$PROJECT_ID-worldart-assets
gsutil iam ch allUsers:objectViewer gs://$PROJECT_ID-worldart-assets
# pull repo and browse to container directory
mkdir world-gift-art
cd ~/world-gift-art
git init
git pull https://github.com/linuxacademy/content-gcpro-devops-engineer

# substitute current project ID and assets buckets for placeholders in config.py file
cd quick-deploy/quick-gke-deployment
sed -i s/[[]YOUR-PROJECT-ID[]]/$PROJECT_ID/ config.py
sed -i s/[[]YOUR-BUCKET-NAME[]]/$PROJECT_ID-worldart-assets/ config.py

# Build and push container to Container Registry

docker build -t gcr.io/$PROJECT_ID/world-gift-art:v1 .
docker push gcr.io/$PROJECT_ID/world-gift-art:v1

# deploy container to cluster
kubectl create deployment world-gift-art --image=gcr.io/$PROJECT_ID/world-gift-art:v1
# expose deployment
kubectl expose deployment world-gift-art --type LoadBalancer --port 80 --target-port 8080
# Set the baseline number of Deployment replicas to 3.
kubectl scale deployment world-gift-art --replicas=3
# Create a HorizontalPodAutoscaler resource for your Deployment.
kubectl autoscale deployment world-gift-art --cpu-percent=80 --min=3 --max=5

echo
echo "Deployment Complete!"
echo "Find your app's IP address by referencing the EXTERNAL_IP address using command"
echo "kubectl get services"
echo "Or by referencing the Services menu in the GKE web console"
echo