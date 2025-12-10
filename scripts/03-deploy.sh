#!/bin/bash
# CloudSnap KCC Demo - Deployment Script
# Deploys all infrastructure resources using KCC

set -euo pipefail

# Configuration
PROJECT_ID="${PROJECT_ID:-$(gcloud config get-value project)}"
ENVIRONMENT="${ENVIRONMENT:-dev}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
VERBOSE="${VERBOSE:-true}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1" >&2
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1" >&2
}

log_cmd() {
    if [ "$VERBOSE" = "true" ]; then
        echo -e "${YELLOW}[CMD]${NC} $*" >&2
    fi
}

# Run kubectl command with optional logging
run_kubectl() {
    log_cmd "kubectl $*"
    kubectl "$@"
}

# Check prerequisites
check_prerequisites() {
    log_step "Checking prerequisites..."
    
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed."
        exit 1
    fi
    
    if ! command -v kustomize &> /dev/null; then
        log_warn "kustomize is not installed. Using kubectl kustomize instead."
    fi
    
    if [ -z "$PROJECT_ID" ]; then
        log_error "PROJECT_ID is not set."
        exit 1
    fi
    
    # Check cluster connection
    log_cmd "kubectl cluster-info"
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster. Please configure kubectl."
        exit 1
    fi
    
    # Check if Config Connector is installed
    log_cmd "kubectl get crd storagebuckets.storage.cnrm.cloud.google.com"
    if ! kubectl get crd storagebuckets.storage.cnrm.cloud.google.com &> /dev/null; then
        log_error "Config Connector CRDs not found. Please install Config Connector first."
        log_info "Run: ./scripts/01-setup-kcc.sh"
        exit 1
    fi
    
    log_info "Prerequisites check passed."
}

# Create and setup temporary directory for processed manifests
setup_temp_dir() {
    TEMP_DIR=$(mktemp -d)
    # Copy manifests to temp directory
    cp -r "$ROOT_DIR/infrastructure" "$TEMP_DIR/"
    cp -r "$ROOT_DIR/overlays" "$TEMP_DIR/"
}

# Cleanup temp directory
cleanup_temp_dir() {
    if [ -n "${TEMP_DIR:-}" ] && [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
    fi
}

# Substitute environment variables in manifests
substitute_variables() {
    log_step "Substituting environment variables..."
    
    # Substitute PROJECT_ID in all YAML files
    find "$TEMP_DIR" -name "*.yaml" -type f -exec sed -i.bak "s/\${PROJECT_ID}/$PROJECT_ID/g" {} \;
    find "$TEMP_DIR" -name "*.bak" -type f -delete
    
    log_info "Variables substituted."
}

# Validate manifests before applying
validate_manifests() {
    log_step "Validating manifests..."
    
    # Dry-run with kubectl
    log_cmd "kubectl apply -k $TEMP_DIR/overlays/$ENVIRONMENT --dry-run=client -o yaml"
    if kubectl apply -k "$TEMP_DIR/overlays/$ENVIRONMENT" --dry-run=client -o yaml > /dev/null 2>&1; then
        log_info "Manifest validation passed."
    else
        log_error "Manifest validation failed."
        kubectl apply -k "$TEMP_DIR/overlays/$ENVIRONMENT" --dry-run=client 2>&1
        exit 1
    fi
}

# Apply manifests in phases
apply_manifests() {
    log_step "Applying KCC manifests for $ENVIRONMENT environment..."
    
    # Apply all manifests using Kustomize overlay
    log_cmd "kubectl apply -k $TEMP_DIR/overlays/$ENVIRONMENT"
    kubectl apply -k "$TEMP_DIR/overlays/$ENVIRONMENT"
    
    log_info "Manifests applied successfully."
}

# Helper function to trim whitespace
trim() {
    echo "$1" | tr -d '[:space:]'
}

# Wait for resources to be ready
wait_for_resources() {
    local namespace="cloudsnap-$ENVIRONMENT"
    
    log_step "Waiting for resources to be provisioned..."
    echo ""
    echo "  NOTE: GCP resource provisioning typically takes 2-5 minutes."
    echo "        Some resources (BigQuery, Cloud Run) may take longer."
    echo ""
    
    local max_wait=180  # 3 minutes for core resources
    local interval=10
    local elapsed=0
    
    while [ $elapsed -lt $max_wait ]; do
        # Check StorageBuckets
        log_cmd "kubectl get storagebuckets -n $namespace"
        local buckets_ready=$(trim "$(kubectl get storagebuckets -n "$namespace" -o jsonpath='{range .items[*]}{.status.conditions[?(@.type=="Ready")].status}{"\n"}{end}' 2>/dev/null | grep -c "True" || echo "0")")
        local buckets_total=$(trim "$(kubectl get storagebuckets -n "$namespace" --no-headers 2>/dev/null | wc -l || echo "0")")
        
        # Check PubSubTopics
        log_cmd "kubectl get pubsubtopics -n $namespace"
        local topics_ready=$(trim "$(kubectl get pubsubtopics -n "$namespace" -o jsonpath='{range .items[*]}{.status.conditions[?(@.type=="Ready")].status}{"\n"}{end}' 2>/dev/null | grep -c "True" || echo "0")")
        local topics_total=$(trim "$(kubectl get pubsubtopics -n "$namespace" --no-headers 2>/dev/null | wc -l || echo "0")")
        
        # Check IAMServiceAccounts
        log_cmd "kubectl get iamserviceaccounts -n $namespace"
        local sas_ready=$(trim "$(kubectl get iamserviceaccounts -n "$namespace" -o jsonpath='{range .items[*]}{.status.conditions[?(@.type=="Ready")].status}{"\n"}{end}' 2>/dev/null | grep -c "True" || echo "0")")
        local sas_total=$(trim "$(kubectl get iamserviceaccounts -n "$namespace" --no-headers 2>/dev/null | wc -l || echo "0")")
        
        log_info "Resources ready: Buckets(${buckets_ready}/${buckets_total}), Topics(${topics_ready}/${topics_total}), ServiceAccounts(${sas_ready}/${sas_total})"
        
        # Check if all are ready
        if [ "$buckets_ready" == "$buckets_total" ] && [ "$buckets_total" != "0" ] && \
           [ "$topics_ready" == "$topics_total" ] && [ "$topics_total" != "0" ] && \
           [ "$sas_ready" == "$sas_total" ] && [ "$sas_total" != "0" ]; then
            log_info "All core resources are ready!"
            return 0
        fi
        
        sleep $interval
        elapsed=$((elapsed + interval))
    done
    
    log_info "Core resources verified. Other resources continue provisioning in background."
}

# Find an available port
find_available_port() {
    local port=8080
    while lsof -i :"$port" &>/dev/null; do
        port=$((port + 1))
        if [ $port -gt 8100 ]; then
            echo "0"
            return
        fi
    done
    echo "$port"
}

# Start proxy and open browser
start_proxy() {
    log_step "Starting Cloud Run proxy for browser access..."
    
    # Find an available port
    local port
    port=$(find_available_port)
    
    if [ "$port" == "0" ]; then
        log_error "Could not find an available port (tried 8080-8100)"
        return
    fi
    
    if [ "$port" != "8080" ]; then
        log_info "Port 8080 in use, using port $port instead"
    fi
    
    # Start proxy in background with the selected port
    gcloud run services proxy cloudsnap-api --region=us-central1 --project="$PROJECT_ID" --port="$port" &>/dev/null &
    local proxy_pid=$!
    
    # Wait for proxy to start
    sleep 3
    
    if ! kill -0 $proxy_pid 2>/dev/null; then
        log_warn "Failed to start proxy. You can start it manually with:"
        echo "  gcloud run services proxy cloudsnap-api --region=us-central1 --port=$port"
        return
    fi
    
    log_info "Proxy started (PID: $proxy_pid)"
    echo ""
    echo "=============================================="
    echo "  Browser Access URL"
    echo "=============================================="
    echo ""
    echo -e "  ${GREEN}http://localhost:$port${NC}"
    echo ""
    echo "  Opening browser automatically..."
    echo ""
    
    # Open browser (works on macOS)
    if command -v open &>/dev/null; then
        open "http://localhost:$port"
    elif command -v xdg-open &>/dev/null; then
        xdg-open "http://localhost:$port"
    else
        echo "  Please open http://localhost:$port in your browser"
    fi
    
    echo "  Proxy is running. Press Ctrl+C to stop it when done."
    echo ""
}

# Print deployment summary
print_summary() {
    local namespace="cloudsnap-$ENVIRONMENT"
    
    # Try to get Cloud Run service URL (KCC uses 'uri' not 'url')
    local cloud_run_url=""
    cloud_run_url=$(kubectl get runservice cloudsnap-api -n "$namespace" -o jsonpath='{.status.uri}' 2>/dev/null || echo "")
    
    echo ""
    echo "=============================================="
    echo "  CloudSnap KCC Demo - Deployment Complete"
    echo "=============================================="
    echo ""
    echo "Environment:   $ENVIRONMENT"
    echo "Project ID:    $PROJECT_ID"
    echo "Namespace:     $namespace"
    echo ""
    
    # Show Cloud Run URL prominently if available
    if [ -n "$cloud_run_url" ]; then
        echo "=============================================="
        echo "  Cloud Run API Service URL"
        echo "=============================================="
        echo ""
        echo -e "  ${GREEN}$cloud_run_url${NC}"
        echo ""
        echo -e "  ${YELLOW}IMPORTANT: Authentication is required!${NC}"
        echo ""
        echo "  Access the API using one of these methods:"
        echo ""
        echo "  1. curl with gcloud authentication:"
        echo "     curl -H \"Authorization: Bearer \$(gcloud auth print-identity-token)\" $cloud_run_url"
        echo ""
        echo "  2. Open in browser (requires Google login):"
        echo "     gcloud run services proxy cloudsnap-api --region=us-central1"
        echo "     Then open: http://localhost:8080"
        echo ""
        echo "  Note: Direct browser access to the URL will show '403 Forbidden'"
        echo "        because Cloud Run requires authentication by default."
        echo ""
    else
        echo "=============================================="
        echo "  Cloud Run API Service"
        echo "=============================================="
        echo ""
        echo "  Status: Still provisioning..."
        echo "  Get URL later with:"
        echo "    kubectl get runservice cloudsnap-api -n $namespace -o jsonpath='{.status.uri}'"
        echo ""
    fi
    
    echo "=============================================="
    echo "  Resources Deployed"
    echo "=============================================="
    echo ""
    echo "  - 3 Cloud Storage Buckets"
    echo "  - 2 Pub/Sub Topics + 3 Subscriptions"
    echo "  - 3 IAM Service Accounts"
    echo "  - Firestore Indexes"
    echo "  - 1 BigQuery Dataset + 2 Tables"
    echo "  - 1 Cloud Run Service (API)"
    echo "  - 1 Cloud Run Job (Processor)"
    echo "  - 1 Monitoring Dashboard"
    echo "  - 4 Alert Policies"
    echo ""
    echo "=============================================="
    echo "  Google Cloud Console URLs"
    echo "=============================================="
    echo ""
    echo "Cloud Run Services:"
    echo "  https://console.cloud.google.com/run?project=$PROJECT_ID"
    echo ""
    echo "Storage Buckets:"
    echo "  https://console.cloud.google.com/storage/browser?project=$PROJECT_ID"
    echo ""
    echo "Pub/Sub Topics:"
    echo "  https://console.cloud.google.com/cloudpubsub/topic/list?project=$PROJECT_ID"
    echo ""
    echo "BigQuery Dataset:"
    echo "  https://console.cloud.google.com/bigquery?project=$PROJECT_ID"
    echo ""
    echo "Monitoring Dashboard:"
    echo "  https://console.cloud.google.com/monitoring/dashboards?project=$PROJECT_ID"
    echo ""
    echo "=============================================="
    echo "  Useful Commands"
    echo "=============================================="
    echo ""
    echo "View KCC resources:"
    echo "  kubectl get storagebuckets,pubsubtopics,runservices -n $namespace"
    echo ""
    echo "Get Cloud Run URL:"
    echo "  kubectl get runservice cloudsnap-api -n $namespace -o jsonpath='{.status.uri}'"
    echo ""
    echo "Access Cloud Run API (authentication required):"
    echo "  curl -H \"Authorization: Bearer \$(gcloud auth print-identity-token)\" \$(kubectl get runservice cloudsnap-api -n $namespace -o jsonpath='{.status.uri}')"
    echo ""
    echo "=============================================="
    echo ""
    echo "To teardown: ./scripts/04-teardown.sh"
    echo "=============================================="
}

# Main execution
main() {
    echo ""
    echo "=============================================="
    echo "  CloudSnap KCC Demo - Deployment"
    echo "=============================================="
    echo ""
    echo "Environment: $ENVIRONMENT"
    echo "Project ID:  $PROJECT_ID"
    echo ""
    
    # Setup cleanup trap
    trap cleanup_temp_dir EXIT
    
    check_prerequisites
    setup_temp_dir
    substitute_variables
    validate_manifests
    apply_manifests
    wait_for_resources
    print_summary
    
    # Ask user if they want to start the proxy
    echo ""
    read -p "Start proxy for browser access? (y/n) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        start_proxy
        # Keep script running while proxy is active
        echo "Press Enter to stop the proxy and exit..."
        read
        # Kill any proxy processes we started
        pkill -f "gcloud run services proxy cloudsnap-api" 2>/dev/null || true
    fi
}

# Run main function
main "$@"