# Setup Guide: RNA-Seq Analysis Platform

This guide provides step-by-step instructions for setting up and running the RNA-Seq analysis platform. It covers both local development with Docker and production deployment on Kubernetes.

## 🎯 Table of Contents

1.  [Prerequisites](#1-prerequisites)
2.  [Local Development Setup (Docker)](#2-local-development-setup-docker)
3.  [Kubernetes Deployment Setup](#3-kubernetes-deployment-setup)
4.  [Data Setup](#4-data-setup)
5.  [Running the Pipeline](#5-running-the-pipeline)
6.  [Viewing Results](#6-viewing-results)

---

## 1. Prerequisites

Before you begin, ensure you have the following software installed.

### For Local Development

| Software | Minimum Version | Installation Guide | Purpose |
| :--- | :--- | :--- | :--- |
| **Git** | 2.x | [git-scm.com](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git) | Version control |
| **Nextflow** | 23.04.0 | [nextflow.io/docs/latest/getstarted.html](https://www.nextflow.io/docs/latest/getstarted.html) | Pipeline orchestration |
| **Docker Desktop** | 4.x | [docker.com/products/docker-desktop](https://www.docker.com/products/docker-desktop) | Container runtime |

**Hardware Recommendations (Local):**
- **CPU**: 8+ cores
- **Memory**: 32+ GB RAM (STAR aligner requires significant memory)
- **Disk**: 100+ GB free space

### For Kubernetes Deployment

| Software | Minimum Version | Installation Guide | Purpose |
| :--- | :--- | :--- | :--- |
| **kubectl** | 1.24 | [kubernetes.io/docs/tasks/tools/](https://kubernetes.io/docs/tasks/tools/) | Kubernetes CLI |
| **Helm** | 3.x | [helm.sh/docs/intro/install/](https://helm.sh/docs/intro/install/) | Package manager (optional) |
| **Cloud CLI** | latest | (e.g., `aws`, `gcloud`, `az`) | Cloud provider interaction |

**Cloud Infrastructure:**
- A running Kubernetes cluster (EKS, GKE, AKS, or self-hosted).
- A configured `kubeconfig` file pointing to your cluster.
- A network file system (NFS) like AWS EFS, GCP Filestore, or Azure Files for shared storage.

---

## 2. Local Development Setup (Docker)

This setup is ideal for testing, development, and running the pipeline on a small scale.

### Step 1: Clone the Repository

```bash
git clone https://github.com/ngandjuialphonse/optimum-space-services.git
cd optimum-space-services/bioinformatics-platform
```

### Step 2: Install Nextflow

Nextflow requires Java 8 or later. The installation script handles this for you.

```bash
# Download and install Nextflow
curl -s https://get.nextflow.io | bash

# Move to a directory in your PATH
sudo mv nextflow /usr/local/bin/

# Verify installation
nextflow -version
```

### Step 3: Start Docker Desktop

Ensure Docker Desktop is running and has sufficient resources allocated.

- **Memory**: At least 16 GB allocated to Docker.
- **CPUs**: At least 4 CPUs allocated.

You can configure this in Docker Desktop settings: `Settings > Resources`.

### Step 4: Run a Test

To confirm your local setup is working, run the pipeline with the `--help` flag.

```bash
nextflow run workflows/main.nf --help
```

This command will download the required container images and display the pipeline's help message. It confirms that Nextflow and Docker are communicating correctly.

---

## 3. Kubernetes Deployment Setup

This setup is for production-grade, scalable execution of the pipeline.

### Step 1: Configure `kubectl`

Ensure your `kubectl` is configured to connect to your Kubernetes cluster.

```bash
# Verify cluster connection
kubectl cluster-info

# Check nodes
kubectl get nodes
```

### Step 2: Set Up Shared Storage (One-Time Setup)

This is the most critical step. You need a `ReadWriteMany` storage solution. Below is an example for **AWS EFS**.

1.  **Create an EFS File System:**
    - Go to the AWS EFS console and create a new file system.
    - Ensure it's in the same VPC as your EKS cluster.
    - Note the **File System ID** (e.g., `fs-12345678`).

2.  **Install the EFS CSI Driver:**
    - This driver allows Kubernetes to provision and manage EFS volumes.
    - Follow the official AWS guide: [docs.aws.amazon.com/eks/latest/userguide/efs-csi.html](https://docs.aws.amazon.com/eks/latest/userguide/efs-csi.html)

3.  **Update the StorageClass:**
    - Open `k8s/storage.yaml`.
    - Find the `StorageClass` definition.
    - Replace `fs-XXXXXXXXX` with your actual EFS **File System ID**.

    ```yaml
    # k8s/storage.yaml
    apiVersion: storage.k8s.io/v1
    kind: StorageClass
    metadata:
      name: efs-sc
    provisioner: efs.csi.aws.com
    parameters:
      provisioningMode: efs-ap
      fileSystemId: fs-12345678 # <-- UPDATE THIS
      directoryPerms: "700"
    ```

### Step 3: Run the Setup Script

The `setup-k8s.sh` script automates the creation of all necessary Kubernetes resources.

```bash
# Make sure you are in the bioinformatics-platform directory
cd bioinformatics-platform

# Run the setup script
bash scripts/setup-k8s.sh
```

This script will:
1.  Create the `bioinformatics` namespace.
2.  Create the `nextflow-sa` ServiceAccount, Role, and RoleBinding.
3.  Create the `efs-sc` StorageClass.
4.  Create the `genomics-data-pvc` PersistentVolumeClaim and wait for it to be `Bound`.
5.  Create the `bioinformatics-quota` ResourceQuota and LimitRange.

---

## 4. Data Setup

The pipeline requires a reference genome and input FASTQ files.

### Option A: Download the Test Dataset

For quick testing, a script is provided to download a small, public dataset.

```bash
# This script downloads ~10 MB of data
bash scripts/download-test-data.sh
```

This will populate the `data/fastq` and `data/reference` directories.

### Option B: Using Your Own Data

1.  **Local:**
    - Place your reference genome (`.fa`) and annotations (`.gtf`) in the `data/reference/` directory.
    - Place your paired-end FASTQ files (`_R1.fastq.gz`, `_R2.fastq.gz`) in the `data/fastq/` directory.

2.  **Kubernetes:**
    - You need to upload your data to the shared Persistent Volume.
    - The easiest way is to use a temporary pod with the volume mounted.

    ```bash
    # 1. Start a temporary pod with the PVC mounted at /data
    kubectl run -it --rm upload-pod --image=ubuntu --restart=Never -n bioinformatics -- /bin/bash

    # 2. Inside the pod, install tools and download your data
    # apt-get update && apt-get install -y wget
    # wget -P /data/reference/ http://my-data-source/genome.fa
    # wget -P /data/fastq/ http://my-data-source/sample1_R1.fastq.gz
    # exit
    ```

---

## 5. Running the Pipeline

### Running Locally with Docker

Use the `docker` profile. This tells Nextflow to run each task in a Docker container.

```bash
nextflow run workflows/main.nf -profile docker
```

### Running on Kubernetes

Use the `kubernetes` profile. This tells Nextflow to create a new pod for each task.

```bash
# The run-pipeline.sh script wraps the full command
bash scripts/run-pipeline.sh

# Or run manually:
# nextflow run workflows/main.nf -profile kubernetes
```

**Monitoring the Kubernetes Run:**

```bash
# Watch pods being created and completed
kubectl get pods -n bioinformatics -w

# View logs of the main Nextflow pod
kubectl logs -f -n bioinformatics <nextflow-head-pod-name>

# View logs of a specific task pod
kubectl logs -f -n bioinformatics <task-pod-name>
```

### Common Parameters

You can override default parameters from the command line.

```bash
# Run with custom data and output directory
nextflow run workflows/main.nf -profile docker \
  --reads "/path/to/my/data/*_R{1,2}.fastq.gz" \
  --genome "/path/to/my/genome.fa" \
  --outdir "/path/to/my/results"
```

---

## 6. Viewing Results

Pipeline results will be saved to the directory specified by `--outdir` (default: `data/results`).

### Key Output Files

-   **`multiqc_report.html`**: The main report. Open this in a web browser to see an aggregated view of all QC metrics.
-   **`fastqc/`**: Individual FastQC reports for each input sample.
-   **`aligned/`**: BAM files containing the aligned reads.
-   **`counts/`**: Gene count matrices.

### Accessing Results

-   **Local:** The `data/results` directory will be created in your project folder.
-   **Kubernetes:** Results are on the shared Persistent Volume. You can access them by:
    1.  Using the same temporary pod method from the data setup.
    2.  Using `kubectl cp` to copy files from a pod to your local machine.

    ```bash
    # Example: Copy the MultiQC report locally
    # First, find a completed pod
    POD_NAME=$(kubectl get pods -n bioinformatics -l app=multiqc --field-selector=status.phase=Succeeded -o jsonpath=\'{.items[0].metadata.name}\')

    # Then, copy the file
    kubectl cp ${NAMESPACE}/${POD_NAME}:/path/to/results/multiqc_report.html ./multiqc_report.html
    ```

Congratulations! You have successfully set up and run a production-grade bioinformatics pipeline.
