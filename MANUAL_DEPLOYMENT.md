# 🛠️ Manual Deployment Guide

## Prerequisites
```bash
# Install gcloud CLI and authenticate
gcloud auth login
gcloud config set project YOUR_PROJECT_ID
```

## Step 1: Enable APIs
```bash
gcloud services enable run.googleapis.com
gcloud services enable cloudbuild.googleapis.com
gcloud services enable artifactregistry.googleapis.com
gcloud services enable secretmanager.googleapis.com
```

## Step 2: Create Artifact Registry
```bash
gcloud artifacts repositories create wave-ai \
  --repository-format=docker \
  --location=us-central1
```

## Step 3: Store API Key
```bash
echo "YOUR_GEMINI_API_KEY" | gcloud secrets create gemini-api-key --data-file=-
```

## Step 4: Create Service Account
```bash
gcloud iam service-accounts create wave-ai-sa

gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
  --member="serviceAccount:wave-ai-sa@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor"
```

## Step 5: Build & Push Docker Image
```bash
# Configure Docker auth
gcloud auth configure-docker us-central1-docker.pkg.dev

# Build image
docker build -t us-central1-docker.pkg.dev/YOUR_PROJECT_ID/wave-ai/app:latest .

# Push image
docker push us-central1-docker.pkg.dev/YOUR_PROJECT_ID/wave-ai/app:latest
```

## Step 6: Deploy to Cloud Run
```bash
gcloud run deploy wave-ai-YOUR_UNIQUE_ID \
  --image=us-central1-docker.pkg.dev/YOUR_PROJECT_ID/wave-ai/app:latest \
  --platform=managed \
  --region=us-central1 \
  --allow-unauthenticated \
  --service-account=wave-ai-sa@YOUR_PROJECT_ID.iam.gserviceaccount.com \
  --set-env-vars="GOOGLE_CLOUD_PROJECT=YOUR_PROJECT_ID"
```

## Step 7: Get URL
```bash
gcloud run services describe wave-ai-YOUR_UNIQUE_ID \
  --region=us-central1 \
  --format="value(status.url)"
```

## 🔧 Troubleshooting

**Container fails to start:**
```bash
# Check logs
gcloud logs tail --service=wave-ai-YOUR_UNIQUE_ID
```

**Permission denied:**
```bash
# Check service account permissions
gcloud projects get-iam-policy YOUR_PROJECT_ID
```

**API key not found:**
```bash
# Verify secret exists
gcloud secrets versions list gemini-api-key
```

## 🗑️ Cleanup
```bash
# Delete Cloud Run service
gcloud run services delete wave-ai-YOUR_UNIQUE_ID --region=us-central1

# Delete Docker images
gcloud artifacts repositories delete wave-ai --location=us-central1

# Delete secrets
gcloud secrets delete gemini-api-key

# Delete service account
gcloud iam service-accounts delete wave-ai-sa@YOUR_PROJECT_ID.iam.gserviceaccount.com
```
