# Project Structure Explained

## 📁 Directory Layout

This document explains **why** each directory exists and **what** goes in it. Think of this as the "architecture documentation" for the codebase.

```
bioinformatics-platform/
├── workflows/              # Pipeline definitions (the "application code")
├── containers/             # Docker images (the "services")
├── k8s/                    # Kubernetes configs (the "infrastructure")
├── .github/workflows/      # CI/CD (the "deployment automation")
├── data/                   # Data storage (the "database")
├── scripts/                # Automation scripts (the "utilities")
└── docs/                   # Documentation (the "wiki")
```

---

## 📂 `/workflows` - Pipeline Definitions

**Purpose**: Contains the Nextflow workflow code - this is the "application logic"

**DevOps Analogy**: Like your application source code in a microservices project

### Files:

#### `main.nf` - Main Pipeline
**What**: The entry point for the pipeline  
**Contains**:
- Workflow definition (DAG of tasks)
- Process definitions (individual steps)
- Channel operations (data flow)

**Analogy**: Like `main.py` in a Python app or `index.js` in Node.js

**Example Structure**:
```groovy
// Define parameters (like CLI arguments)
params.reads = "/data/fastq/*_R{1,2}.fastq.gz"
params.genome = "/data/reference/genome.fa"
params.outdir = "results"

// Define workflow (the DAG)
workflow {
  read_pairs_ch = Channel.fromFilePairs(params.reads)
  
  FASTQC(read_pairs_ch)
  STAR_ALIGN(read_pairs_ch, params.genome)
  SALMON_QUANT(STAR_ALIGN.out)
  MULTIQC(FASTQC.out.mix(SALMON_QUANT.out).collect())
}

// Define processes (individual tasks)
process FASTQC {
  input:
  tuple val(sample_id), path(reads)
  
  output:
  path("${sample_id}_fastqc.html")
  
  script:
  """
  fastqc -t ${task.cpus} ${reads}
  """
}
```

#### `nextflow.config` - Configuration
**What**: Resource allocation, profiles, executor settings  
**Contains**:
- Process resource requirements (CPU, memory)
- Execution profiles (docker, kubernetes, local)
- Container image locations
- Kubernetes-specific settings

**Analogy**: Like `application.yml` in Spring Boot or `.env` files

**Example**:
```groovy
// Global settings
manifest {
  name = 'RNA-Seq Pipeline'
  version = '1.0.0'
  description = 'Production RNA-Seq analysis'
}

// Execution profiles
profiles {
  docker {
    docker.enabled = true
    process.container = 'your-registry/tool:version'
  }
  
  kubernetes {
    process.executor = 'k8s'
    k8s {
      namespace = 'bioinformatics'
      serviceAccount = 'nextflow-sa'
      storageClaimName = 'genomics-data-pvc'
      storageMountPath = '/data'
    }
  }
}

// Resource allocation per process
process {
  withName: FASTQC {
    container = 'your-registry/fastqc:0.12.1'
    cpus = 2
    memory = '4 GB'
  }
  
  withName: STAR_ALIGN {
    container = 'your-registry/star:2.7.10'
    cpus = 8
    memory = '32 GB'  // Large genome index!
  }
  
  withName: SALMON_QUANT {
    container = 'your-registry/salmon:1.9.0'
    cpus = 4
    memory = '8 GB'
  }
}
```

#### `/modules` - Modular Process Definitions
**What**: Reusable process definitions (optional, for cleaner code)  
**Why**: Separate concerns, easier testing, reusability

**Analogy**: Like splitting a monolith into microservices

**Example** (`modules/fastqc.nf`):
```groovy
process FASTQC {
  tag "$sample_id"
  publishDir "${params.outdir}/fastqc", mode: 'copy'
  
  input:
  tuple val(sample_id), path(reads)
  
  output:
  path("${sample_id}_fastqc.html"), emit: html
  path("${sample_id}_fastqc.zip"), emit: zip
  
  script:
  """
  fastqc -t ${task.cpus} -o . ${reads}
  """
}
```

---

## 🐳 `/containers` - Docker Images

**Purpose**: Dockerfile for each bioinformatics tool  
**Why**: Reproducibility, version control, portability

**DevOps Analogy**: Like building microservice containers

### Structure:
```
containers/
├── fastqc/
│   └── Dockerfile
├── star/
│   └── Dockerfile
├── salmon/
│   └── Dockerfile
└── multiqc/
    └── Dockerfile
```

### Example: `containers/fastqc/Dockerfile`

```dockerfile
# Multi-stage build for smaller images
FROM ubuntu:22.04 AS builder

# Install dependencies
RUN apt-get update && apt-get install -y \
    wget \
    unzip \
    openjdk-11-jre-headless \
    && rm -rf /var/lib/apt/lists/*

# Download and install FastQC
RUN wget https://www.bioinformatics.babraham.ac.uk/projects/fastqc/fastqc_v0.12.1.zip \
    && unzip fastqc_v0.12.1.zip \
    && chmod +x FastQC/fastqc

# Final stage
FROM ubuntu:22.04
COPY --from=builder /FastQC /opt/fastqc
RUN apt-get update && apt-get install -y openjdk-11-jre-headless \
    && rm -rf /var/lib/apt/lists/*

ENV PATH="/opt/fastqc:${PATH}"

ENTRYPOINT ["fastqc"]
```

**Best Practices**:
- ✅ Pin versions (e.g., `ubuntu:22.04`, not `ubuntu:latest`)
- ✅ Use multi-stage builds to reduce image size
- ✅ Clean up package manager caches
- ✅ Run as non-root user (security)
- ✅ Add health checks

---

## ☸️ `/k8s` - Kubernetes Configurations

**Purpose**: Infrastructure-as-Code for Kubernetes resources  
**Why**: Version control, reproducibility, automation

**DevOps Analogy**: Like Terraform for Kubernetes

### Files:

#### `namespace.yaml` - Logical Isolation
**What**: Create a dedicated namespace for bioinformatics workloads  
**Why**: Multi-tenancy, resource quotas, RBAC isolation

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: bioinformatics
  labels:
    name: bioinformatics
    purpose: genomics-pipelines
```

**Analogy**: Like a VPC or project in cloud providers

#### `rbac.yaml` - Permissions
**What**: ServiceAccount, Role, RoleBinding for Nextflow  
**Why**: Nextflow needs to create/delete pods dynamically

```yaml
# 1. ServiceAccount: Identity for Nextflow
apiVersion: v1
kind: ServiceAccount
metadata:
  name: nextflow-sa
  namespace: bioinformatics

---
# 2. Role: What actions are allowed
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: nextflow-role
  namespace: bioinformatics
rules:
- apiGroups: [""]
  resources: ["pods", "pods/log", "pods/status"]
  verbs: ["get", "list", "watch", "create", "delete"]
- apiGroups: [""]
  resources: ["persistentvolumeclaims"]
  verbs: ["get", "list"]

---
# 3. RoleBinding: Connect ServiceAccount to Role
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: nextflow-rolebinding
  namespace: bioinformatics
subjects:
- kind: ServiceAccount
  name: nextflow-sa
  namespace: bioinformatics
roleRef:
  kind: Role
  name: nextflow-role
  apiGroup: rbac.authorization.k8s.io
```

**Why These Permissions?**
- **pods**: Create worker pods for each task
- **pods/log**: Monitor task execution
- **pods/status**: Check if tasks completed
- **persistentvolumeclaims**: Access shared storage

**Analogy**: Like IAM roles in AWS - giving Nextflow permissions to manage resources

#### `storage.yaml` - Persistent Storage
**What**: PersistentVolumeClaim for shared genomic data  
**Why**: Multi-GB files need to be shared across pods

```yaml
# StorageClass for EFS (AWS example)
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: efs-sc
provisioner: efs.csi.aws.com
parameters:
  provisioningMode: efs-ap
  fileSystemId: fs-12345678  # Your EFS ID
  directoryPerms: "700"

---
# PersistentVolumeClaim
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: genomics-data-pvc
  namespace: bioinformatics
spec:
  accessModes:
    - ReadWriteMany  # Multiple pods read/write simultaneously
  storageClassName: efs-sc
  resources:
    requests:
      storage: 100Gi
```

**Why ReadWriteMany?**
- Reference genome (~30 GB) accessed by all alignment pods
- Intermediate files passed between stages
- Multiple samples processed in parallel

**Storage Options**:
| Provider | Service | Type | Use Case |
|----------|---------|------|----------|
| AWS | EFS | NFS | Multi-AZ, ReadWriteMany |
| GCP | Filestore | NFS | Multi-zone, ReadWriteMany |
| Azure | Azure Files | SMB | Multi-region |
| On-prem | NFS/Ceph | NFS | Self-hosted |

**Analogy**: Like a shared NFS mount for distributed workers

#### `resource-quota.yaml` - Resource Limits
**What**: Prevent runaway jobs from consuming all cluster resources  
**Why**: Cost control, multi-tenancy, stability

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: bioinformatics-quota
  namespace: bioinformatics
spec:
  hard:
    requests.cpu: "100"          # Max 100 CPUs
    requests.memory: 500Gi       # Max 500 GB RAM
    persistentvolumeclaims: "10" # Max 10 PVCs
    pods: "50"                   # Max 50 pods
```

**Analogy**: Like AWS Service Quotas or budget alerts

#### `nextflow-pod.yaml` - Nextflow Head Pod
**What**: The main Nextflow process that orchestrates worker pods  
**Why**: Nextflow itself runs as a pod in Kubernetes

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nextflow-head
  namespace: bioinformatics
spec:
  serviceAccountName: nextflow-sa  # Use the ServiceAccount with permissions
  containers:
  - name: nextflow
    image: nextflow/nextflow:23.04.0
    command: ["/bin/bash"]
    args: ["-c", "nextflow run /workflows/main.nf -profile kubernetes"]
    volumeMounts:
    - name: workflows
      mountPath: /workflows
    - name: data
      mountPath: /data
    resources:
      requests:
        cpu: "2"
        memory: "4Gi"
      limits:
        cpu: "4"
        memory: "8Gi"
  volumes:
  - name: workflows
    configMap:
      name: nextflow-workflows
  - name: data
    persistentVolumeClaim:
      claimName: genomics-data-pvc
```

**Analogy**: Like a Jenkins master node that spawns worker agents

---

## 🔄 `/.github/workflows` - CI/CD

**Purpose**: Automated testing and deployment  
**Why**: Catch errors early, automate repetitive tasks

**DevOps Analogy**: Like Jenkins pipelines or GitLab CI

### File: `pipeline-ci.yml`

```yaml
name: Bioinformatics Pipeline CI

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  # Job 1: Lint Nextflow code
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Install Nextflow
        run: |
          curl -s https://get.nextflow.io | bash
          sudo mv nextflow /usr/local/bin/
      
      - name: Lint Pipeline
        run: nextflow run workflows/main.nf --help
      
      - name: Validate Config
        run: nextflow config workflows/nextflow.config

  # Job 2: Build and push Docker images
  build-containers:
    runs-on: ubuntu-latest
    needs: lint
    strategy:
      matrix:
        tool: [fastqc, star, salmon, multiqc]
    steps:
      - uses: actions/checkout@v3
      
      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v2
      
      - name: Login to Docker Hub
        uses: docker/login-action@v2
        with:
          username: ${{ secrets.DOCKER_USERNAME }}
          password: ${{ secrets.DOCKER_PASSWORD }}
      
      - name: Build and Push
        uses: docker/build-push-action@v4
        with:
          context: ./containers/${{ matrix.tool }}
          push: true
          tags: |
            yourname/${{ matrix.tool }}:${{ github.sha }}
            yourname/${{ matrix.tool }}:latest
          cache-from: type=gha
          cache-to: type=gha,mode=max

  # Job 3: Test pipeline with small dataset
  test-pipeline:
    runs-on: ubuntu-latest
    needs: build-containers
    steps:
      - uses: actions/checkout@v3
      
      - name: Download Test Data
        run: bash scripts/download-test-data.sh
      
      - name: Run Pipeline
        run: |
          nextflow run workflows/main.nf \
            -profile test,docker \
            --outdir results
      
      - name: Upload Results
        uses: actions/upload-artifact@v3
        with:
          name: test-results
          path: results/

  # Job 4: Deploy to Kubernetes (main branch only)
  deploy:
    runs-on: ubuntu-latest
    needs: test-pipeline
    if: github.ref == 'refs/heads/main'
    steps:
      - uses: actions/checkout@v3
      
      - name: Configure kubectl
        uses: azure/k8s-set-context@v3
        with:
          kubeconfig: ${{ secrets.KUBE_CONFIG }}
      
      - name: Apply Kubernetes Configs
        run: |
          kubectl apply -f k8s/namespace.yaml
          kubectl apply -f k8s/rbac.yaml
          kubectl apply -f k8s/storage.yaml
          kubectl apply -f k8s/resource-quota.yaml
```

**What Gets Tested**:
1. **Lint**: Syntax validation (catch typos)
2. **Build**: Container images (ensure they build)
3. **Test**: Run on small dataset (functional test)
4. **Deploy**: Push to Kubernetes (only on main branch)

---

## 📊 `/data` - Data Storage

**Purpose**: Store input data, reference genomes, and results  
**Why**: Separation of code and data

**DevOps Analogy**: Like a database or S3 bucket

### Structure:
```
data/
├── reference/          # Reference genome and annotations
│   ├── genome.fa       # FASTA file (3 GB)
│   ├── genome.gtf      # Gene annotations (200 MB)
│   └── star_index/     # Pre-built STAR index (30 GB)
├── fastq/              # Input FASTQ files
│   ├── sample1_R1.fastq.gz
│   ├── sample1_R2.fastq.gz
│   ├── sample2_R1.fastq.gz
│   └── sample2_R2.fastq.gz
└── results/            # Pipeline outputs
    ├── fastqc/
    ├── aligned/
    ├── counts/
    └── multiqc_report.html
```

**Best Practices**:
- ✅ Use `.gitignore` for data files (don't commit to Git)
- ✅ Document data sources and versions
- ✅ Use checksums (MD5) to verify downloads
- ✅ Separate raw data from processed data

---

## 🛠️ `/scripts` - Automation Scripts

**Purpose**: Helper scripts for common tasks  
**Why**: Automate repetitive operations

**DevOps Analogy**: Like Makefile or npm scripts

### Files:

#### `download-test-data.sh`
**What**: Download small public dataset for testing  
**Why**: Avoid manual downloads, ensure consistency

```bash
#!/bin/bash
set -euo pipefail

# Download test FASTQ files from NCBI SRA
echo "Downloading test dataset..."
wget -O data/fastq/test_R1.fastq.gz \
  ftp://ftp.sra.ebi.ac.uk/vol1/fastq/SRR000/SRR000001/SRR000001_1.fastq.gz

wget -O data/fastq/test_R2.fastq.gz \
  ftp://ftp.sra.ebi.ac.uk/vol1/fastq/SRR000/SRR000001/SRR000001_2.fastq.gz

# Download reference genome (chromosome 22 only)
echo "Downloading reference genome..."
wget -O data/reference/genome.fa.gz \
  ftp://ftp.ensembl.org/pub/release-110/fasta/homo_sapiens/dna/Homo_sapiens.GRCh38.dna.chromosome.22.fa.gz

gunzip data/reference/genome.fa.gz

echo "Download complete!"
```

#### `setup-k8s.sh`
**What**: Apply all Kubernetes configurations  
**Why**: One-command setup

```bash
#!/bin/bash
set -euo pipefail

echo "Setting up Kubernetes resources..."

kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/rbac.yaml
kubectl apply -f k8s/storage.yaml
kubectl apply -f k8s/resource-quota.yaml

echo "Kubernetes setup complete!"
```

#### `run-pipeline.sh`
**What**: Run pipeline on Kubernetes with proper settings  
**Why**: Simplify execution, avoid typos

```bash
#!/bin/bash
set -euo pipefail

# Run Nextflow pipeline on Kubernetes
nextflow run workflows/main.nf \
  -profile kubernetes \
  --reads "/data/fastq/*_R{1,2}.fastq.gz" \
  --genome "/data/reference/genome.fa" \
  --outdir "/data/results" \
  -with-report report.html \
  -with-timeline timeline.html \
  -with-dag dag.html
```

---

## 📚 `/docs` - Documentation

**Purpose**: Comprehensive guides for users and developers  
**Why**: Knowledge transfer, onboarding, troubleshooting

### Files:

- **BIOINFORMATICS-PRIMER.md**: Biology concepts for DevOps engineers
- **SETUP.md**: Step-by-step deployment instructions
- **ARCHITECTURE.md**: Detailed system design
- **TROUBLESHOOTING.md**: Common issues and solutions
- **COST-OPTIMIZATION.md**: Tips for reducing cloud costs
- **INTERVIEW-PREP.md**: Questions you'll be asked

---

## 🎯 Summary: How It All Fits Together

```
1. Developer writes Nextflow code (workflows/)
2. CI/CD builds Docker images (containers/)
3. CI/CD tests pipeline (.github/workflows/)
4. Kubernetes resources created (k8s/)
5. Nextflow head pod spawns worker pods
6. Workers read data from PVC (data/)
7. Results written back to PVC
8. MultiQC generates final report
```

**Analogy**: Like a microservices application:
- **workflows/** = application code
- **containers/** = service definitions
- **k8s/** = infrastructure
- **.github/workflows/** = CI/CD
- **data/** = database
- **scripts/** = utilities
- **docs/** = wiki

---

**Next Steps**: Now that you understand the structure, let's start building each component!
