# CloudSnap KCC Demo

A demonstration of **Google Kubernetes Engine Config Connector (KCC)** - showing how to provision GCP infrastructure using Kubernetes-native YAML manifests.

[![GCP](https://img.shields.io/badge/Google%20Cloud-4285F4?logo=google-cloud&logoColor=white)](https://cloud.google.com/)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-326CE5?logo=kubernetes&logoColor=white)](https://kubernetes.io/)
[![Config Connector](https://img.shields.io/badge/Config%20Connector-1.x-blue)](https://cloud.google.com/config-connector/docs/overview)

## 🎯 Overview

> ⚠️ **This is an infrastructure-only demo.** There is no application code included - just the GCP resource definitions. The Cloud Run service deploys a placeholder "Hello" container to demonstrate successful provisioning.

**CloudSnap** is a hypothetical media processing platform used as a realistic scenario to demonstrate Config Connector capabilities. This project shows how to:

- **Provision 15+ GCP resources** (Storage, Pub/Sub, BigQuery, Cloud Run, IAM, etc.) using only `kubectl apply`
- **Replace Terraform/gcloud** with Kubernetes-native resource management
- **Enable GitOps workflows** where infrastructure changes go through pull requests
- **Use Kustomize overlays** for dev/prod environment differences

### What This Demo Does

| ✅ What's Included | ❌ What's NOT Included |
|-------------------|----------------------|
| GKE cluster with Config Connector | Application source code |
| Cloud Storage bucket manifests | File upload functionality |
| Pub/Sub topics & subscriptions | Message processing logic |
| Cloud Run service definitions | API implementation |
| IAM service accounts & bindings | Frontend React app |
| BigQuery dataset & tables | Thumbnail generation |
| Firestore database | Actual media processing |
| Monitoring dashboards & alerts | Business logic |

### What You'll Learn

- ✅ Setting up GKE with Config Connector add-on
- ✅ Managing 15+ GCP resource types via KCC
- ✅ Implementing GitOps workflows for infrastructure
- ✅ Using Kustomize for environment overlays
- ✅ Understanding event-driven architecture patterns

## 🏗️ Architecture

The hypothetical CloudSnap platform would work like this (infrastructure is provisioned, but application code is not included):

```
┌─────────────────────────────────────────────────────────────────────────┐
│              CloudSnap Architecture (Infrastructure Only)               │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌──────────────┐    ┌──────────────────┐    ┌───────────────────────┐  │
│  │   Frontend   │───▶│    Cloud Run     │───▶│ Firestore (Metadata)  │  │
│  │   (React)    │    │   API Service    │    │   ✅ PROVISIONED      │  │
│  │ NOT INCLUDED │    │  ✅ DEPLOYED     │    └───────────────────────┘  │
│  └──────────────┘    │   (placeholder)  │                               │
│         │            └──────────────────┘                               │
│         ▼                                                               │
│  ┌────────────────────────┐                                             │
│  │     Cloud Storage      │                                             │
│  │     (Raw Uploads)      │────────┐  ✅ PROVISIONED                    │
│  └────────────────────────┘        │                                    │
│                                    ▼                                    │
│                       ┌─────────────────────┐                           │
│                       │    Pub/Sub Topic    │  ✅ PROVISIONED           │
│                       │   (Notifications)   │                           │
│                       └─────────────────────┘                           │
│                              │       │                                  │
│               ┌──────────────┘       └──────────────┐                   │
│               ▼                                     ▼                   │
│  ┌───────────────────────┐              ┌───────────────────────┐       │
│  │    Cloud Run Job      │              │       BigQuery        │       │
│  │     (Processor)       │              │     (Analytics)       │       │
│  │    ✅ DEPLOYED        │              │   ✅ PROVISIONED      │       │
│  │    (placeholder)      │              └───────────────────────┘       │
│  └───────────────────────┘                                              │
│               │                                                         │
│               ▼                                                         │
│  ┌────────────────────────┐    ┌────────────────────────┐               │
│  │     Cloud Storage      │    │     Cloud Storage      │               │
│  │   (Processed Media)    │    │     (Thumbnails)       │               │
│  │    ✅ PROVISIONED      │    │    ✅ PROVISIONED      │               │
│  └────────────────────────┘    └────────────────────────┘               │
│                                                                         │
│  ═══════════════════════════════════════════════════════════════════    │
│        All GCP resources managed by Config Connector via kubectl        │
└─────────────────────────────────────────────────────────────────────────┘
```

**Legend:**
- ✅ PROVISIONED = GCP resource created by this demo
- ✅ DEPLOYED (placeholder) = Cloud Run with sample container (no real logic)
- NOT INCLUDED = Would need to be built separately

## 📋 Prerequisites

- **GCP Project** with billing enabled
- **gcloud CLI** installed and configured
- **kubectl** installed
- **Kustomize** (optional, kubectl has built-in support)
- GKE cluster admin permissions

> ⚠️ **Important:** Config Connector requires a **GKE Standard cluster**. It is not supported on GKE Autopilot clusters.

## 🚀 Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/your-org/gke-kcc.git
cd gke-kcc
```

### 2. Set Environment Variables

```bash
export PROJECT_ID="your-gcp-project-id"
export REGION="us-central1"
export ENVIRONMENT="dev"  # or "prod"
```

### 3. Create GKE Cluster with Config Connector

```bash
chmod +x scripts/*.sh
./scripts/01-setup-kcc.sh
```

This script will:
- Enable required GCP APIs
- Create a GKE Standard cluster (Config Connector is not supported on Autopilot)
- Enable the Config Connector add-on
- Set up Workload Identity

### 4. Validate Manifests

```bash
./scripts/02-validate.sh
```

### 5. Deploy Infrastructure

```bash
./scripts/03-deploy.sh
```

### 6. Verify Deployment

```bash
# Check all KCC resources
kubectl get storagebuckets,pubsubtopics,iamserviceaccounts -n cloudsnap-dev

# Check resource status
kubectl describe storagebucket cloudsnap-raw-uploads -n cloudsnap-dev
```

## 📁 Project Structure

```
gke-kcc/
├── infrastructure/          # KCC manifests (base configuration)
│   ├── kustomization.yaml   # Kustomize base
│   ├── namespace.yaml       # KCC namespace config
│   ├── storage/             # Cloud Storage buckets
│   ├── pubsub/              # Pub/Sub topics & subscriptions
│   ├── iam/                 # Service accounts & IAM bindings
│   ├── secrets/             # Secret Manager secrets
│   ├── database/            # Firestore & BigQuery
│   ├── run/                 # Cloud Run services & jobs
│   └── monitoring/          # Dashboards & alerts
├── overlays/                # Environment-specific configs
│   ├── dev/                 # Development settings
│   └── prod/                # Production settings
├── scripts/                 # Automation scripts
│   ├── 01-setup-kcc.sh      # Cluster setup
│   ├── 02-validate.sh       # Validate manifests
│   ├── 03-deploy.sh         # Deploy resources
│   └── 04-teardown.sh       # Remove all resources
└── docs/                    # Additional documentation
```

## 🔧 GCP Resources Managed

| Resource Type | Count | Description |
|---------------|-------|-------------|
| StorageBucket | 3 | Raw, processed, thumbnails |
| PubSubTopic | 2 | Upload notifications, dead letter |
| PubSubSubscription | 3 | Processing, analytics, dead letter |
| IAMServiceAccount | 3 | Uploader, processor, API |
| IAMPolicyMember | 12+ | Role bindings |
| SecretManagerSecret | 1 | API configuration |
| FirestoreDatabase | 1 | Metadata store |
| BigQueryDataset | 1 | Analytics warehouse |
| BigQueryTable | 2 | Events, metrics |
| RunService | 1 | REST API |
| RunJob | 1 | Media processor |
| MonitoringDashboard | 1 | Operations view |
| MonitoringAlertPolicy | 4 | Error alerts |

## 🌍 Environment Configuration

### Development (overlays/dev)
- Smaller resource limits
- Shorter data retention
- Scale to zero enabled
- Delete protection disabled

### Production (overlays/prod)
- Higher resource limits
- Longer data retention
- Minimum instances for availability
- Delete protection enabled
- Point-in-time recovery enabled

## 🧹 Cleanup

**⚠️ IMPORTANT: Always clean up demo resources to avoid ongoing charges!**

```bash
# Standard teardown (requires confirmation)
./scripts/04-teardown.sh

# Force teardown (no confirmation, deletes directly via gcloud)
FORCE=true ./scripts/04-teardown.sh
```

### Manual Cleanup Verification

```bash
# Check for remaining resources
gcloud storage ls | grep cloudsnap
gcloud pubsub topics list | grep cloudsnap
gcloud run services list --region=us-central1 | grep cloudsnap
gcloud iam service-accounts list | grep cloudsnap
```

## 🔍 What You'll See When Deployed

After running `./scripts/03-deploy.sh`, you'll have:

1. **Cloud Run URL** - Opens a "Congratulations" page (Google's sample container)
   - This proves the Cloud Run service was provisioned correctly
   - Replace with your own container image to add real functionality

2. **GCP Console Resources** - All infrastructure visible in Google Cloud Console:
   - Storage buckets for uploads, processed files, and thumbnails
   - Pub/Sub topics and subscriptions ready for messages
   - BigQuery datasets and tables for analytics
   - IAM service accounts with proper permissions

3. **Kubernetes Resources** - View via `kubectl`:
   ```bash
   kubectl get storagebuckets,pubsubtopics,runservices -n cloudsnap-dev
   ```

## 📚 Documentation

- [PROJECT_OVERVIEW.md](PROJECT_OVERVIEW.md) - Detailed architecture and concepts
- [TODO.md](TODO.md) - Task tracking for development
- [docs/KCC_SETUP.md](docs/KCC_SETUP.md) - Detailed KCC installation guide
- [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) - Common issues and solutions

## 🔗 Useful Links

### Config Connector
- [Config Connector Overview](https://cloud.google.com/config-connector/docs/overview)
- [KCC Resource Reference](https://cloud.google.com/config-connector/docs/reference/overview)
- [Installing Config Connector](https://cloud.google.com/config-connector/docs/how-to/install-upgrade-uninstall)
- [Config Connector Samples](https://github.com/GoogleCloudPlatform/k8s-config-connector/tree/master/samples)

### GCP Services Used in This Demo
| Service          | Documentation                                        | KCC Resource                                                                                                                                                                                                                                                         |
|------------------|------------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Cloud Storage    | [Docs](https://cloud.google.com/storage/docs)        | [StorageBucket](https://cloud.google.com/config-connector/docs/reference/resource-docs/storage/storagebucket)                                                                                                                                                        |
| Pub/Sub          | [Docs](https://cloud.google.com/pubsub/docs)         | [PubSubTopic](https://cloud.google.com/config-connector/docs/reference/resource-docs/pubsub/pubsubtopic), [PubSubSubscription](https://cloud.google.com/config-connector/docs/reference/resource-docs/pubsub/pubsubsubscription)                                     |
| Cloud Run        | [Docs](https://cloud.google.com/run/docs)            | [RunService](https://cloud.google.com/config-connector/docs/reference/resource-docs/run/runservice), [RunJob](https://cloud.google.com/config-connector/docs/reference/resource-docs/run/runjob)                                                                     |
| BigQuery         | [Docs](https://cloud.google.com/bigquery/docs)       | [BigQueryDataset](https://cloud.google.com/config-connector/docs/reference/resource-docs/bigquery/bigquerydataset), [BigQueryTable](https://cloud.google.com/config-connector/docs/reference/resource-docs/bigquery/bigquerytable)                                   |
| Firestore        | [Docs](https://cloud.google.com/firestore/docs)      | [FirestoreDatabase](https://cloud.google.com/config-connector/docs/reference/resource-docs/firestore/firestoredatabase)                                                                                                                                              |
| IAM              | [Docs](https://cloud.google.com/iam/docs)            | [IAMServiceAccount](https://cloud.google.com/config-connector/docs/reference/resource-docs/iam/iamserviceaccount), [IAMPolicyMember](https://cloud.google.com/config-connector/docs/reference/resource-docs/iam/iampolicymember)                                     |
| Secret Manager   | [Docs](https://cloud.google.com/secret-manager/docs) | [SecretManagerSecret](https://cloud.google.com/config-connector/docs/reference/resource-docs/secretmanager/secretmanagersecret)                                                                                                                                      |
| Cloud Monitoring | [Docs](https://cloud.google.com/monitoring/docs)     | [MonitoringDashboard](https://cloud.google.com/config-connector/docs/reference/resource-docs/monitoring/monitoringdashboard), [MonitoringAlertPolicy](https://cloud.google.com/config-connector/docs/reference/resource-docs/monitoring/monitoringalertpolicy)       |

### GKE & Kubernetes
- [GKE Standard Mode](https://cloud.google.com/kubernetes-engine/docs/concepts/types-of-clusters#standard)
- [Workload Identity](https://cloud.google.com/kubernetes-engine/docs/concepts/workload-identity)
- [Kustomize Documentation](https://kustomize.io/)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run `./scripts/validate.sh`
5. Submit a pull request

## 📄 License

This project is licensed under the Apache 2.0 License - see the [LICENSE](LICENSE) file for details.

## 🚧 Building a Real Application

To turn this into a working media processing platform, you would need to:

1. **Build an API** - Create a Cloud Run service that handles file uploads
2. **Build a Processor** - Create a Cloud Run job that generates thumbnails
3. **Build a Frontend** - Create a React/Vue app for the user interface
4. **Update the manifests** - Replace the placeholder container images:
   ```yaml
   # In infrastructure/run/api-service.yaml
   image: gcr.io/${PROJECT_ID}/cloudsnap-api:latest
   
   # In infrastructure/run/processor-job.yaml
   image: gcr.io/${PROJECT_ID}/cloudsnap-processor:latest
   ```
5. **Redeploy** - Run `./scripts/03-deploy.sh` to update

---

**Note:** This is an infrastructure demo for educational purposes. The GCP resources are real and will incur charges - always run `./scripts/04-teardown.sh` when done!