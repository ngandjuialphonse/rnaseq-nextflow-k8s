#!/bin/bash
# ============================================================================
# Download Test Dataset Script
# ============================
#
# This script downloads a small, public dataset for testing the pipeline.
#
# WHAT IT DOES:
# 1. Downloads tiny FASTQ files (E. coli, ~1MB).
# 2. Downloads the corresponding reference genome and annotations.
#
# DEVOPS ANALOGY:
# Like a database seeding script - populates the environment with test data.
#
# USAGE:
#   bash scripts/download-test-data.sh
#
# ============================================================================

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
DATA_DIR="$(dirname "$0")/../data"
FASTQ_DIR="$DATA_DIR/fastq"
REF_DIR="$DATA_DIR/reference"

print_step() {
    echo -e "${GREEN}[STEP]${NC} $1"
}

print_info() {
    echo -e "${YELLOW}[INFO]${NC} $1"
}

# Create directories
mkdir -p "$FASTQ_DIR" "$REF_DIR"

print_step "Downloading test FASTQ files..."
# Using a small E. coli dataset from nf-core/test-datasets
wget -q -O "$FASTQ_DIR/test_R1.fastq.gz" \
  https://github.com/nf-core/test-datasets/raw/rnaseq/testdata/SRR6357070_1.fastq.gz
wget -q -O "$FASTQ_DIR/test_R2.fastq.gz" \
  https://github.com/nf-core/test-datasets/raw/rnaseq/testdata/SRR6357070_2.fastq.gz
print_info "✓ Downloaded FASTQ files."

print_step "Downloading reference genome and annotations..."
# E. coli reference genome (~5MB)
wget -q -O "$REF_DIR/genome.fa.gz" \
  https://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/000/005/845/GCF_000005845.2_ASM584v2/GCF_000005845.2_ASM584v2_genomic.fna.gz
gunzip -f "$REF_DIR/genome.fa.gz"

# Gene annotations
wget -q -O "$REF_DIR/genes.gtf.gz" \
  https://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/000/005/845/GCF_000005845.2_ASM584v2/GCF_000005845.2_ASM584v2_genomic.gtf.gz
gunzip -f "$REF_DIR/genes.gtf.gz"
print_info "✓ Downloaded reference files."

print_step "Test data setup complete!"
ls -lh "$FASTQ_DIR"
ls -lh "$REF_DIR"
