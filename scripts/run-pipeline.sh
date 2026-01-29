#!/bin/bash
# ============================================================================
# Run Pipeline Script
# =====================
#
# This script runs the RNA-Seq pipeline on Kubernetes.
#
# WHAT IT DOES:
# 1. Sets pipeline parameters.
# 2. Executes the `nextflow run` command with the kubernetes profile.
#
# DEVOPS ANALOGY:
# Like a deployment script that triggers a Jenkins job or Argo Workflow.
#
# USAGE:
#   bash scripts/run-pipeline.sh
#
# ============================================================================

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
WORKDIR="$(dirname "$0")/.."

print_header() {
    echo ""
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║           Running RNA-Seq Pipeline on Kubernetes             ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo ""
}

print_info() {
    echo -e "${YELLOW}[INFO]${NC} $1"
}

# Run Nextflow pipeline
print_header
print_info "Starting Nextflow pipeline..."
print_info "Profile: kubernetes"
print_info "Check progress with: kubectl get pods -n bioinformatics -w"

nextflow run "$WORKDIR/workflows/main.nf" \
  -profile kubernetes \
  --reads "/data/fastq/*_R{1,2}.fastq.gz" \
  --genome "/data/reference/genome.fa" \
  --gtf "/data/reference/genes.gtf" \
  --outdir "/data/results" \
  -with-report report.html \
  -with-timeline timeline.html \
  -with-dag dag.html

print_info "Pipeline execution submitted."
print_info "Final report will be available in the shared volume at /data/results/multiqc_report.html"
