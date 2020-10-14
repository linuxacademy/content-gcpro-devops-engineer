export PROJECT_ID=$(gcloud config list --format 'value(core.project)')

# Initialize your App Engine app with your project and choose its region:

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

cd quick-deploy/quick-gae-deployment
sed -i s/[[]YOUR-PROJECT-ID[]]/$PROJECT_ID/ config.py
sed -i s/[[]YOUR-BUCKET-NAME[]]/$PROJECT_ID-worldart-assets/ config.py
pip install --upgrade pip
pip install -r requirements.txt -t lib
gcloud app deploy --quiet