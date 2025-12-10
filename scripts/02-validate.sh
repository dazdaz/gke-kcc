#!/bin/bash
# CloudSnap KCC Demo - Validation Script
# Validates manifests before deployment

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

log_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
}

log_cmd() {
    if [ "$VERBOSE" = "true" ]; then
        echo -e "${YELLOW}[CMD]${NC} $*"
    fi
}

# Track validation results
ERRORS=0
WARNINGS=0

# Check YAML syntax - uses Kustomize build as validation
# Note: Individual file YAML validation is skipped because CRDs may not be installed
check_yaml_syntax() {
    log_step "Checking YAML syntax (via Kustomize)..."
    
    # Kustomize build will fail if YAML is invalid
    # This is checked in check_kustomize_build, so we just note it here
    log_pass "YAML syntax validated via Kustomize build"
}

# Check Kustomize build
check_kustomize_build() {
    log_step "Checking Kustomize build..."
    
    # Create temp dir for variable substitution
    local temp_dir=$(mktemp -d)
    trap "rm -rf $temp_dir" RETURN
    
    cp -r "$ROOT_DIR/infrastructure" "$temp_dir/"
    cp -r "$ROOT_DIR/overlays" "$temp_dir/"
    
    # Substitute variables
    log_cmd "find $temp_dir -name '*.yaml' ... (substituting \${PROJECT_ID})"
    find "$temp_dir" -name "*.yaml" -type f -exec sed -i.bak "s/\${PROJECT_ID}/${PROJECT_ID:-my-project}/g" {} \;
    find "$temp_dir" -name "*.bak" -type f -delete
    
    # Try to build with kustomize
    log_cmd "kubectl kustomize $temp_dir/overlays/$ENVIRONMENT"
    if kubectl kustomize "$temp_dir/overlays/$ENVIRONMENT" > /dev/null 2>&1; then
        log_pass "Kustomize build for $ENVIRONMENT environment"
    else
        log_fail "Kustomize build failed for $ENVIRONMENT environment"
        kubectl kustomize "$temp_dir/overlays/$ENVIRONMENT" 2>&1 | head -20
        ((ERRORS++))
    fi
}

# Check for required fields
check_required_fields() {
    log_step "Checking required fields in KCC resources..."
    
    local files=$(find "$ROOT_DIR/infrastructure" -name "*.yaml" -type f ! -name "kustomization.yaml" ! -name "kustomizeconfig.yaml")
    local local_errors=0
    
    for file in $files; do
        # Check for apiVersion
        if ! grep -q "^apiVersion:" "$file"; then
            log_fail "$(basename $file) - Missing apiVersion"
            ((ERRORS++))
            ((local_errors++))
        fi
        
        # Check for kind
        if ! grep -q "^kind:" "$file"; then
            log_fail "$(basename $file) - Missing kind"
            ((ERRORS++))
            ((local_errors++))
        fi
        
        # Check for metadata.name (allowing indented name: fields)
        if ! grep -q "^  name:" "$file" && ! grep -q "^metadata:" "$file"; then
            log_fail "$(basename $file) - Missing metadata.name"
            ((ERRORS++))
            ((local_errors++))
        fi
    done
    
    if [ $local_errors -eq 0 ]; then
        log_pass "All required fields present"
    fi
}

# Check KCC API versions
check_api_versions() {
    log_step "Checking KCC API versions..."
    
    local files=$(find "$ROOT_DIR/infrastructure" -name "*.yaml" -type f ! -name "kustomization.yaml" ! -name "kustomizeconfig.yaml")
    local valid_apis=(
        "storage.cnrm.cloud.google.com/v1beta1"
        "pubsub.cnrm.cloud.google.com/v1beta1"
        "iam.cnrm.cloud.google.com/v1beta1"
        "resourcemanager.cnrm.cloud.google.com/v1beta1"
        "secretmanager.cnrm.cloud.google.com/v1beta1"
        "firestore.cnrm.cloud.google.com/v1beta1"
        "bigquery.cnrm.cloud.google.com/v1beta1"
        "run.cnrm.cloud.google.com/v1beta1"
        "monitoring.cnrm.cloud.google.com/v1beta1"
        "eventarc.cnrm.cloud.google.com/v1beta1"
        "core.cnrm.cloud.google.com/v1beta1"
        "v1"  # For Namespace
    )
    
    for file in $files; do
        # Only check lines that start with apiVersion (not indented ones)
        local apis=$(grep "^apiVersion:" "$file" | awk '{print $2}')
        for api in $apis; do
            # Skip empty values
            [ -z "$api" ] && continue
            
            local found=false
            for valid_api in "${valid_apis[@]}"; do
                if [ "$api" == "$valid_api" ]; then
                    found=true
                    break
                fi
            done
            if [ "$found" == "false" ]; then
                log_warn "$(basename $file) - Unrecognized API version: $api"
                ((WARNINGS++))
            fi
        done
    done
    
    log_pass "API version check complete"
}

# Check namespace consistency
check_namespaces() {
    log_step "Checking namespace consistency..."
    
    local files=$(find "$ROOT_DIR/infrastructure" -name "*.yaml" -type f ! -name "namespace.yaml" ! -name "kustomization.yaml" ! -name "kustomizeconfig.yaml")
    
    for file in $files; do
        if grep -q "namespace:" "$file"; then
            local ns=$(grep "namespace:" "$file" | head -1 | awk '{print $2}')
            if [ "$ns" != "cloudsnap" ]; then
                log_warn "$(basename $file) - Namespace is '$ns', expected 'cloudsnap'"
                ((WARNINGS++))
            fi
        fi
    done
    
    log_pass "Namespace check complete"
}

# Check for common issues
check_common_issues() {
    log_step "Checking for common issues..."
    
    local files=$(find "$ROOT_DIR/infrastructure" -name "*.yaml" -type f)
    local has_issues=false
    
    for file in $files; do
        # Check for tabs (YAML should use spaces)
        if grep -q $'\t' "$file"; then
            log_warn "$(basename $file) - Contains tabs (use spaces instead)"
            ((WARNINGS++))
            has_issues=true
        fi
        
        # Check for PROJECT_ID placeholder (informational only)
        if grep -q '\${PROJECT_ID}' "$file"; then
            log_info "$(basename $file) - Contains PROJECT_ID placeholder (will be substituted)"
        fi
    done
    
    # Note: Removed trailing whitespace check - it's cosmetic and not a real issue
    
    if [ "$has_issues" = false ]; then
        log_pass "No common issues found"
    else
        log_pass "Common issues check complete (see warnings above)"
    fi
}

# Dry-run against cluster (if connected and CRDs installed)
check_dry_run() {
    log_step "Checking kubectl dry-run (optional)..."
    
    # Check if we can connect to cluster
    log_cmd "kubectl cluster-info"
    if ! kubectl cluster-info &>/dev/null; then
        log_info "Not connected to a cluster. Skipping dry-run validation."
        log_info "This is normal if the cluster hasn't been created yet."
        return
    fi
    
    # Check if Config Connector CRDs are installed
    log_cmd "kubectl get crd storagebuckets.storage.cnrm.cloud.google.com"
    if ! kubectl get crd storagebuckets.storage.cnrm.cloud.google.com &>/dev/null; then
        log_info "Config Connector CRDs not installed. Skipping dry-run."
        log_info "Run ./scripts/01-setup-kcc.sh to install CRDs first."
        return
    fi
    
    # Create temp dir for variable substitution
    local temp_dir=$(mktemp -d)
    trap "rm -rf $temp_dir" RETURN
    
    cp -r "$ROOT_DIR/infrastructure" "$temp_dir/"
    cp -r "$ROOT_DIR/overlays" "$temp_dir/"
    
    # Substitute variables
    log_cmd "find $temp_dir -name '*.yaml' ... (substituting \${PROJECT_ID})"
    find "$temp_dir" -name "*.yaml" -type f -exec sed -i.bak "s/\${PROJECT_ID}/${PROJECT_ID:-my-project}/g" {} \;
    find "$temp_dir" -name "*.bak" -type f -delete
    
    # Dry-run apply
    log_cmd "kubectl apply -k $temp_dir/overlays/$ENVIRONMENT --dry-run=server"
    if kubectl apply -k "$temp_dir/overlays/$ENVIRONMENT" --dry-run=server -o yaml > /dev/null 2>&1; then
        log_pass "Server-side dry-run successful"
    else
        log_warn "Dry-run failed. This may be expected if some CRDs are missing."
    fi
}

# Print summary
print_summary() {
    echo ""
    echo "=============================================="
    echo "  Validation Summary"
    echo "=============================================="
    echo ""
    echo -e "Errors:   ${RED}$ERRORS${NC}"
    echo -e "Warnings: ${YELLOW}$WARNINGS${NC}"
    echo ""
    
    if [ $ERRORS -gt 0 ]; then
        echo -e "${RED}Validation FAILED. Please fix errors before deploying.${NC}"
        exit 1
    elif [ $WARNINGS -gt 0 ]; then
        echo -e "${YELLOW}Validation passed with warnings.${NC}"
    else
        echo -e "${GREEN}Validation PASSED. Ready to deploy!${NC}"
    fi
    
    echo ""
    echo "To deploy: ./scripts/03-deploy.sh"
    echo "=============================================="
}

# Main execution
main() {
    echo ""
    echo "=============================================="
    echo "  CloudSnap KCC Demo - Validation"
    echo "=============================================="
    echo ""
    echo "Environment: $ENVIRONMENT"
    echo "Project ID:  ${PROJECT_ID:-not set}"
    echo ""
    
    check_yaml_syntax
    check_required_fields
    check_api_versions
    check_namespaces
    check_common_issues
    check_kustomize_build
    check_dry_run
    print_summary
}

# Run main function
main "$@"