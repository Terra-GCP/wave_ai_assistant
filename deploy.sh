#!/usr/bin/env bash
set -e

# --------------------------
# Colors & Styles
# --------------------------
BOLD=$(tput bold)
RESET=$(tput sgr0)
GREEN=$(tput setaf 2)
BLUE=$(tput setaf 4)
YELLOW=$(tput setaf 3)
RED=$(tput setaf 1)
CYAN=$(tput setaf 6)
MAGENTA=$(tput setaf 5)
WHITE=$(tput setaf 7)

# --------------------------
# GCP Vars
# --------------------------
get_project_id() {
  local project_id=$(gcloud config get-value project 2>/dev/null)
  if [[ -z "$project_id" || "$project_id" == "(unset)" ]]; then
    echo "unknown"
  else
    echo "$project_id"
  fi
}

# Generate unique identifier to avoid naming conflicts when multiple users deploy
get_unique_identifier() {
  # Use logged-in user email or fallback to random string
  local user_email=$(gcloud config get-value account 2>/dev/null || echo "")
  if [[ -n "$user_email" ]]; then
    # Extract username part before @ and sanitize for GCP naming (lowercase, alphanumeric, max 8 chars)
    local username=$(echo "$user_email" | cut -d'@' -f1 | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]//g' | cut -c1-8)
    echo "$username"
  else
    # Fallback to random 6-character string
    echo $(openssl rand -hex 3 2>/dev/null || echo "$(date +%s)" | tail -c 7)
  fi
}

PROJECT_ID=$(get_project_id)
REGION="us-central1"
UNIQUE_ID=$(get_unique_identifier)
SERVICE_NAME="wave-ai-${UNIQUE_ID}"
REPO_NAME="wave-ai-repo"
SECRET_NAME="wave-ai-key-${UNIQUE_ID}"
IMAGE="us-central1-docker.pkg.dev/$PROJECT_ID/$REPO_NAME/$SERVICE_NAME:latest"

# Dedicated Cloud Run service account
CR_SA_NAME="wave-ai-run-sa-${UNIQUE_ID}"
CR_SA_EMAIL="$CR_SA_NAME@$PROJECT_ID.iam.gserviceaccount.com"

# --------------------------
# Header Banner
# --------------------------
banner() {
  clear
  echo ""
  echo "${MAGENTA}${BOLD}╔══════════════════════════════════════════════════════╗${RESET}"
  echo "${MAGENTA}${BOLD}║${RESET}   🌊 ${CYAN}${BOLD}Wave AI Deployment Manager${RESET}               ${MAGENTA}${BOLD}║${RESET}"
  echo "${MAGENTA}${BOLD}╚══════════════════════════════════════════════════════╝${RESET}"
  echo ""
  echo "${YELLOW}${BOLD}Active Project:${RESET} $PROJECT_ID"
  echo "${YELLOW}${BOLD}Default Region:${RESET} $REGION"
  echo "${YELLOW}${BOLD}Unique ID:${RESET} $UNIQUE_ID (avoids naming conflicts)"
  echo ""
}

# --------------------------
# Validate Auth & Project
# --------------------------
validate_env() {
  if ! gcloud auth list --format="value(account)" | grep -q "@"; then
    echo "${RED}${BOLD}❌ ERROR:${RESET} No gcloud account authenticated!"
    echo "Run: ${CYAN}gcloud auth login${RESET}"
    exit 1
  fi

  if [[ "$PROJECT_ID" == "unknown" ]]; then
    echo "${YELLOW}${BOLD}⚠️  WARNING:${RESET} No active GCP project set!"
    echo ""
    echo "Would you like to:"
    echo "  ${GREEN}1)${RESET} Set a project interactively"
    echo "  ${GREEN}2)${RESET} Exit and set manually"
    echo ""
    read -p "👉 Enter your choice (1/2): " project_choice
    
    case $project_choice in
      1)
        select_project_interactive
        ;;
      2)
        echo "Please run: ${CYAN}gcloud config set project YOUR_PROJECT_ID${RESET}"
        exit 1
        ;;
      *)
        echo "${RED}❌ Invalid choice!${RESET}"
        exit 1
        ;;
    esac
  fi
}

# --------------------------
# Interactive Project Selection
# --------------------------
select_project_interactive() {
  echo ""
  echo "${BLUE}${BOLD}🔍 Available Projects:${RESET}"
  
  # Get available projects
  local projects=$(gcloud projects list --format="value(projectId)" --filter="lifecycleState=ACTIVE" 2>/dev/null)
  
  if [[ -z "$projects" ]]; then
    echo "${RED}${BOLD}❌ ERROR:${RESET} No accessible projects found!"
    echo "Make sure you have the necessary permissions or create a new project."
    exit 1
  fi
  
  # Display projects with numbers
  local project_array=()
  local i=1
  while IFS= read -r project; do
    echo "  ${GREEN}$i)${RESET} $project"
    project_array+=("$project")
    ((i++))
  done <<< "$projects"
  
  echo ""
  read -p "👉 Select project number: " selection
  
  # Validate selection
  if ! [[ "$selection" =~ ^[0-9]+$ ]] || [[ $selection -lt 1 ]] || [[ $selection -gt ${#project_array[@]} ]]; then
    echo "${RED}${BOLD}❌ ERROR:${RESET} Invalid selection!"
    exit 1
  fi
  
  # Set the selected project
  local selected_project="${project_array[$((selection-1))]}"
  echo ""
  echo -n "Setting project to $selected_project ... "
  
  if gcloud config set project "$selected_project" >/dev/null 2>&1; then
    echo "✅ Done"
    PROJECT_ID="$selected_project"
    # Update dependent variables
    IMAGE="us-central1-docker.pkg.dev/$PROJECT_ID/$REPO_NAME/$SERVICE_NAME:latest"
    CR_SA_EMAIL="$CR_SA_NAME@$PROJECT_ID.iam.gserviceaccount.com"
    echo "Project successfully set to: ${CYAN}${BOLD}$PROJECT_ID${RESET}"
  else
    echo "${RED}${BOLD}❌ ERROR:${RESET} Failed to set project!"
    exit 1
  fi
  echo ""
}

# --------------------------
# Resource Checking Functions
# --------------------------
check_apis_enabled() {
  local apis_needed=(run.googleapis.com artifactregistry.googleapis.com cloudbuild.googleapis.com secretmanager.googleapis.com iam.googleapis.com)
  
  # Get the list of enabled APIs once and cache it
  local enabled_apis=$(gcloud services list --enabled --format="value(name)" 2>/dev/null)
  
  for api in "${apis_needed[@]}"; do
    if ! echo "$enabled_apis" | grep -q "/$api$"; then
      return 1  # Some APIs not enabled
    fi
  done
  
  return 0  # All APIs enabled
}

check_artifact_registry() {
  gcloud artifacts repositories describe $REPO_NAME --location=$REGION >/dev/null 2>&1
}

check_secret_exists() {
  gcloud secrets describe $SECRET_NAME >/dev/null 2>&1
}

check_service_account() {
  gcloud iam service-accounts describe $CR_SA_EMAIL >/dev/null 2>&1
}

check_cloud_run_service() {
  gcloud run services describe $SERVICE_NAME --region $REGION >/dev/null 2>&1
}

check_docker_image() {
  gcloud artifacts docker images describe $IMAGE >/dev/null 2>&1
}

# --------------------------
# Deployment Status Overview
# --------------------------
show_deployment_status() {
  echo ""
  echo "${WHITE}${BOLD}📊 Current Deployment Status:${RESET}"
  echo ""
  
  # APIs
  if check_apis_enabled; then
    echo "   🔌 ${GREEN}APIs:${RESET}              ✅ Enabled"
  else
    echo "   🔌 ${RED}APIs:${RESET}              ❌ Not all enabled"
  fi
  
  # Artifact Registry
  if check_artifact_registry; then
    echo "   📦 ${GREEN}Artifact Registry:${RESET} ✅ Repository exists"
  else
    echo "   📦 ${RED}Artifact Registry:${RESET} ❌ Repository missing"
  fi
  
  # Secret
  if check_secret_exists; then
    echo "   🔑 ${GREEN}Secret Manager:${RESET}    ✅ API key stored"
  else
    echo "   🔑 ${RED}Secret Manager:${RESET}    ❌ API key missing"
  fi
  
  # Service Account
  if check_service_account; then
    echo "   👤 ${GREEN}Service Account:${RESET}   ✅ Configured"
  else
    echo "   👤 ${RED}Service Account:${RESET}   ❌ Missing"
  fi
  
  # Docker Image
  if check_docker_image; then
    echo "   🐳 ${GREEN}Docker Image:${RESET}      ✅ Built and pushed"
  else
    echo "   🐳 ${RED}Docker Image:${RESET}      ❌ Not found"
  fi
  
  # Cloud Run Service
  if check_cloud_run_service; then
    SERVICE_URL=$(gcloud run services describe $SERVICE_NAME --region $REGION --format="value(status.url)" 2>/dev/null)
    echo "   🚢 ${GREEN}Cloud Run:${RESET}         ✅ Deployed"
    echo "      ${CYAN}URL: $SERVICE_URL${RESET}"
  else
    echo "   🚢 ${RED}Cloud Run:${RESET}         ❌ Not deployed"
  fi
  echo ""
}

# --------------------------
# Simple Menu System
# --------------------------
main_menu() {
  echo "${BLUE}${BOLD}🌊 Wave AI Deployment Manager:${RESET}"
  echo ""
  echo "     ${GREEN}1)${RESET} 🚀 Create/Update    ${CYAN}(Smart deploy/update)${RESET}"
  echo "     ${YELLOW}2)${RESET} ⚡ Update Code      ${CYAN}(Rebuild & deploy image only)${RESET}"
  echo "     ${BLUE}3)${RESET} 📋 Show Status      ${CYAN}(Check deployment status)${RESET}"
  echo "     ${RED}4)${RESET} 🗑️  Destroy All      ${CYAN}(Delete all resources)${RESET}"
  echo ""
  echo "     ${RED}q)${RESET} ❌ Quit"
  echo ""
  read -p "👉 Select option (1-4/q): " choice
}

# --------------------------
# Helper: Grant IAM role (clean output)
# --------------------------
grant_role() {
  local member="$1"
  local role="$2"
  
  echo -n "🔑 Granting ${role} to ${member} ... "
  gcloud projects add-iam-policy-binding "$PROJECT_ID" \
      --member="$member" \
      --role="$role" \
      --quiet >/dev/null 2>&1
  echo "✅ Done"
}

grant_secret_role() {
  local member="$1"
  local role="$2"

  echo -n "🔑 Granting ${role} to ${member} on secret ${SECRET_NAME} ... "
  gcloud secrets add-iam-policy-binding "$SECRET_NAME" \
      --member="$member" \
      --role="$role" \
      --quiet >/dev/null 2>&1
  echo "✅ Done"
}

# --------------------------
# Individual Setup Functions
# --------------------------
setup_apis() {
  if check_apis_enabled; then
    echo "🔌 APIs ✅"
    return 0
  fi
  
  echo "🔌 Enabling required APIs..."
  APIS=(run.googleapis.com artifactregistry.googleapis.com cloudbuild.googleapis.com secretmanager.googleapis.com iam.googleapis.com)
  for api in "${APIS[@]}"; do
      gcloud services enable "$api" --quiet >/dev/null 2>&1
  done
  echo "🔌 APIs ✅"
}

setup_artifact_registry() {
  if check_artifact_registry; then
    echo "📦 Artifact Registry ✅"
    return 0
  fi
  
  echo "📦 Creating Artifact Registry..."
  if gcloud artifacts repositories create $REPO_NAME \
    --repository-format=docker \
    --location=$REGION \
    --description="Wave AI Assistant Repository" \
    --quiet >/dev/null 2>&1; then
    echo "📦 Artifact Registry ✅"
  else
    echo "${RED}❌ Failed to create Artifact Registry repository!${RESET}"
    exit 1
  fi
}

setup_docker_auth() {
  echo "🔐 Configuring Docker authentication..."
  if gcloud auth configure-docker $REGION-docker.pkg.dev --quiet >/dev/null 2>&1; then
    echo "🔐 Docker authentication ✅"
  else
    echo "${RED}❌ Failed to configure Docker authentication!${RESET}"
    exit 1
  fi
}

setup_secret_manager() {
  if check_secret_exists; then
    echo "🔑 Secret Manager ✅"
    return 0
  fi
  
  echo "🔑 Setting up Secret Manager..."
  read -sp "🔑 Enter your Wave AI API Key (Gemini): " API_KEY
  echo ""
  
  if [[ -z "$API_KEY" ]]; then
    echo "${RED}❌ API key cannot be empty!${RESET}"
    exit 1
  fi

  # Basic API key validation
  if [[ ! "$API_KEY" =~ ^AIza[A-Za-z0-9_-]{35}$ ]]; then
    echo "${YELLOW}⚠️  API key format warning - continuing anyway...${RESET}"
  fi
  
  echo -n "$API_KEY" | gcloud secrets create $SECRET_NAME \
    --replication-policy="automatic" \
    --data-file=- \
    --project $PROJECT_ID >/dev/null 2>&1
  echo "🔑 Secret Manager ✅"
}

setup_service_account() {
  if check_service_account; then
    echo "👤 Service Account ✅"
  else
    echo "👤 Creating Service Account..."
    gcloud iam service-accounts create $CR_SA_NAME --display-name "Cloud Run SA for Wave AI Assistant" >/dev/null 2>&1
    echo "👤 Service Account ✅"
  fi

  # Always ensure roles are granted (silently)
  echo "🔑 Configuring IAM roles..."
  PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format="value(projectNumber)" 2>/dev/null)
  CLOUD_BUILD_SA="$PROJECT_NUMBER@cloudbuild.gserviceaccount.com"
  
  # Grant roles silently
  gcloud secrets add-iam-policy-binding "$SECRET_NAME" \
      --member="serviceAccount:$CR_SA_EMAIL" \
      --role="roles/secretmanager.secretAccessor" \
      --quiet >/dev/null 2>&1
  gcloud projects add-iam-policy-binding "$PROJECT_ID" \
      --member="serviceAccount:$CLOUD_BUILD_SA" \
      --role="roles/run.developer" \
      --quiet >/dev/null 2>&1
  gcloud projects add-iam-policy-binding "$PROJECT_ID" \
      --member="serviceAccount:$CLOUD_BUILD_SA" \
      --role="roles/iam.serviceAccountUser" \
      --quiet >/dev/null 2>&1
  gcloud projects add-iam-policy-binding "$PROJECT_ID" \
      --member="serviceAccount:$CLOUD_BUILD_SA" \
      --role="roles/artifactregistry.writer" \
      --quiet >/dev/null 2>&1
  
  echo "🔑 IAM roles ✅"
}

build_and_push_image() {
  echo "🔨 Building Docker image..."
  if gcloud builds submit --tag $IMAGE --project $PROJECT_ID --quiet >/dev/null 2>&1; then
    echo "🔨 Docker image ✅"
  else
    echo "${RED}❌ Failed to build Docker image!${RESET}"
    exit 1
  fi
}

deploy_to_cloud_run() {
  echo "🚢 Deploying to Cloud Run..."
  if gcloud run deploy $SERVICE_NAME \
      --image $IMAGE \
      --region $REGION \
      --service-account $CR_SA_EMAIL \
      --allow-unauthenticated \
      --set-secrets GEMINI_API_KEY=$SECRET_NAME:latest \
      --memory=512Mi \
      --cpu=1000m \
      --max-instances=10 \
      --timeout=300 \
      --quiet >/dev/null 2>&1; then
    echo "🚢 Cloud Run ✅"
  else
    echo "${RED}❌ Failed to deploy to Cloud Run!${RESET}"
    exit 1
  fi
}

show_deployment_success() {
  echo ""
  echo "${GREEN}${BOLD}🎉 Wave AI Deployed Successfully!${RESET}"
  SERVICE_URL=$(gcloud run services describe $SERVICE_NAME --region $REGION --format="value(status.url)" 2>/dev/null)
  echo ""
  echo "🌐 ${BOLD}Your Wave AI is live at:${RESET}"
  echo "   ${CYAN}${BOLD}$SERVICE_URL${RESET}"
  echo ""
}

# --------------------------
# Main Deployment Functions
# --------------------------
smart_create_update() {
  # Check if Dockerfile exists
  if [[ ! -f "Dockerfile" ]]; then
    echo "${RED}${BOLD}❌ ERROR:${RESET} Dockerfile not found in current directory!"
    exit 1
  fi
  
  echo "${BLUE}${BOLD}🚀 Smart Create/Update Starting...${RESET}"
  echo "${CYAN}Checking requirements and proceeding...${RESET}"
  echo ""
  
  setup_apis
  setup_artifact_registry
  setup_docker_auth
  setup_secret_manager
  setup_service_account
  build_and_push_image
  deploy_to_cloud_run
  show_deployment_success
}

update_code_only() {
  # Check if Dockerfile exists
  if [[ ! -f "Dockerfile" ]]; then
    echo "${RED}${BOLD}❌ ERROR:${RESET} Dockerfile not found in current directory!"
    exit 1
  fi
  
  if ! check_cloud_run_service; then
    echo "${RED}${BOLD}❌ ERROR:${RESET} No Wave AI service found!"
    echo "Run 'Create/Update' first to set up the infrastructure."
    exit 1
  fi
  
  echo "${BLUE}${BOLD}⚡ Updating Code Only...${RESET}"
  echo "${CYAN}Rebuilding and deploying latest code${RESET}"
  echo ""
  
  build_and_push_image
  deploy_to_cloud_run
  show_deployment_success
}

# --------------------------
# Resource Cleanup Functions
# --------------------------
destroy_resources() {
  echo "${GREEN}${BOLD}🗑️  Starting Resource Cleanup...${RESET}"
  echo ""

  echo "${GREEN}${BOLD}🗑️  Deleting Cloud Run service...${RESET}"
  if gcloud run services describe $SERVICE_NAME --region $REGION >/dev/null 2>&1; then
    echo -n "Deleting Cloud Run service ... "
    gcloud run services delete $SERVICE_NAME --region $REGION --quiet && echo "✅ Done" || echo "⚠️  Failed"
  else
    echo "Cloud Run service not found ✅"
  fi
  echo ""

  echo "${GREEN}${BOLD}🗑️  Deleting Artifact Registry repo...${RESET}"
  if gcloud artifacts repositories describe $REPO_NAME --location=$REGION >/dev/null 2>&1; then
    echo -n "Deleting Artifact Registry repository ... "
    gcloud artifacts repositories delete $REPO_NAME --location=$REGION --quiet && echo "✅ Done" || echo "⚠️  Failed"
  else
    echo "Artifact Registry repository not found ✅"
  fi
  echo ""

  echo "${GREEN}${BOLD}🗑️  Deleting Secret Manager secret...${RESET}"
  if gcloud secrets describe $SECRET_NAME >/dev/null 2>&1; then
    echo -n "Deleting secret ... "
    gcloud secrets delete $SECRET_NAME --quiet && echo "✅ Done" || echo "⚠️  Failed"
  else
    echo "Secret not found ✅"
  fi
  echo ""

  echo "${GREEN}${BOLD}🗑️  Deleting Cloud Run Service Account...${RESET}"
  if gcloud iam service-accounts describe $CR_SA_EMAIL >/dev/null 2>&1; then
    echo -n "Deleting service account ... "
    gcloud iam service-accounts delete $CR_SA_EMAIL --quiet && echo "✅ Done" || echo "⚠️  Failed"
  else
    echo "Service account not found ✅"
  fi
  echo ""

  echo "${GREEN}${BOLD}✅ Cleanup complete!${RESET}"
  echo ""
}

destroy_all() {
  echo ""
  echo "${RED}${BOLD}🗑️  DESTROYING ALL RESOURCES${RESET}"
  echo "${YELLOW}Removing all Wave AI resources from Google Cloud...${RESET}"
  echo ""
  
  destroy_resources
}

# --------------------------
# Main Flow
# --------------------------
main() {
  banner
  validate_env
  
  # Show status only once at startup
  echo "${CYAN}${BOLD}🔍 Checking deployment status...${RESET}"
  show_deployment_status
  
  while true; do
    main_menu
    
    case $choice in
      1) 
        smart_create_update 
        read -p "Press Enter to continue..."
        clear
        banner
        ;;
      2) 
        update_code_only 
        read -p "Press Enter to continue..."
        clear
        banner
        ;;
      3) 
        echo "${CYAN}${BOLD}🔍 Refreshing deployment status...${RESET}"
        show_deployment_status
        read -p "Press Enter to continue..."
        clear
        banner
        ;;
      4) 
        destroy_all 
        read -p "Press Enter to continue..."
        clear
        banner
        echo "${CYAN}All resources have been removed.${RESET}"
        echo ""
        ;;
      q|Q) 
        echo "👋 Exiting Wave AI Deployment Manager..."
        echo ""
        exit 0 
        ;;
      *) 
        echo "${RED}❌ Invalid choice! Please select 1-4 or q.${RESET}"
        read -p "Press Enter to continue..."
        clear
        banner
        ;;
    esac
    
    echo ""
  done
}

# Run the main function
main