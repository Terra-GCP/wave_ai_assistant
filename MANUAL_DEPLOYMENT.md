# 🛠️ Manual Deployment Guide

## 🏗️ Environment Setup
Set these environment variables first to avoid issues later:

```bash
# Set your project details
export PROJECT_ID="your-gcp-project-id"
export REGION="us-central1"
# Generate unique ID from gcloud account (matching deploy.sh logic)
USER_EMAIL=$(gcloud config get-value account 2>/dev/null || echo "")
if [[ -n "$USER_EMAIL" ]]; then
  export UNIQUE_ID="$(echo "$USER_EMAIL" | cut -d'@' -f1 | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]//g' | cut -c1-8)"
else
  export UNIQUE_ID="$(whoami | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]//g' | cut -c1-8)"
fi

# Single naming pattern for ALL resources: wave-ai-${UNIQUE_ID} (matching deploy.sh script)
export RESOURCE_NAME="wave-ai-${UNIQUE_ID}"
export IMAGE="us-central1-docker.pkg.dev/${PROJECT_ID}/${RESOURCE_NAME}/app:latest"

echo "📋 Your deployment configuration:"
echo "  Project ID: $PROJECT_ID"
echo "  Unique ID: $UNIQUE_ID"
echo "  Resource Name: $RESOURCE_NAME (used for all resources)"
```

## Prerequisites
```bash
# Install gcloud CLI and authenticate
gcloud auth login
gcloud config set project $PROJECT_ID
```

## Step 1: Enable APIs
```bash
gcloud services enable run.googleapis.com
gcloud services enable cloudbuild.googleapis.com
gcloud services enable artifactregistry.googleapis.com
gcloud services enable secretmanager.googleapis.com
```

## Step 2: Store API Key
```bash
echo -n "YOUR_GEMINI_API_KEY" | gcloud secrets create $RESOURCE_NAME --data-file=-

# Grant default compute service account access to the secret
PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format="value(projectNumber)")
COMPUTE_SA="${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"

gcloud secrets add-iam-policy-binding $RESOURCE_NAME \
    --member="serviceAccount:$COMPUTE_SA" \
    --role="roles/secretmanager.secretAccessor"
```

## Step 3: Create Artifact Registry
```bash
gcloud artifacts repositories create $RESOURCE_NAME \
  --repository-format=docker \
  --location=$REGION
```

## Step 4: Build & Push Docker Image
```bash
# Configure Docker auth
gcloud auth configure-docker ${REGION}-docker.pkg.dev

# Build image (use --no-cache if needed)
docker build -t $IMAGE .

# Push image
docker push $IMAGE
```

## Step 5: Deploy to Cloud Run
```bash
gcloud run deploy $RESOURCE_NAME \
  --image=$IMAGE \
  --platform=managed \
  --region=$REGION \
  --allow-unauthenticated \
  --set-secrets="GEMINI_API_KEY=${RESOURCE_NAME}:latest" \
  --set-env-vars="GOOGLE_CLOUD_PROJECT=$PROJECT_ID" \
  --memory=1Gi \
  --cpu=1000m \
  --concurrency=80 \
  --execution-environment=gen2
```

## Step 6: Get URL
```bash
gcloud run services describe $RESOURCE_NAME \
  --region=$REGION \
  --format="value(status.url)"
```

## 🔧 Troubleshooting

**Container fails to start:**
```bash
# Check logs
gcloud logs tail --service=$RESOURCE_NAME
```

**Permission denied:**
```bash
# Check if you have necessary permissions  
gcloud auth list
gcloud config get-value account
```

**API key not found:**
```bash
# Verify secret exists
gcloud secrets versions list $RESOURCE_NAME
```

**Docker build fails:**
```bash
# Build with verbose output
docker build -t $IMAGE . --no-cache --progress=plain

# Check available space
df -h
```

## 🗑️ Cleanup
```bash
# Delete Cloud Run service (auto-approved, no prompts)
gcloud run services delete $RESOURCE_NAME --region=$REGION --quiet
# Delete Docker images
gcloud artifacts repositories delete $RESOURCE_NAME --location=$REGION --quiet
# Delete secrets
gcloud secrets delete $RESOURCE_NAME --quiet 
```