#!/bin/bash

# 🌊 Wave AI - Lightweight Cloud Run Deployer
set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# Configuration
readonly REGION="us-central1"

# Get dynamic values
get_unique_id() {
    local user_email=$(timeout 5 gcloud config get-value account 2>/dev/null || echo "")
    if [[ -n "$user_email" ]]; then
        local username=$(echo "$user_email" | cut -d'@' -f1 | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]//g' | cut -c1-8)
        echo "$username"
    else
        whoami | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]//g' | cut -c1-8
    fi
}

PROJECT_ID=$(timeout 5 gcloud config get-value project 2>/dev/null || echo "")
UNIQUE_ID=$(get_unique_id)

# Single naming pattern for ALL resources: wave-ai-${UNIQUE_ID}
readonly RESOURCE_NAME="wave-ai-${UNIQUE_ID}"

# Validation
if [[ -z "$PROJECT_ID" ]]; then
    echo -e "${RED}❌ No active GCP project found${RESET}"
    echo -e "${CYAN}💡 Run: gcloud config set project YOUR_PROJECT_ID${RESET}"
    exit 1
fi

# Banner
echo -e "${BLUE}${BOLD}🌊 Wave AI Deployer${RESET} ${CYAN}($PROJECT_ID)${RESET}"
echo ""

# Setup secret
setup_secret() {
    echo -e "${YELLOW}🔐 Setting up API key...${RESET}"
    
    if gcloud secrets describe "$RESOURCE_NAME" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Secret already exists${RESET}"
        
        # Grant compute service account access
        local project_number=$(gcloud projects describe "$PROJECT_ID" --format="value(projectNumber)")
        local compute_sa="${project_number}-compute@developer.gserviceaccount.com"
        
        gcloud secrets add-iam-policy-binding "$RESOURCE_NAME" \
            --member="serviceAccount:$compute_sa" \
            --role="roles/secretmanager.secretAccessor" 2>/dev/null || true
        echo -e "${GREEN}✅ Secret permissions verified${RESET}"
        return
    fi
    
    echo -e "${CYAN}Enter your Gemini API key:${RESET}"
    read -s -p "🔑 API Key: " api_key
    echo ""
    
    if [[ -z "$api_key" ]]; then
        echo -e "${RED}❌ No API key provided${RESET}"
        exit 1
    fi
    
    echo -e "${YELLOW}🔐 Creating secret...${RESET}"
    if echo -n "$api_key" | gcloud secrets create "$RESOURCE_NAME" --data-file=-; then
        echo -e "${GREEN}✅ API key stored securely${RESET}"
        
        # Grant compute service account access
        local project_number=$(gcloud projects describe "$PROJECT_ID" --format="value(projectNumber)")
        local compute_sa="${project_number}-compute@developer.gserviceaccount.com"
        
        if gcloud secrets add-iam-policy-binding "$RESOURCE_NAME" \
            --member="serviceAccount:$compute_sa" \
            --role="roles/secretmanager.secretAccessor"; then
            echo -e "${GREEN}✅ Secret access granted${RESET}"
        fi
    else
        echo -e "${RED}❌ Failed to store API key${RESET}"
        exit 1
    fi
}

# Deploy function
deploy_wave_ai() {
    echo -e "${YELLOW}🚀 Deploying Wave AI...${RESET}"
    echo ""
    
    # Enable APIs
    local apis=("run.googleapis.com" "cloudbuild.googleapis.com" "artifactregistry.googleapis.com" "secretmanager.googleapis.com")
    echo -e "${CYAN}Checking APIs...${RESET}"
    for api in "${apis[@]}"; do
        if ! gcloud services list --enabled --filter="name:$api" --format="value(name)" 2>/dev/null | grep -q "$api"; then
            echo -e "${YELLOW}Enabling $api...${RESET}"
            gcloud services enable "$api"
        fi
    done
    echo -e "${GREEN}✅ All APIs ready${RESET}"
    
    # Setup secret
    setup_secret
    
    # Grant Cloud Build permissions to compute service account
    echo -e "${CYAN}Setting up Cloud Build permissions...${RESET}"
    local project_number=$(gcloud projects describe "$PROJECT_ID" --format="value(projectNumber)")
    local compute_sa="${project_number}-compute@developer.gserviceaccount.com"
    
    # Grant Cloud Build Editor role
    if gcloud projects add-iam-policy-binding "$PROJECT_ID" \
        --member="serviceAccount:$compute_sa" \
        --role="roles/cloudbuild.builds.editor" --quiet; then
        echo -e "${GREEN}✅ Cloud Build permissions granted${RESET}"
    else
        echo -e "${YELLOW}⚠️  Cloud Build permissions already set${RESET}"
    fi
    
    # Grant Storage Admin role for Cloud Build staging
    if gcloud projects add-iam-policy-binding "$PROJECT_ID" \
        --member="serviceAccount:$compute_sa" \
        --role="roles/storage.admin" --quiet; then
        echo -e "${GREEN}✅ Storage permissions granted${RESET}"
    else
        echo -e "${YELLOW}⚠️  Storage permissions already set${RESET}"
    fi
    
    # Create artifact registry
    if ! gcloud artifacts repositories describe "$RESOURCE_NAME" --location="$REGION" >/dev/null 2>&1; then
        echo -e "${CYAN}Creating artifact registry...${RESET}"
        gcloud artifacts repositories create "$RESOURCE_NAME" \
            --repository-format=docker \
            --location="$REGION"
        echo -e "${GREEN}✅ Artifact registry created${RESET}"
    else
        echo -e "${GREEN}✅ Artifact registry ready${RESET}"
    fi
    
    # Build and deploy
    echo -e "${CYAN}Building container...${RESET}"
    gcloud builds submit --tag="${REGION}-docker.pkg.dev/$PROJECT_ID/$RESOURCE_NAME/app:latest"
    echo -e "${GREEN}✅ Container built${RESET}"
    
    echo -e "${CYAN}Deploying to Cloud Run...${RESET}"
    if gcloud run deploy "$RESOURCE_NAME" \
        --image="${REGION}-docker.pkg.dev/$PROJECT_ID/$RESOURCE_NAME/app:latest" \
        --platform=managed \
        --region="$REGION" \
        --allow-unauthenticated \
        --set-secrets="GEMINI_API_KEY=${RESOURCE_NAME}:latest" \
        --set-env-vars="GOOGLE_CLOUD_PROJECT=$PROJECT_ID" \
        --memory=1Gi \
        --cpu=1000m \
        --concurrency=80 \
        --execution-environment=gen2 \
        --timeout=300; then
        echo -e "${GREEN}✅ Cloud Run deployment successful${RESET}"
    else
        echo -e "${RED}❌ Deployment failed${RESET}"
        exit 1
    fi
    
    # Get URL and show success
    local url=$(gcloud run services describe "$RESOURCE_NAME" --region="$REGION" --format="value(status.url)" 2>/dev/null)
    
    echo ""
    echo -e "${GREEN}${BOLD}🎉 Wave AI deployed successfully!${RESET}"
    echo ""
    echo -e "${CYAN}${BOLD}📋 Deployment Details:${RESET}"
    echo -e "   ${YELLOW}Project:${RESET}        ${BOLD}$PROJECT_ID${RESET}"
    echo -e "   ${YELLOW}Unique ID:${RESET}      ${BOLD}$UNIQUE_ID${RESET}"  
    echo -e "   ${YELLOW}Service Name:${RESET}   ${BOLD}$RESOURCE_NAME${RESET}"
    echo -e "   ${YELLOW}Live URL:${RESET}       ${GREEN}${BOLD}$url${RESET}"
    echo ""
    echo -e "${BLUE}🔗 Quick Access: ${CYAN}$url${RESET}"
    echo ""
}

# Function to show status  
show_status() {
    echo -e "${YELLOW}📊 Deployment Status${RESET}"
    echo ""
    echo -e "${CYAN}${BOLD}📋 Configuration:${RESET}"
    echo -e "   ${YELLOW}Project:${RESET}        ${BOLD}$PROJECT_ID${RESET}"
    echo -e "   ${YELLOW}Unique ID:${RESET}      ${BOLD}$UNIQUE_ID${RESET}"  
    echo -e "   ${YELLOW}Service Name:${RESET}   ${BOLD}$RESOURCE_NAME${RESET}"
    echo -e "   ${YELLOW}Region:${RESET}         ${BOLD}$REGION${RESET}"
    echo ""
    
    # Check Cloud Run status
    local url=$(gcloud run services describe "$RESOURCE_NAME" --region="$REGION" --format="value(status.url)" 2>/dev/null || echo "")
    if [[ -n "$url" ]]; then
        echo -e "${GREEN}${BOLD}✅ DEPLOYED & RUNNING${RESET}"
        echo -e "   ${YELLOW}Live URL:${RESET}       ${GREEN}${BOLD}$url${RESET}"
        echo ""
        echo -e "${BLUE}🔗 Quick Access: ${CYAN}$url${RESET}"
    else
        if gcloud run services describe "$RESOURCE_NAME" --region="$REGION" >/dev/null 2>&1; then
            echo -e "${YELLOW}⚠️  DEPLOYED BUT NOT READY${RESET}"
            echo -e "${YELLOW}💡 Check logs: gcloud logs tail --service=$RESOURCE_NAME --region=$REGION${RESET}"
        else
            echo -e "${RED}❌ NOT DEPLOYED${RESET}"
            echo -e "${YELLOW}💡 Run option 1 to deploy Wave AI${RESET}"
        fi
    fi
    echo ""
}

# Destroy resources
destroy_resources() {
    echo -e "${RED}${BOLD}🗑️  Destroying Wave AI resources...${RESET}"
    echo ""
    
    # Delete Cloud Run service
    if gcloud run services describe "$RESOURCE_NAME" --region="$REGION" >/dev/null 2>&1; then
        echo -e "${YELLOW}Deleting Cloud Run service...${RESET}"
        gcloud run services delete "$RESOURCE_NAME" --region="$REGION" --quiet
        echo -e "${GREEN}✅ Cloud Run service deleted${RESET}"
    fi
    
    # Delete artifact registry
    if gcloud artifacts repositories describe "$RESOURCE_NAME" --location="$REGION" >/dev/null 2>&1; then
        echo -e "${YELLOW}Deleting artifact registry...${RESET}"
        gcloud artifacts repositories delete "$RESOURCE_NAME" --location="$REGION" --quiet
        echo -e "${GREEN}✅ Artifact registry deleted${RESET}"
    fi
    
    # Delete secret
    if gcloud secrets describe "$RESOURCE_NAME" >/dev/null 2>&1; then
        echo -e "${YELLOW}Deleting secret...${RESET}"
        gcloud secrets delete "$RESOURCE_NAME" --quiet
        echo -e "${GREEN}✅ Secret deleted${RESET}"
    fi
    
    echo ""
    echo -e "${GREEN}${BOLD}✅ All resources destroyed${RESET}"
}

# Main menu
show_menu() {
    echo -e "${BOLD}Options for ${CYAN}$UNIQUE_ID${RESET}${BOLD}:${RESET}"
    echo ""
    echo -e "  ${GREEN}1)${RESET} 🚀 Deploy Wave AI    ${CYAN}(Idempotent)${RESET}"
    echo -e "  ${BLUE}2)${RESET} 📊 Show Status"
    echo -e "  ${RED}3)${RESET} 🗑️  Destroy All"
    echo -e "  ${YELLOW}q)${RESET} ❌ Quit"
    echo ""
}

# Main execution - single action, then exit
main() {
    show_menu
    read -p "👉 Choice (1-3/q): " choice
    echo ""
    
    case "$choice" in
        1)
            deploy_wave_ai
            ;;
        2)
            show_status
            ;;
        3)
            destroy_resources
            ;;
        q|Q)
            echo -e "${YELLOW}👋 Goodbye!${RESET}"
            exit 0
            ;;
        *)
            echo -e "${RED}❌ Invalid choice!${RESET}"
            exit 1
            ;;
    esac
}

# Run the script
main