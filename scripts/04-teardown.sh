#!/bin/bash
# CloudSnap KCC Demo - Teardown Script
# CRITICAL: This script removes ALL CloudSnap resources from GCP

set -euo pipefail

# Configuration
PROJECT_ID="${PROJECT_ID:-$(gcloud config get-value project)}"
ENVIRONMENT="${ENVIRONMENT:-dev}"
FORCE="${FORCE:-false}"
DELETE_CLUSTER="${DELETE_CLUSTER:-true}"
CLUSTER_NAME="${CLUSTER_NAME:-cloudsnap-cluster}"
REGION="${REGION:-us-central1}"
VERBOSE="${VERBOSE:-true}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

log_cmd() {
    if [ "$VERBOSE" = "true" ]; then
        echo -e "${YELLOW}[CMD]${NC} $*"
    fi
}

# Determine namespace based on environment
get_namespace() {
    if [ "$ENVIRONMENT" == "dev" ]; then
        echo "cloudsnap-dev"
    elif [ "$ENVIRONMENT" == "prod" ]; then
        echo "cloudsnap-prod"
    else
        echo "cloudsnap"
    fi
}

# Confirm teardown with user
confirm_teardown() {
    if [ "$FORCE" == "true" ]; then
        log_warn "Force mode enabled. Skipping confirmation."
        return 0
    fi
    
    echo ""
    echo -e "${RED}+----------------------------------------------------------------+${NC}"
    echo -e "${RED}|                       *** WARNING ***                          |${NC}"
    echo -e "${RED}|                                                                |${NC}"
    echo -e "${RED}|  This will DELETE ALL CloudSnap resources from Google Cloud!   |${NC}"
    echo -e "${RED}|                                                                |${NC}"
    echo -e "${RED}|  Resources to be deleted:                                      |${NC}"
    echo -e "${RED}|  - 3 Cloud Storage Buckets (and all contents)                  |${NC}"
    echo -e "${RED}|  - 3 Pub/Sub Topics                                            |${NC}"
    echo -e "${RED}|  - 3 Pub/Sub Subscriptions                                     |${NC}"
    echo -e "${RED}|  - 3 IAM Service Accounts                                      |${NC}"
    echo -e "${RED}|  - 1 Firestore Database                                        |${NC}"
    echo -e "${RED}|  - 1 BigQuery Dataset                                          |${NC}"
    echo -e "${RED}|  - Cloud Run Services and Jobs                                 |${NC}"
    echo -e "${RED}|  - Monitoring Dashboards and Alerts                            |${NC}"
    echo -e "${RED}|  - GKE Cluster (cloudsnap-cluster)                             |${NC}"
    echo -e "${RED}|                                                                |${NC}"
    printf "${RED}| Environment: %-50s|${NC}\n" "$ENVIRONMENT"
    printf "${RED}| Project:     %-50s|${NC}\n" "$PROJECT_ID"
    echo -e "${RED}+----------------------------------------------------------------+${NC}"
    echo ""

    read -p "Are you sure you want to proceed? Type 'DELETE' to confirm: " confirmation

    if [ "$confirmation" != "DELETE" ]; then
        log_info "Teardown cancelled."
        exit 0
    fi
}

# Delete KCC resources via Kubernetes
delete_kcc_resources() {
    local namespace=$(get_namespace)
    log_step "Deleting KCC resources in namespace: $namespace"
    
    # Delete in reverse dependency order
    
    # 1. Delete monitoring resources first
    log_info "Deleting monitoring resources..."
    log_cmd "kubectl delete monitoringalertpolicies --all -n $namespace --ignore-not-found --wait=false"
    kubectl delete monitoringalertpolicies --all -n "$namespace" --ignore-not-found --wait=false 2>/dev/null || true
    log_cmd "kubectl delete monitoringdashboards --all -n $namespace --ignore-not-found --wait=false"
    kubectl delete monitoringdashboards --all -n "$namespace" --ignore-not-found --wait=false 2>/dev/null || true
    
    # 2. Delete Cloud Run resources
    log_info "Deleting Cloud Run resources..."
    log_cmd "kubectl delete eventarctriggers --all -n $namespace --ignore-not-found --wait=false"
    kubectl delete eventarctriggers --all -n "$namespace" --ignore-not-found --wait=false 2>/dev/null || true
    log_cmd "kubectl delete runjobs --all -n $namespace --ignore-not-found --wait=false"
    kubectl delete runjobs --all -n "$namespace" --ignore-not-found --wait=false 2>/dev/null || true
    log_cmd "kubectl delete runservices --all -n $namespace --ignore-not-found --wait=false"
    kubectl delete runservices --all -n "$namespace" --ignore-not-found --wait=false 2>/dev/null || true
    
    # 3. Delete IAM bindings
    log_info "Deleting IAM bindings..."
    log_cmd "kubectl delete iampolicymembers --all -n $namespace --ignore-not-found --wait=false"
    kubectl delete iampolicymembers --all -n "$namespace" --ignore-not-found --wait=false 2>/dev/null || true
    
    # 4. Delete databases
    log_info "Deleting database resources..."
    log_cmd "kubectl delete bigquerytables --all -n $namespace --ignore-not-found --wait=false"
    kubectl delete bigquerytables --all -n "$namespace" --ignore-not-found --wait=false 2>/dev/null || true
    log_cmd "kubectl delete bigquerydatasets --all -n $namespace --ignore-not-found --wait=false"
    kubectl delete bigquerydatasets --all -n "$namespace" --ignore-not-found --wait=false 2>/dev/null || true
    log_cmd "kubectl delete firestoreindexes --all -n $namespace --ignore-not-found --wait=false"
    kubectl delete firestoreindexes --all -n "$namespace" --ignore-not-found --wait=false 2>/dev/null || true
    log_cmd "kubectl delete firestoredatabases --all -n $namespace --ignore-not-found --wait=false"
    kubectl delete firestoredatabases --all -n "$namespace" --ignore-not-found --wait=false 2>/dev/null || true
    
    # 5. Delete secrets
    log_info "Deleting Secret Manager resources..."
    log_cmd "kubectl delete secretmanagersecretversions --all -n $namespace --ignore-not-found --wait=false"
    kubectl delete secretmanagersecretversions --all -n "$namespace" --ignore-not-found --wait=false 2>/dev/null || true
    log_cmd "kubectl delete secretmanagersecrets --all -n $namespace --ignore-not-found --wait=false"
    kubectl delete secretmanagersecrets --all -n "$namespace" --ignore-not-found --wait=false 2>/dev/null || true
    
    # 6. Delete Pub/Sub resources
    log_info "Deleting Pub/Sub resources..."
    log_cmd "kubectl delete pubsubsubscriptions --all -n $namespace --ignore-not-found --wait=false"
    kubectl delete pubsubsubscriptions --all -n "$namespace" --ignore-not-found --wait=false 2>/dev/null || true
    log_cmd "kubectl delete storagenotifications --all -n $namespace --ignore-not-found --wait=false"
    kubectl delete storagenotifications --all -n "$namespace" --ignore-not-found --wait=false 2>/dev/null || true
    log_cmd "kubectl delete pubsubtopics --all -n $namespace --ignore-not-found --wait=false"
    kubectl delete pubsubtopics --all -n "$namespace" --ignore-not-found --wait=false 2>/dev/null || true
    
    # 7. Delete storage buckets
    log_info "Deleting Cloud Storage buckets..."
    log_cmd "kubectl delete storagebuckets --all -n $namespace --ignore-not-found --wait=false"
    kubectl delete storagebuckets --all -n "$namespace" --ignore-not-found --wait=false 2>/dev/null || true
    
    # 8. Delete IAM service accounts
    log_info "Deleting IAM service accounts..."
    log_cmd "kubectl delete iamserviceaccounts --all -n $namespace --ignore-not-found --wait=false"
    kubectl delete iamserviceaccounts --all -n "$namespace" --ignore-not-found --wait=false 2>/dev/null || true
    
    log_info "KCC resource deletion initiated."
}

# Helper function to count kubectl resources safely
count_resources() {
    local resource_type="$1"
    local namespace="$2"
    local result
    result=$(kubectl get "$resource_type" -n "$namespace" --no-headers 2>/dev/null | wc -l | tr -d '[:space:]')
    # Return 0 if empty or non-numeric
    if [[ "$result" =~ ^[0-9]+$ ]]; then
        echo "$result"
    else
        echo "0"
    fi
}

# Wait for resources to be deleted
wait_for_deletion() {
    local namespace=$(get_namespace)
    log_step "Waiting for GCP resources to be deleted..."
    
    local max_wait=600  # 10 minutes
    local interval=15
    local elapsed=0
    
    while [ $elapsed -lt $max_wait ]; do
        # Count remaining resources
        local remaining=0
        
        remaining=$((remaining + $(count_resources storagebuckets "$namespace")))
        remaining=$((remaining + $(count_resources pubsubtopics "$namespace")))
        remaining=$((remaining + $(count_resources iamserviceaccounts "$namespace")))
        remaining=$((remaining + $(count_resources firestoredatabases "$namespace")))
        
        if [ "$remaining" -eq 0 ]; then
            log_info "All KCC resources have been deleted."
            return 0
        fi
        
        log_info "Waiting... $remaining resources remaining."
        sleep $interval
        elapsed=$((elapsed + interval))
    done
    
    log_warn "Timeout waiting for resource deletion. Some resources may still be deleting."
}

# Force delete GCP resources using gcloud
force_delete_gcp_resources() {
    log_step "Force deleting GCP resources using gcloud..."
    
    # Delete Storage buckets (force delete contents)
    log_info "Force deleting Cloud Storage buckets..."
    for bucket in cloudsnap-raw-uploads cloudsnap-processed cloudsnap-thumbnails; do
        if gcloud storage buckets describe "gs://$bucket" --project="$PROJECT_ID" &>/dev/null; then
            log_info "Deleting bucket: $bucket"
            log_cmd "gcloud storage rm -r gs://$bucket --project=$PROJECT_ID"
            gcloud storage rm -r "gs://$bucket" --project="$PROJECT_ID" 2>/dev/null || true
        fi
    done
    
    # Delete Pub/Sub subscriptions
    log_info "Force deleting Pub/Sub subscriptions..."
    for sub in cloudsnap-processing-sub cloudsnap-analytics-sub cloudsnap-dead-letter-sub; do
        if gcloud pubsub subscriptions describe "$sub" --project="$PROJECT_ID" &>/dev/null; then
            log_info "Deleting subscription: $sub"
            log_cmd "gcloud pubsub subscriptions delete $sub --project=$PROJECT_ID --quiet"
            gcloud pubsub subscriptions delete "$sub" --project="$PROJECT_ID" --quiet 2>/dev/null || true
        fi
    done
    
    # Delete Pub/Sub topics
    log_info "Force deleting Pub/Sub topics..."
    for topic in cloudsnap-upload-notifications cloudsnap-dead-letter; do
        if gcloud pubsub topics describe "$topic" --project="$PROJECT_ID" &>/dev/null; then
            log_info "Deleting topic: $topic"
            log_cmd "gcloud pubsub topics delete $topic --project=$PROJECT_ID --quiet"
            gcloud pubsub topics delete "$topic" --project="$PROJECT_ID" --quiet 2>/dev/null || true
        fi
    done
    
    # Delete Cloud Run services
    log_info "Force deleting Cloud Run services..."
    log_cmd "gcloud run services delete cloudsnap-api --region=us-central1 --project=$PROJECT_ID --quiet"
    gcloud run services delete cloudsnap-api --region=us-central1 --project="$PROJECT_ID" --quiet 2>/dev/null || true
    log_cmd "gcloud run jobs delete cloudsnap-processor --region=us-central1 --project=$PROJECT_ID --quiet"
    gcloud run jobs delete cloudsnap-processor --region=us-central1 --project="$PROJECT_ID" --quiet 2>/dev/null || true
    
    # Delete IAM service accounts
    log_info "Force deleting IAM service accounts..."
    for sa in cloudsnap-uploader cloudsnap-processor cloudsnap-api; do
        local sa_email="${sa}@${PROJECT_ID}.iam.gserviceaccount.com"
        if gcloud iam service-accounts describe "$sa_email" --project="$PROJECT_ID" &>/dev/null; then
            log_info "Deleting service account: $sa"
            log_cmd "gcloud iam service-accounts delete $sa_email --project=$PROJECT_ID --quiet"
            gcloud iam service-accounts delete "$sa_email" --project="$PROJECT_ID" --quiet 2>/dev/null || true
        fi
    done
    
    # Delete BigQuery dataset
    log_info "Force deleting BigQuery dataset..."
    log_cmd "bq rm -r -f --project_id=$PROJECT_ID cloudsnap_analytics"
    bq rm -r -f --project_id="$PROJECT_ID" cloudsnap_analytics 2>/dev/null || true
    
    # Note: Firestore database deletion requires special handling
    log_warn "Firestore database may need manual deletion if delete protection is enabled."
    
    log_info "Force deletion complete."
}

# Delete namespace
delete_namespace() {
    local namespace=$(get_namespace)
    log_step "Deleting namespace: $namespace"
    
    log_cmd "kubectl delete namespace $namespace --ignore-not-found --wait=false"
    kubectl delete namespace "$namespace" --ignore-not-found --wait=false 2>/dev/null || true
    
    log_info "Namespace deletion initiated."
}

# Verify deletion
verify_deletion() {
    log_step "Verifying resource deletion..."
    
    echo ""
    echo "Remaining GCP resources (should be empty):"
    echo ""
    
    echo "Cloud Storage buckets:"
    log_cmd "gcloud storage ls --project=$PROJECT_ID | grep cloudsnap"
    gcloud storage ls --project="$PROJECT_ID" 2>/dev/null | grep cloudsnap || echo "  (none)"
    
    echo ""
    echo "Pub/Sub topics:"
    log_cmd "gcloud pubsub topics list --project=$PROJECT_ID | grep cloudsnap"
    gcloud pubsub topics list --project="$PROJECT_ID" 2>/dev/null | grep cloudsnap || echo "  (none)"
    
    echo ""
    echo "Cloud Run services:"
    log_cmd "gcloud run services list --project=$PROJECT_ID --region=us-central1 | grep cloudsnap"
    gcloud run services list --project="$PROJECT_ID" --region=us-central1 2>/dev/null | grep cloudsnap || echo "  (none)"
    
    echo ""
    echo "IAM Service Accounts:"
    log_cmd "gcloud iam service-accounts list --project=$PROJECT_ID | grep cloudsnap"
    gcloud iam service-accounts list --project="$PROJECT_ID" 2>/dev/null | grep cloudsnap || echo "  (none)"
    
    echo ""
}

# Delete GKE cluster
delete_cluster() {
    if [ "$DELETE_CLUSTER" != "true" ]; then
        log_info "Skipping cluster deletion (DELETE_CLUSTER=$DELETE_CLUSTER)"
        return 0
    fi
    
    log_step "Deleting GKE cluster: $CLUSTER_NAME..."
    
    if gcloud container clusters describe "$CLUSTER_NAME" --region="$REGION" --project="$PROJECT_ID" &> /dev/null; then
        log_cmd "gcloud container clusters delete $CLUSTER_NAME --region=$REGION --project=$PROJECT_ID --quiet"
        gcloud container clusters delete "$CLUSTER_NAME" \
            --region="$REGION" \
            --project="$PROJECT_ID" \
            --quiet
        log_info "Cluster deleted successfully."
    else
        log_warn "Cluster $CLUSTER_NAME does not exist. Skipping."
    fi
    
    # Also delete the KCC service account
    local kcc_sa="kcc-controller@${PROJECT_ID}.iam.gserviceaccount.com"
    if gcloud iam service-accounts describe "$kcc_sa" --project="$PROJECT_ID" &> /dev/null; then
        log_info "Deleting KCC service account..."
        log_cmd "gcloud iam service-accounts delete $kcc_sa --project=$PROJECT_ID --quiet"
        gcloud iam service-accounts delete "$kcc_sa" --project="$PROJECT_ID" --quiet 2>/dev/null || true
    fi
}

# Print summary
print_summary() {
    echo ""
    echo "=============================================="
    echo "  CloudSnap KCC Demo - Teardown Complete"
    echo "=============================================="
    echo ""
    echo "Environment: $ENVIRONMENT"
    echo "Project ID:  $PROJECT_ID"
    echo ""
    echo "Resources have been deleted. Please verify:"
    echo "  1. Check GCP Console for any remaining resources"
    echo "  2. Review billing to ensure no ongoing charges"
    echo ""
    echo "If resources remain, run with FORCE=true:"
    echo "  FORCE=true ./scripts/teardown.sh"
    echo "=============================================="
}

# Main execution
main() {
    echo ""
    echo "=============================================="
    echo "  CloudSnap KCC Demo - Teardown"
    echo "=============================================="
    echo ""
    
    confirm_teardown
    delete_kcc_resources
    wait_for_deletion
    
    if [ "$FORCE" == "true" ]; then
        force_delete_gcp_resources
    fi
    
    delete_namespace
    delete_cluster
    verify_deletion
    print_summary
}

# Run main function
main "$@"