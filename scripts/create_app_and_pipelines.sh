#!/usr/bin/env bash

bold() {
  echo ". $(tput bold)" "$*" "$(tput sgr0)";
}

source ~/cloudshell_open/spinnaker-for-gcp/scripts/install/properties



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

if [ ! -d ~/world-gift-art ]; then
  bold 'Creating GCR repo "world-gift-art" in project...'
  gcloud source repos create world-gift-art
  gcloud source repos clone world-gift-art
fi

cd ~/world-gift-art
git pull https://github.com/linuxacademy/content-gcpro-devops-engineer

cat ~/world-gift-art/working/world-gift-art-v3/templates/repo/cloudbuild_yaml.template | envsubst '$BUCKET_NAME' > ~/world-gift-art/working/world-gift-art-v3/cloudbuild.yaml
cat ~/world-gift-art/working/world-gift-art-v3/config/staging/replicaset_yaml.template | envsubst > ~/world-gift-art/working/world-gift-art-v3/config/staging/replicaset.yaml
rm ~/world-gift-art/working/world-gift-art-v3/config/staging/replicaset_yaml.template
cat ~/world-gift-art/working/world-gift-art-v3/config/prod/replicaset_yaml.template | envsubst > ~/world-gift-art/working/world-gift-art-v3/config/prod/replicaset.yaml
rm ~/world-gift-art/working/world-gift-art-v3/config/prod/replicaset_yaml.template

# substitute current project ID and assets buckets for placeholders in config.py file
cd working/world-gift-art-v3
sed -i s/[[]YOUR-PROJECT-ID[]]/$PROJECT_ID/ config.py
sed -i s/[[]YOUR-BUCKET-NAME[]]/$PROJECT_ID-worldart-assets/ config.py



bold "Creating world-gift-art Spinnaker application..."
~/spin app save --application-name world-gift-art --cloud-providers kubernetes --owner-email $IAP_USER

bold 'Creating "Deploy to Staging" Spinnaker pipeline...'
cat ~/world-gift-art/working/world-gift-art-v3/templates/pipelines/deploystaging_json.template | envsubst  > ~/world-gift-art/working/world-gift-art-v3/templates/pipelines/deploystaging.json
~/spin pi save -f ~/world-gift-art/working/world-gift-art-v3/templates/pipelines/deploystaging.json

export DEPLOY_STAGING_PIPELINE_ID=$(~/spin pi get -a world-gift-art -n 'Deploy to Staging' | jq -r '.id')

bold 'Creating "Deploy to Prod" Spinnaker pipeline...'
cat ~/world-gift-art/working/world-gift-art-v3/templates/pipelines/deployprod_json.template | envsubst  > ~/world-gift-art/working/world-gift-art-v3/templates/pipelines/deployprod.json
~/spin pi save -f ~/world-gift-art/working/world-gift-art-v3/templates/pipelines/deployprod.json

git add *
git commit -m "Add source, build, and manifest files."
git push

if [ -z $(gcloud alpha builds triggers list --filter triggerTemplate.repoName=world-gift-art --format 'get(id)') ]; then
  bold "Creating Cloud Build build trigger for world-gift-art app..."
  gcloud alpha builds triggers create cloud-source-repositories \
    --repo world-gift-art \
    --branch-pattern master \
    --build-config working/world-gift-art-v3/cloudbuild.yaml
fi