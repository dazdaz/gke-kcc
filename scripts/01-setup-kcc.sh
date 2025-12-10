#!/bin/bash
# CloudSnap KCC Demo - GKE Cluster Setup Script
# This script creates a GKE Autopilot cluster with Config Connector enabled

set -euo pipefail

# Configuration
PROJECT_ID="${PROJECT_ID:-$(gcloud config get-value project)}"
REGION="${REGION:-us-central1}"
CLUSTER_NAME="${CLUSTER_NAME:-cloudsnap-cluster}"
KCC_NAMESPACE="${KCC_NAMESPACE:-cloudsnap}"
VERBOSE="${VERBOSE:-true}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_cmd() {
    echo -e "${YELLOW}[CMD]${NC} $1" >&2
}

# Run gcloud command with optional verbose output
run_gcloud() {
    if [ "$VERBOSE" == "true" ]; then
        log_cmd "gcloud $*"
    fi
    gcloud "$@"
}

# Run kubectl command with optional verbose output
run_kubectl() {
    if [ "$VERBOSE" == "true" ]; then
        log_cmd "kubectl $*"
    fi
    kubectl "$@"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    if ! command -v gcloud &> /dev/null; then
        log_error "gcloud CLI is not installed. Please install it first."
        exit 1
    fi
    
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed. Please install it first."
        exit 1
    fi
    
    if [ -z "$PROJECT_ID" ]; then
        log_error "PROJECT_ID is not set. Please set it or configure gcloud."
        exit 1
    fi
    
    log_info "Prerequisites check passed."
}

# Enable required APIs
enable_apis() {
    log_info "Enabling required Google Cloud APIs..."
    
    run_gcloud services enable \
        container.googleapis.com \
        cloudresourcemanager.googleapis.com \
        iam.googleapis.com \
        storage.googleapis.com \
        pubsub.googleapis.com \
        run.googleapis.com \
        firestore.googleapis.com \
        bigquery.googleapis.com \
        secretmanager.googleapis.com \
        monitoring.googleapis.com \
        logging.googleapis.com \
        --project="$PROJECT_ID"
    
    log_info "APIs enabled successfully."
}

# Check if cluster is Autopilot (which doesn't support Config Connector)
is_autopilot_cluster() {
    local autopilot_enabled
    autopilot_enabled=$(run_gcloud container clusters describe "$CLUSTER_NAME" \
        --region="$REGION" \
        --project="$PROJECT_ID" \
        --format="value(autopilot.enabled)" 2>/dev/null)
    
    [[ "$autopilot_enabled" == "True" ]]
}

# Check if Config Connector add-on is enabled
has_config_connector() {
    local addons
    addons=$(run_gcloud container clusters describe "$CLUSTER_NAME" \
        --region="$REGION" \
        --project="$PROJECT_ID" \
        --format="value(addonsConfig.configConnectorConfig.enabled)" 2>/dev/null)
    
    [[ "$addons" == "True" ]]
}

# Create GKE Standard cluster with Config Connector
# Note: Config Connector is NOT supported on Autopilot clusters
create_cluster() {
    log_info "Creating GKE Standard cluster: $CLUSTER_NAME..."
    
    # Check if cluster already exists
    if run_gcloud container clusters describe "$CLUSTER_NAME" --region="$REGION" --project="$PROJECT_ID" &> /dev/null; then
        log_warn "Cluster $CLUSTER_NAME already exists."
        
        # Check if it's an Autopilot cluster
        if is_autopilot_cluster; then
            log_error "Existing cluster is an Autopilot cluster. Config Connector is NOT supported on Autopilot."
            log_error "Please delete the cluster first:"
            log_error "  gcloud container clusters delete $CLUSTER_NAME --region=$REGION --quiet"
            exit 1
        fi
        
        # Check if Config Connector add-on is enabled
        if has_config_connector; then
            log_info "Config Connector add-on is already enabled."
        else
            log_warn "Config Connector add-on is not enabled. Enabling now..."
            run_gcloud container clusters update "$CLUSTER_NAME" \
                --region="$REGION" \
                --project="$PROJECT_ID" \
                --update-addons=ConfigConnector=ENABLED
            log_info "Config Connector add-on enabled."
        fi
        
        return
    fi
    
    # Create Standard cluster with Config Connector and Workload Identity
    run_gcloud container clusters create "$CLUSTER_NAME" \
        --region="$REGION" \
        --project="$PROJECT_ID" \
        --num-nodes=1 \
        --machine-type=e2-standard-4 \
        --workload-pool="${PROJECT_ID}.svc.id.goog" \
        --addons=ConfigConnector \
        --enable-ip-alias \
        --create-subnetwork name="${CLUSTER_NAME}-subnet"
    
    log_info "Cluster created successfully."
}

# Get cluster credentials
get_credentials() {
    log_info "Getting cluster credentials..."
    
    run_gcloud container clusters get-credentials "$CLUSTER_NAME" \
        --region="$REGION" \
        --project="$PROJECT_ID"
    
    log_info "Credentials configured."
}

# Create IAM service account for Config Connector
create_kcc_service_account() {
    log_info "Creating Config Connector service account..."
    
    local SA_NAME="kcc-controller"
    local SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
    
    # Check if service account exists
    if run_gcloud iam service-accounts describe "$SA_EMAIL" --project="$PROJECT_ID" &> /dev/null; then
        log_warn "Service account $SA_EMAIL already exists. Skipping creation."
    else
        run_gcloud iam service-accounts create "$SA_NAME" \
            --display-name="Config Connector Service Account" \
            --project="$PROJECT_ID"
    fi
    
    # Grant required permissions (Owner for demo, use more restrictive in production)
    log_info "Granting permissions to Config Connector service account..."
    
    run_gcloud projects add-iam-policy-binding "$PROJECT_ID" \
        --member="serviceAccount:${SA_EMAIL}" \
        --role="roles/owner" \
        --condition=None
    
    # Create Workload Identity binding
    log_info "Setting up Workload Identity binding..."
    
    run_gcloud iam service-accounts add-iam-policy-binding "$SA_EMAIL" \
        --member="serviceAccount:${PROJECT_ID}.svc.id.goog[cnrm-system/cnrm-controller-manager]" \
        --role="roles/iam.workloadIdentityUser" \
        --project="$PROJECT_ID"
    
    log_info "Config Connector service account configured."
}

# Configure Config Connector
configure_kcc() {
    log_info "Configuring Config Connector..."
    
    # Wait for Config Connector CRDs to be available
    log_info "Waiting for Config Connector CRDs..."
    sleep 30
    
    # Create ConfigConnector configuration
    local config_yaml="apiVersion: core.cnrm.cloud.google.com/v1beta1
kind: ConfigConnector
metadata:
  name: configconnector.core.cnrm.cloud.google.com
spec:
  mode: cluster
  googleServiceAccount: kcc-controller@${PROJECT_ID}.iam.gserviceaccount.com"
    
    if [ "$VERBOSE" == "true" ]; then
        log_cmd "kubectl apply -f - <<EOF"
        echo "$config_yaml"
        echo "EOF"
    fi
    
    echo "$config_yaml" | run_kubectl apply -f -
    
    log_info "Config Connector configured."
}

# Create namespace for CloudSnap resources
create_namespace() {
    log_info "Creating namespace: $KCC_NAMESPACE..."
    
    # Create namespace (don't pipe to avoid log output corruption)
    log_cmd "kubectl create namespace $KCC_NAMESPACE --dry-run=client -o yaml | kubectl apply -f -"
    kubectl create namespace "$KCC_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
    
    # Annotate namespace with project ID
    run_kubectl annotate namespace "$KCC_NAMESPACE" \
        cnrm.cloud.google.com/project-id="$PROJECT_ID" \
        --overwrite
    
    log_info "Namespace created and configured."
}

# Wait for Config Connector to be ready
wait_for_kcc() {
    log_info "Waiting for Config Connector to be ready..."
    
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if run_kubectl wait --for=condition=Ready pod -l cnrm.cloud.google.com/component=cnrm-controller-manager -n cnrm-system --timeout=10s &> /dev/null; then
            log_info "Config Connector is ready!"
            return 0
        fi
        log_info "Attempt $attempt/$max_attempts: Config Connector not ready yet..."
        sleep 10
        ((attempt++))
    done
    
    log_error "Config Connector did not become ready in time."
    exit 1
}

# Validate setup
validate_setup() {
    log_info "Validating setup..."
    
    # Check cluster status
    run_kubectl cluster-info
    
    # Check Config Connector status
    run_kubectl get configconnector -o yaml
    
    # List available KCC resource types
    log_info "Available Config Connector resource types:"
    run_kubectl api-resources --api-group=storage.cnrm.cloud.google.com 2>/dev/null || true
    run_kubectl api-resources --api-group=pubsub.cnrm.cloud.google.com 2>/dev/null || true
    run_kubectl api-resources --api-group=iam.cnrm.cloud.google.com 2>/dev/null || true
    
    log_info "Setup validation complete."
}

# Print summary
print_summary() {
    echo ""
    echo "=============================================="
    echo "  CloudSnap KCC Demo - Setup Complete"
    echo "=============================================="
    echo ""
    echo "Project ID:    $PROJECT_ID"
    echo "Region:        $REGION"
    echo "Cluster:       $CLUSTER_NAME"
    echo "Namespace:     $KCC_NAMESPACE"
    echo ""
    echo "Next steps:"
    echo "  1. Validate manifests: ./scripts/02-validate.sh"
    echo "  2. Deploy infrastructure: ./scripts/03-deploy.sh"
    echo "  3. Verify resources: kubectl get all -n $KCC_NAMESPACE"
    echo ""
    echo "To clean up: ./scripts/04-teardown.sh"
    echo "=============================================="
}

# Main execution
main() {
    echo ""
    echo "=============================================="
    echo "  CloudSnap KCC Demo - GKE Setup"
    echo "=============================================="
    echo ""
    
    check_prerequisites
    enable_apis
    create_cluster
    get_credentials
    create_kcc_service_account
    configure_kcc
    create_namespace
    wait_for_kcc
    validate_setup
    print_summary
}

# Run main function
main "$@"