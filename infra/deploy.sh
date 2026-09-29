#!/bin/bash
set -e

set -a
source .env
set +a

IMAGE_SERVER_NAME="${APP_NAME}registry"
IMAGE_SERVER=$IMAGE_SERVER_NAME.azurecr.io

az group create -n $APP_NAME -l $REGION

az deployment group create \
  -g $APP_NAME \
  -f ./infra/containerRegistry.bicep \
  --parameters "environmentName=$APP_NAME"

az acr login --name $IMAGE_SERVER_NAME

# API
docker build -t $IMAGE_API_REPOSITORY -f api/Dockerfile .
docker tag $IMAGE_API_REPOSITORY:$IMAGE_TAG $IMAGE_SERVER/$IMAGE_API_REPOSITORY:$IMAGE_TAG
docker push $IMAGE_SERVER/$IMAGE_API_REPOSITORY:$IMAGE_TAG

# Queue Worker
docker build -t $IMAGE_QUEUE_LISTENER_REPOSITORY -f queue-listener/Dockerfile .
docker tag $IMAGE_QUEUE_LISTENER_REPOSITORY:$IMAGE_TAG $IMAGE_SERVER/$IMAGE_QUEUE_LISTENER_REPOSITORY:$IMAGE_TAG
docker push $IMAGE_SERVER/$IMAGE_QUEUE_LISTENER_REPOSITORY:$IMAGE_TAG

az deployment group create \
  -g $APP_NAME \
  -f ./infra/basic.bicep \
  --parameters "environmentName=$APP_NAME" \
  "generationQueueName=$GENERATION_QUEUE_NAME" \
  "imageQueueName=$IMAGE_QUEUE_NAME" \
  "postprocessImageQueueName=$POSTPROCESS_IMAGE_QUEUE_NAME" \
  "weatherTableName=$WEATHER_TABLE_NAME" \
  "imageContainerName=$IMAGE_CONTAINER_NAME" \
  "targetPort=$API_PORT" \
  "apiAccessToken=$ACCESS_TOKEN"

# GitHub Actions deploy identity
DEPLOY_IDENTITY_NAME="${APP_NAME}deploy"
GITHUB_SUBJECT_PREFIX=$(gh api "repos/$GITHUB_REPOSITORY/actions/oidc/customization/sub" --jq .sub_claim_prefix)
GITHUB_SUBJECT="$GITHUB_SUBJECT_PREFIX:ref:refs/heads/main"

az identity create -g $APP_NAME -n $DEPLOY_IDENTITY_NAME -l $REGION --output none

EXISTING_CREDENTIAL=$(az identity federated-credential list \
  -g $APP_NAME \
  --identity-name $DEPLOY_IDENTITY_NAME \
  --query "[?subject=='$GITHUB_SUBJECT'].name" -o tsv)

if [ -z "$EXISTING_CREDENTIAL" ]; then
  az identity federated-credential create \
    -g $APP_NAME \
    --identity-name $DEPLOY_IDENTITY_NAME \
    --name github-main \
    --issuer https://token.actions.githubusercontent.com \
    --subject "$GITHUB_SUBJECT" \
    --audiences api://AzureADTokenExchange \
    --output none
fi

DEPLOY_PRINCIPAL_ID=$(az identity show -g $APP_NAME -n $DEPLOY_IDENTITY_NAME --query principalId -o tsv)
RESOURCE_GROUP_ID=$(az group show -n $APP_NAME --query id -o tsv)
REGISTRY_ID=$(az acr show -n $IMAGE_SERVER_NAME --query id -o tsv)

az role assignment create \
  --assignee-object-id "$DEPLOY_PRINCIPAL_ID" \
  --assignee-principal-type ServicePrincipal \
  --role Contributor \
  --scope "$RESOURCE_GROUP_ID" \
  --output none

az role assignment create \
  --assignee-object-id "$DEPLOY_PRINCIPAL_ID" \
  --assignee-principal-type ServicePrincipal \
  --role AcrPush \
  --scope "$REGISTRY_ID" \
  --output none

echo
echo "GitHub Actions secrets for $GITHUB_REPOSITORY:"
echo "  AZURE_CLIENT_ID=$(az identity show -g $APP_NAME -n $DEPLOY_IDENTITY_NAME --query clientId -o tsv)"
echo "  AZURE_TENANT_ID=$(az account show --query tenantId -o tsv)"
echo "  AZURE_SUBSCRIPTION_ID=$(az account show --query id -o tsv)"
