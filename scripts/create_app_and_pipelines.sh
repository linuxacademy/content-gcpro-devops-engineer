#!/usr/bin/env bash

bold() {
  echo ". $(tput bold)" "$*" "$(tput sgr0)";
}

source ~/cloudshell_open/spinnaker-for-gcp/scripts/install/properties

~/cloudshell_open/spinnaker-for-gcp/scripts/manage/check_project_mismatch.sh

pushd ~/cloudshell_open/spinnaker-for-gcp/samples/worldart

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

if [ ! -d ~/worldart ]; then
  bold 'Creating GCR repo "worldart" in Spinnaker project...'
  gcloud source repos create worldart
  mkdir -p ~
  gcloud source repos clone worldart ~/worldart
fi


cat ~/worldart/working/world-gift-art-v3/templates/repo/cloudbuild_yaml.template | envsubst '$BUCKET_NAME' > ~/worldart/working/world-gift-art-v3/cloudbuild.yaml
cat ~/worldart/working/world-gift-art-v3/config/staging/replicaset_yaml.template | envsubst > ~/worldart/config/staging/replicaset.yaml
rm ~/worldart/working/world-gift-art-v3/config/staging/replicaset_yaml.template
cat ~/worldart/working/world-gift-art-v3/config/prod/replicaset_yaml.template | envsubst > ~/worldart/config/prod/replicaset.yaml
rm ~/worldart/working/world-gift-art-v3/config/prod/replicaset_yaml.template

pushd ~/worldart

git add *
git commit -m "Add source, build, and manifest files."
git push

popd

if [ -z $(gcloud alpha builds triggers list --filter triggerTemplate.repoName=worldart --format 'get(id)') ]; then
  bold "Creating Cloud Build build trigger for helloworld app..."
  gcloud alpha builds triggers create cloud-source-repositories \
    --repo worldart \
    --branch-pattern master \
    --build-config working/world-gift-art-v3/cloudbuild.yaml
fi

bold "Creating worldart Spinnaker application..."
~/spin app save --application-name worldart --cloud-providers kubernetes --owner-email $IAP_USER

bold 'Creating "Deploy to Staging" Spinnaker pipeline...'
cat ~/worldart/working/world-gift-art-v3/templates/pipelines/deploystaging_json.template | envsubst  > ~/worldart/working/world-gift-art-v3/templates/pipelines/deploystaging.json
~/spin pi save -f ~/worldart/working/world-gift-art-v3/templates/pipelines/deploystaging.json

export DEPLOY_STAGING_PIPELINE_ID=$(~/spin pi get -a worldart -n 'Deploy to Staging' | jq -r '.id')

bold 'Creating "Deploy to Prod" Spinnaker pipeline...'
cat ~/worldart/working/world-gift-art-v3/templates/pipelines/deployprod_json.template | envsubst  > ~/worldart/working/world-gift-art-v3/templates/pipelines/deployprod.json
~/spin pi save -f ~/worldart/working/world-gift-art-v3/templates/pipelines/deployprod.json

popd
