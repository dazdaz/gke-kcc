# CloudSnap KCC Demo - Task List

## Task Labeling Convention

| Prefix | Category | Description |
|--------|----------|-------------|
| `f1`, `f2`, `f3`... | **Frontend** | Browser-based code (TypeScript, React, UI/UX, WASM) |
| `b1`, `b2`, `b3`... | **Backend** | Infrastructure & services (GKE, Cloud Run, KCC manifests, GCP) |
| `d1`, `d2`, `d3`... | **Documentation** | README updates, API docs, guides |

---

## Phase 1: Infrastructure Foundation

### Backend Tasks (Infrastructure)

- [ ] **b1** - Create GKE cluster setup script with Config Connector add-on
  - Script: `scripts/setup-kcc.sh`
  - Enable Workload Identity
  - Configure KCC with project-level permissions
  - Validate KCC controller is running

- [ ] **b2** - Create KCC namespace configuration
  - File: `infrastructure/namespace.yaml`
  - Configure `ConfigConnectorContext` for the namespace
  - Set default project annotation

- [ ] **b3** - Create Cloud Storage bucket manifests
  - Files: `infrastructure/storage/*.yaml`
  - `StorageBucket` for raw uploads (STANDARD class)
  - `StorageBucket` for processed media (STANDARD class)
  - `StorageBucket` for thumbnails (STANDARD class)
  - Configure lifecycle rules for cost optimization
  - Enable uniform bucket-level access
  - Add CORS configuration for frontend uploads

- [ ] **b4** - Create Pub/Sub topic and subscription manifests
  - Files: `infrastructure/pubsub/*.yaml`
  - `PubSubTopic` for upload notifications
  - `PubSubSubscription` for processing queue (push to Cloud Run)
  - `PubSubSubscription` for analytics pipeline
  - Configure message retention and acknowledgment deadline

- [ ] **b5** - Create IAM service account manifests
  - Files: `infrastructure/iam/*.yaml`
  - `IAMServiceAccount` for upload operations
  - `IAMServiceAccount` for processor service
  - `IAMServiceAccount` for API service
  - `IAMPolicyMember` bindings for bucket access
  - `IAMPolicyMember` bindings for Pub/Sub access
  - Configure Workload Identity bindings

- [ ] **b6** - Create Secret Manager secret manifests
  - Files: `infrastructure/secrets/*.yaml`
  - `SecretManagerSecret` for API configuration
  - `SecretManagerSecretVersion` for secret data
  - IAM bindings for secret access

- [ ] **b7** - Create Firestore database manifest
  - Files: `infrastructure/database/firestore-database.yaml`
  - `FirestoreDatabase` in native mode
  - Configure location and concurrency settings

- [ ] **b8** - Create BigQuery dataset and table manifests
  - Files: `infrastructure/database/bigquery-*.yaml`
  - `BigQueryDataset` for analytics
  - `BigQueryTable` for processing events
  - Define schema for event tracking

- [ ] **b9** - Create Cloud Run service manifest for API
  - Files: `infrastructure/run/api-service.yaml`
  - `RunService` for REST API
  - Configure scaling, memory, CPU
  - Set up Workload Identity
  - Environment variables from Secret Manager

- [ ] **b10** - Create Cloud Run job manifest for processor
  - Files: `infrastructure/run/processor-job.yaml`
  - `RunJob` for media processing
  - Configure task timeout and retry policy
  - Set up Workload Identity

- [ ] **b11** - Create monitoring dashboard manifest
  - Files: `infrastructure/monitoring/dashboard.yaml`
  - `MonitoringDashboard` with key metrics
  - Upload counts, processing times, error rates

- [ ] **b12** - Create alerting policy manifests
  - Files: `infrastructure/monitoring/alerts.yaml`
  - `MonitoringAlertPolicy` for processing failures
  - `MonitoringAlertPolicy` for high error rate
  - Configure notification channels

- [ ] **b13** - Create Kustomize configuration
  - Files: `infrastructure/kustomization.yaml`
  - Base configuration with all resources
  - Common labels and annotations
  - Resource ordering

- [ ] **b14** - Create environment overlays
  - Files: `overlays/dev/kustomization.yaml`, `overlays/prod/kustomization.yaml`
  - Dev: smaller resources, shorter retention
  - Prod: production-ready configuration

---

## Phase 2: Backend Services

### Backend Tasks (Application Code)

- [ ] **b15** - Create API service (Go)
  - Files: `backend/main.go`, `backend/handlers/*.go`
  - REST endpoints: upload URL generation, file listing, processing status
  - Firestore integration for metadata
  - Structured logging
  - Health check endpoint

- [ ] **b16** - Create API service Dockerfile
  - Files: `backend/Dockerfile`
  - Multi-stage build
  - Minimal runtime image
  - Non-root user

- [ ] **b17** - Create media processor service (Python)
  - Files: `processor/process.py`, `processor/requirements.txt`
  - Image resizing and optimization
  - Thumbnail generation
  - Metadata extraction
  - GCS upload of processed files
  - Firestore metadata update

- [ ] **b18** - Create processor Dockerfile
  - Files: `processor/Dockerfile`
  - Include image processing libraries (Pillow)
  - Minimal runtime image

---

## Phase 3: Frontend Application

### Frontend Tasks

- [ ] **f1** - Initialize React TypeScript project
  - Files: `frontend/package.json`, `frontend/tsconfig.json`
  - Vite or Create React App setup
  - TailwindCSS for styling
  - Essential dependencies

- [ ] **f2** - Create main application layout
  - Files: `frontend/src/App.tsx`, `frontend/src/index.tsx`
  - Navigation structure
  - Theme and styling
  - Responsive design

- [ ] **f3** - Create file upload component
  - Files: `frontend/src/components/FileUpload.tsx`
  - Drag-and-drop support
  - Progress indicator
  - Direct GCS upload using signed URLs
  - File type validation
  - Multiple file support

- [ ] **f4** - Create media gallery component
  - Files: `frontend/src/components/MediaGallery.tsx`
  - Grid layout with thumbnails
  - Lazy loading
  - Lightbox for full-size view
  - Infinite scroll or pagination

- [ ] **f5** - Create processing status component
  - Files: `frontend/src/components/ProcessingStatus.tsx`
  - Real-time status updates
  - Progress indicators
  - Error display

- [ ] **f6** - Create API service layer
  - Files: `frontend/src/services/api.ts`
  - TypeScript interfaces for API responses
  - Axios or Fetch wrapper
  - Error handling
  - Authentication (if needed)

- [ ] **f7** - Create upload status hooks
  - Files: `frontend/src/hooks/useUpload.ts`
  - Upload state management
  - Progress tracking
  - Retry logic

- [ ] **f8** - Add WASM image preview optimization (optional)
  - Files: `frontend/src/wasm/image-preview.ts`
  - Client-side image resizing before upload
  - Format conversion
  - Lazy loading WASM module

---

## Phase 4: Deployment & Operations

### Backend Tasks (Deployment)

- [ ] **b19** - Create deployment script
  - Files: `scripts/deploy.sh`
  - Apply KCC manifests in correct order
  - Wait for resource readiness
  - Build and deploy container images
  - Validate deployment

- [ ] **b20** - Create teardown script (CRITICAL)
  - Files: `scripts/teardown.sh`
  - Delete all KCC-managed resources
  - Clean up container images
  - Verify resource deletion
  - Remove IAM bindings
  - **IMPORTANT: This must completely remove all deployed resources**

  ```bash
  #!/bin/bash
  # teardown.sh - Remove all CloudSnap resources
  
  echo "Removing all CloudSnap KCC resources..."
  
  # Delete in reverse dependency order
  kubectl delete -k overlays/dev/ --ignore-not-found
  
  # Wait for resources to be deleted
  echo "Waiting for GCP resources to be deleted..."
  sleep 30
  
  # Verify deletion
  kubectl get storagebuckets,pubsubtopics,pubsubsubscriptions -n cloudsnap
  
  echo "Teardown complete!"
  ```

- [ ] **b21** - Create validation script
  - Files: `scripts/validate.sh`
  - Dry-run kubectl apply
  - Schema validation
  - Dependency checking

- [ ] **b22** - Create CI/CD pipeline configuration
  - Files: `.github/workflows/deploy.yaml` or `cloudbuild.yaml`
  - Lint and validate manifests
  - Build container images
  - Deploy to dev/prod

---

## Phase 5: Documentation

### Documentation Tasks

- [ ] **d1** - Create README.md (Quick Start)
  - Files: `README.md`
  - Project overview
  - Prerequisites
  - Quick start commands
  - Architecture diagram
  - Links to detailed docs

- [ ] **d2** - Create KCC Setup Guide
  - Files: `docs/KCC_SETUP.md`
  - GKE cluster creation
  - KCC installation options (add-on vs manual)
  - Workload Identity configuration
  - Permission requirements
  - Troubleshooting steps

- [ ] **d3** - Create API Reference
  - Files: `docs/API_REFERENCE.md`
  - All API endpoints
  - Request/response examples
  - Authentication
  - Error codes

- [ ] **d4** - Create Troubleshooting Guide
  - Files: `docs/TROUBLESHOOTING.md`
  - Common KCC issues
  - Resource reconciliation problems
  - Permission errors
  - Debug commands

- [ ] **d5** - Create Cleanup Documentation
  - Files: `docs/CLEANUP.md`
  - **Step-by-step resource removal**
  - Manual cleanup procedures
  - Verification commands
  - Cost avoidance checklist

---

## Teardown Process (IMPORTANT)

### Complete Resource Removal Checklist

The following resources must be removed when tearing down the demo:

1. **Kubernetes Resources**
   - [ ] Delete all KCC custom resources
   - [ ] Delete namespace (cascades to resources)

2. **Cloud Storage**
   - [ ] `cloudsnap-raw-uploads` bucket (force delete contents)
   - [ ] `cloudsnap-processed` bucket
   - [ ] `cloudsnap-thumbnails` bucket

3. **Pub/Sub**
   - [ ] `cloudsnap-upload-notifications` topic
   - [ ] `cloudsnap-processing-sub` subscription
   - [ ] `cloudsnap-analytics-sub` subscription

4. **Cloud Run**
   - [ ] `cloudsnap-api` service
   - [ ] `cloudsnap-processor` job

5. **Firestore**
   - [ ] `cloudsnap-db` database

6. **BigQuery**
   - [ ] `cloudsnap_analytics` dataset

7. **Secret Manager**
   - [ ] `cloudsnap-api-config` secret

8. **IAM**
   - [ ] `cloudsnap-uploader` service account
   - [ ] `cloudsnap-processor` service account
   - [ ] All associated IAM bindings

9. **Monitoring**
   - [ ] `CloudSnap Processing Dashboard`
   - [ ] All alert policies

10. **Artifact Registry** (if images were pushed)
    - [ ] Container images

### Teardown Command Sequence

```bash
# 1. Delete all resources via KCC
kubectl delete -k infrastructure/ -n cloudsnap

# 2. Wait for reconciliation
watch kubectl get all -n cloudsnap

# 3. Verify GCP resources are deleted
gcloud storage ls | grep cloudsnap
gcloud pubsub topics list | grep cloudsnap
gcloud run services list | grep cloudsnap

# 4. Delete namespace if needed
kubectl delete namespace cloudsnap

# 5. Optional: Force delete any remaining resources
gcloud storage rm -r gs://cloudsnap-raw-uploads --force
gcloud storage rm -r gs://cloudsnap-processed --force
gcloud storage rm -r gs://cloudsnap-thumbnails --force
```

---

## Task Priority Order

1. **High Priority** (Do First)
   - b1, b2, b3 - Cluster and basic storage setup
   - d1 - README for others to follow

2. **Medium Priority** (Core Functionality)
   - b4, b5, b6 - Pub/Sub and IAM
   - b15, b16 - API service
   - f1, f2, f3 - Basic frontend

3. **Lower Priority** (Enhanced Features)
   - b7, b8 - Database resources
   - b11, b12 - Monitoring
   - f4, f5, f6 - Additional frontend features

4. **Final** (Polish)
   - b20 - Teardown script (critical before demo)
   - d2, d3, d4, d5 - Complete documentation

---

## Progress Tracking

| Phase | Total Tasks | Completed | Percentage |
|-------|-------------|-----------|------------|
| Phase 1: Infrastructure | 14 | 0 | 0% |
| Phase 2: Backend Services | 4 | 0 | 0% |
| Phase 3: Frontend | 8 | 0 | 0% |
| Phase 4: Deployment | 4 | 0 | 0% |
| Phase 5: Documentation | 5 | 0 | 0% |
| **Total** | **35** | **0** | **0%** |