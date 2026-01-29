# Production-Grade RNA-Seq Analysis Platform on Kubernetes

[![Nextflow](https://img.shields.io/badge/nextflow-%E2%89%A523.04.0-brightgreen.svg)](https://www.nextflow.io/)
[![Kubernetes](https://img.shields.io/badge/kubernetes-%3E%3D1.24-blue.svg)](https://kubernetes.io/)
[![Docker](https://img.shields.io/badge/docker-required-blue.svg)](https://www.docker.com/)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

A production-ready bioinformatics platform demonstrating enterprise-grade RNA-Seq analysis workflows orchestrated by Nextflow on Kubernetes. Built to showcase DevOps best practices in computational biology infrastructure.

## 🎯 Project Overview

This project demonstrates how to build and operate a **scalable bioinformatics platform** that processes RNA sequencing data to quantify gene expression. It's designed as a portfolio project for DevOps engineers entering the bioinformatics space.

### What This Pipeline Does (DevOps Translation)

```
Raw Sequencing Data (FASTQ) → Quality Control → Alignment → Quantification → Report
     (Raw Logs)                (Validation)     (ETL)      (Aggregation)   (Dashboard)
```

**Business Value**: Identify which genes are active in cells - critical for drug discovery, diagnostics, and personalized medicine.

## 🏗️ Architecture

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         GitHub Repository                        │
│                    (Source Code + Workflows)                     │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│                      GitHub Actions CI/CD                        │
│  • Lint Nextflow Pipeline                                        │
│  • Build & Push Docker Images                                    │
│  • Run Test Dataset                                              │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│                   Container Registry (Docker Hub)                │
│  • fastqc:latest                                                 │
│  • star:latest                                                   │
│  • salmon:latest                                                 │
│  • multiqc:latest                                                │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster (EKS/GKE)                  │
│                                                                   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │              Nextflow Head Pod                           │   │
│  │  • Reads workflow definition                             │   │
│  │  • Spawns worker pods via K8s API                        │   │
│  │  • Monitors execution                                    │   │
│  └─────────────────────┬───────────────────────────────────┘   │
│                        │                                         │
│                        ▼                                         │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │           Ephemeral Worker Pods                          │   │
│  │  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐   │   │
│  │  │ FastQC  │  │  STAR   │  │ Salmon  │  │MultiQC  │   │   │
│  │  │  Pod    │  │  Pod    │  │  Pod    │  │  Pod    │   │   │
│  │  │ 2 CPU   │  │ 8 CPU   │  │ 4 CPU   │  │ 1 CPU   │   │   │
│  │  │ 4 GB    │  │ 32 GB   │  │ 8 GB    │  │ 2 GB    │   │   │
│  │  └─────────┘  └─────────┘  └─────────┘  └─────────┘   │   │
│  └─────────────────────┬───────────────────────────────────┘   │
│                        │                                         │
│                        ▼                                         │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │     Persistent Volume (ReadWriteMany - EFS/Filestore)   │   │
│  │  • Reference genome (~30 GB)                             │   │
│  │  • Input FASTQ files                                     │   │
│  │  • Intermediate results                                  │   │
│  │  • Final outputs                                         │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

### Technology Stack

| Component | Technology | Purpose |
|-----------|-----------|---------|
| **Workflow Orchestration** | Nextflow 23.04+ | DAG-based pipeline execution |
| **Container Orchestration** | Kubernetes 1.24+ | Dynamic pod scheduling |
| **Container Runtime** | Docker | Tool isolation |
| **CI/CD** | GitHub Actions | Automated testing & deployment |
| **Storage** | EFS (AWS) / Filestore (GCP) | Shared genomic data |
| **Quality Control** | FastQC 0.12.1 | Sequencing quality assessment |
| **Alignment** | STAR 2.7.10 | RNA-to-genome mapping |
| **Quantification** | Salmon 1.9.0 | Gene expression counting |
| **Reporting** | MultiQC 1.14 | Unified QC dashboard |

## 📁 Project Structure

```
bioinformatics-platform/
├── workflows/
│   ├── main.nf                    # Main Nextflow pipeline
│   ├── nextflow.config            # Configuration (resources, profiles)
│   └── modules/                   # Modular process definitions
│       ├── fastqc.nf
│       ├── star.nf
│       ├── salmon.nf
│       └── multiqc.nf
├── containers/
│   ├── fastqc/
│   │   └── Dockerfile             # FastQC container
│   ├── star/
│   │   └── Dockerfile             # STAR aligner container
│   ├── salmon/
│   │   └── Dockerfile             # Salmon quantification container
│   └── multiqc/
│       └── Dockerfile             # MultiQC reporting container
├── k8s/
│   ├── namespace.yaml             # Kubernetes namespace
│   ├── rbac.yaml                  # ServiceAccount, Role, RoleBinding
│   ├── storage.yaml               # PVC for shared data
│   ├── resource-quota.yaml        # Resource limits
│   └── nextflow-pod.yaml          # Nextflow head pod definition
├── .github/
│   └── workflows/
│       └── pipeline-ci.yml        # CI/CD pipeline
├── data/
│   ├── reference/                 # Reference genome (downloaded)
│   ├── fastq/                     # Input FASTQ files (test dataset)
│   └── results/                   # Output directory
├── scripts/
│   ├── download-test-data.sh      # Download public test dataset
│   ├── setup-k8s.sh               # Kubernetes setup automation
│   └── run-pipeline.sh            # Pipeline execution wrapper
├── docs/
│   ├── SETUP.md                   # Setup instructions
│   ├── ARCHITECTURE.md            # Detailed architecture
│   ├── BIOINFORMATICS-PRIMER.md   # Biology concepts for DevOps
│   └── TROUBLESHOOTING.md         # Common issues & solutions
└── README.md                      # This file
```

## 🚀 Quick Start

### Prerequisites

- **Local Development**:
  - Docker Desktop
  - Nextflow 23.04+
  - 16 GB RAM minimum
  
- **Kubernetes Deployment**:
  - Kubernetes cluster (EKS, GKE, or local)
  - `kubectl` configured
  - 100 GB storage available
  - Helm 3+ (optional, for monitoring)

### 1. Run Locally (Docker)

```bash
# Clone repository
git clone https://github.com/ngandjuialphonse/optimum-space-services.git
cd optimum-space-services/bioinformatics-platform

# Download test dataset (small, public data)
bash scripts/download-test-data.sh

# Run pipeline with Docker profile
nextflow run workflows/main.nf \
  -profile docker \
  --reads "data/fastq/*_R{1,2}.fastq.gz" \
  --genome "data/reference/genome.fa" \
  --outdir "data/results"
```

### 2. Deploy to Kubernetes

```bash
# Set up Kubernetes resources
bash scripts/setup-k8s.sh

# Run pipeline on Kubernetes
bash scripts/run-pipeline.sh
```

## 🧬 Understanding the Pipeline (DevOps Perspective)

### Stage 1: Quality Control (FastQC)
**What**: Validate raw sequencing data quality  
**Analogy**: Like checking HTTP response times and error rates in logs  
**Resources**: 2 CPU, 4 GB RAM  
**Time**: ~5 minutes per sample  

### Stage 2: Alignment (STAR)
**What**: Map RNA sequences to reference genome  
**Analogy**: Like joining log entries with a user database (massive JOIN query)  
**Resources**: 8 CPU, 32 GB RAM (genome index is huge!)  
**Time**: ~30 minutes per sample  

### Stage 3: Quantification (Salmon)
**What**: Count reads per gene  
**Analogy**: Like `GROUP BY gene_name` aggregation  
**Resources**: 4 CPU, 8 GB RAM  
**Time**: ~10 minutes per sample  

### Stage 4: Report (MultiQC)
**What**: Unified QC dashboard  
**Analogy**: Like Grafana - combines metrics from multiple sources  
**Resources**: 1 CPU, 2 GB RAM  
**Time**: ~2 minutes  

**Total Pipeline Time**: ~50 minutes per sample (parallelizable)

## ⚙️ Kubernetes Configuration Explained

### RBAC Setup (Why Nextflow Needs Permissions)

Nextflow dynamically creates and destroys pods for each task. It needs specific Kubernetes permissions:

```yaml
# ServiceAccount: Identity for Nextflow
apiVersion: v1
kind: ServiceAccount
metadata:
  name: nextflow-sa
  namespace: bioinformatics

---
# Role: What actions are allowed
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: nextflow-role
rules:
- apiGroups: [""]
  resources: ["pods", "pods/log", "pods/status"]
  verbs: ["get", "list", "watch", "create", "delete"]  # Create/delete worker pods
- apiGroups: [""]
  resources: ["persistentvolumeclaims"]
  verbs: ["get", "list"]  # Access shared storage

---
# RoleBinding: Connect ServiceAccount to Role
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: nextflow-rolebinding
subjects:
- kind: ServiceAccount
  name: nextflow-sa
roleRef:
  kind: Role
  name: nextflow-role
```

**DevOps Analogy**: Like giving Jenkins a service account to deploy applications - it needs permissions to create resources.

### Persistent Volume Claims (Handling Multi-GB Data)

Genomic data is huge and needs to be shared across pods:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: genomics-data-pvc
spec:
  accessModes:
    - ReadWriteMany  # Multiple pods read/write simultaneously
  storageClassName: efs-sc  # AWS EFS (managed NFS)
  resources:
    requests:
      storage: 100Gi
```

**Why ReadWriteMany?**
- Reference genome (~30 GB) accessed by all alignment pods
- Intermediate files passed between stages
- Final results written to shared location

**Storage Options**:
- **AWS**: EFS (Elastic File System) - managed NFS
- **GCP**: Filestore - managed NFS
- **Azure**: Azure Files
- **On-prem**: NFS server or Ceph

### Resource Management

Each tool has different resource requirements:

```groovy
// nextflow.config
process {
  withName: FASTQC {
    cpus = 2
    memory = '4 GB'
  }
  withName: STAR_ALIGN {
    cpus = 8
    memory = '32 GB'  // Genome index is huge!
  }
  withName: SALMON_QUANT {
    cpus = 4
    memory = '8 GB'
  }
}
```

**Cost Optimization**:
- Use spot instances for non-critical tasks
- Auto-scale cluster based on workload
- Set resource quotas to prevent runaway jobs

## 🔄 CI/CD Pipeline

### GitHub Actions Workflow

```yaml
# .github/workflows/pipeline-ci.yml
name: Bioinformatics Pipeline CI

on: [push, pull_request]

jobs:
  lint:
    # Validate Nextflow syntax
    
  build-containers:
    # Build and push Docker images
    
  test-pipeline:
    # Run test dataset
    
  deploy:
    # Deploy to Kubernetes (on main branch)
```

**What Gets Tested**:
1. **Lint**: Nextflow syntax validation
2. **Build**: Container images built and pushed
3. **Test**: Pipeline runs on small test dataset
4. **Deploy**: Automatic deployment to staging

## 📊 Test Dataset

We use a **small, public dataset** from NCBI to avoid massive cloud costs:

- **Source**: Sequence Read Archive (SRA)
- **Dataset**: SRR000001 (1000 reads, ~100 MB)
- **Reference**: Human chromosome 22 only (~50 MB)
- **Total Size**: ~150 MB (perfect for testing!)

**Download Script**:
```bash
bash scripts/download-test-data.sh
```

## 💰 Cost Estimation

### Development (Local)
- **Cost**: $0 (Docker Desktop)

### Testing (Cloud - 1 week)
- **EKS/GKE Control Plane**: ~$18/week
- **Worker Nodes**: 2x t3.large spot = ~$8/week
- **Storage**: 100 GB EFS = ~$8/week
- **Total**: ~$34/week

### Production (Monthly)
- **Control Plane**: ~$73/month
- **Worker Nodes**: Auto-scale (0-10 nodes)
- **Storage**: Tiered (hot + cold)
- **Estimated**: $200-500/month (depending on usage)

**Cost Optimization Tips**:
- Use spot instances (70% savings)
- Auto-scale to zero when idle
- Use S3/GCS for cold storage (cheaper than EFS)
- Set up budget alerts

## 📚 Learning Resources

- **[Bioinformatics Primer](docs/BIOINFORMATICS-PRIMER.md)**: Biology concepts explained with DevOps analogies
- **[Architecture Deep Dive](docs/ARCHITECTURE.md)**: Detailed system design
- **[Setup Guide](docs/SETUP.md)**: Step-by-step deployment instructions
- **[Troubleshooting](docs/TROUBLESHOOTING.md)**: Common issues and solutions

## 🎯 Portfolio Impact

### What This Demonstrates

✅ **Cloud Infrastructure**: Kubernetes, RBAC, storage, networking  
✅ **CI/CD**: GitHub Actions, automated testing, deployment  
✅ **Containerization**: Docker best practices, multi-stage builds  
✅ **Workflow Orchestration**: Nextflow (like Airflow for bio)  
✅ **Resource Management**: CPU/memory allocation, cost optimization  
✅ **Domain Knowledge**: Understanding of bioinformatics workflows  

### Interview Talking Points

- "Built a production-grade RNA-Seq pipeline on Kubernetes"
- "Implemented RBAC for Nextflow to manage ephemeral pods"
- "Optimized resource allocation for 32 GB alignment jobs"
- "Set up ReadWriteMany PVCs for shared genomic data"
- "Created CI/CD pipeline with automated testing"
- "Reduced costs 70% using spot instances"

## 🤝 Contributing

This is a portfolio/learning project. Feel free to:
- Fork and adapt for your own learning
- Submit issues for questions
- Suggest improvements via PRs

## 📄 License

MIT License - See [LICENSE](LICENSE) file

## 🙏 Acknowledgments

- **nf-core**: Nextflow best practices
- **NCBI SRA**: Public test datasets
- **Kubernetes community**: Excellent documentation

---

**Built with ❤️ by a DevOps Engineer learning Bioinformatics**

*Questions? Open an issue or reach out!*
