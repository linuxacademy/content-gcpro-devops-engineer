#!/usr/bin/env bash

# return to home directory
cd

bold() {
  echo ". $(tput bold)" "$*" "$(tput sgr0)";
}

source ~/cloudshell_open/spinnaker-for-gcp/scripts/install/properties

# Enable Datastore API:
gcloud services enable datastore.googleapis.com

# Error checking to ensure port forwarding/IAP access to Spinnaker is enabled before proceeding
if ! ~/spin app list &> /dev/null ; then
  bold "Spinnaker instance is not reachable via the Spin CLI. Please make sure the Spinnaker \
instance is reachable with port-forwarding or is exposed publicly.

To port-forward the Spinnaker UI, run this command:
~/cloudshell_open/spinnaker-for-gcp/scripts/manage/connect_unsecured.sh

If you would instead like to expose the service with a domain behind Identity-Aware Proxy, \
run this command:
~/cloudshell_open/spinnaker-for-gcp/scripts/expose/configure_endpoint.sh
"
  exit 1
fi

# create GCS bucket and assign public access
gsutil mb -l $REGION gs://$PROJECT_ID-worldart-assets
gsutil iam ch allUsers:objectViewer gs://$PROJECT_ID-worldart-assets

bold 'Creating GCR repo "world-gift-art" in project...'
cd
gcloud source repos create world-gift-art
gcloud source repos clone world-gift-art ~/world-gift-art


cd ~/world-gift-art
git pull https://github.com/linuxacademy/content-gcpro-devops-engineer

cat ~/world-gift-art/spinnaker-pipeline/templates/repo/cloudbuild_yaml.template | envsubst '$BUCKET_NAME' > ~/world-gift-art/spinnaker-pipeline/cloudbuild.yaml
cat ~/world-gift-art/spinnaker-pipeline/config/staging/replicaset_yaml.template | envsubst > ~/world-gift-art/spinnaker-pipeline/config/staging/replicaset.yaml
rm ~/world-gift-art/spinnaker-pipeline/config/staging/replicaset_yaml.template
cat ~/world-gift-art/spinnaker-pipeline/config/prod/replicaset_yaml.template | envsubst > ~/world-gift-art/spinnaker-pipeline/config/prod/replicaset.yaml
rm ~/world-gift-art/spinnaker-pipeline/config/prod/replicaset_yaml.template

# substitute current project ID and assets buckets for placeholders in config.py file
cd spinnaker-pipeline
sed -i s/[[]YOUR-PROJECT-ID[]]/$PROJECT_ID/ config.py
sed -i s/[[]YOUR-BUCKET-NAME[]]/$PROJECT_ID-worldart-assets/ config.py



bold "Creating world-gift-art Spinnaker application..."
~/spin app save --application-name world-gift-art --cloud-providers kubernetes --owner-email $IAP_USER

bold 'Creating "Deploy to Staging" Spinnaker pipeline...'
cat ~/world-gift-art/spinnaker-pipeline/templates/pipelines/deploystaging_json.template | envsubst  > ~/world-gift-art/spinnaker-pipeline/templates/pipelines/deploystaging.json
~/spin pi save -f ~/world-gift-art/spinnaker-pipeline/templates/pipelines/deploystaging.json

export DEPLOY_STAGING_PIPELINE_ID=$(~/spin pi get -a world-gift-art -n 'Deploy to Staging' | jq -r '.id')

bold 'Creating "Deploy to Prod" Spinnaker pipeline...'
cat ~/world-gift-art/spinnaker-pipeline/templates/pipelines/deployprod_json.template | envsubst  > ~/world-gift-art/spinnaker-pipeline/templates/pipelines/deployprod.json
~/spin pi save -f ~/world-gift-art/spinnaker-pipeline/templates/pipelines/deployprod.json

git add *
git commit -m "Add source, build, and manifest files."
git push

bold "Creating Cloud Build build trigger for world-gift-art app..."
gcloud beta builds triggers create cloud-source-repositories \
  --repo world-gift-art \
  --branch-pattern master \
  --build-config spinnaker-pipeline/cloudbuild.yaml