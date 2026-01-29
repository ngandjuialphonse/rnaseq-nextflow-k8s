# FastQC Container
# =================
# FastQC is a quality control tool for high-throughput sequence data
#
# DEVOPS ANALOGY:
# Like a log validator - checks if data is good quality
#
# WHAT IT DOES:
# - Analyzes FASTQ files
# - Generates quality metrics
# - Creates HTML reports with plots
#
# RESOURCES:
# - CPU: 2 cores
# - Memory: 4 GB
# - Time: ~5 minutes per sample
#
# ============================================================================

# Use Ubuntu as base image (stable, well-supported)
FROM ubuntu:22.04 AS builder

# Metadata
LABEL maintainer="devops-team@company.com"
LABEL description="FastQC for RNA-Seq quality control"
LABEL version="0.12.1"

# Avoid interactive prompts during build
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt-get update && apt-get install -y \
    wget \
    unzip \
    openjdk-11-jre-headless \
    perl \
    fontconfig \
    && rm -rf /var/lib/apt/lists/*

# Download and install FastQC
RUN wget https://www.bioinformatics.babraham.ac.uk/projects/fastqc/fastqc_v0.12.1.zip \
    && unzip fastqc_v0.12.1.zip \
    && chmod +x FastQC/fastqc \
    && rm fastqc_v0.12.1.zip

# Final stage (smaller image)
FROM ubuntu:22.04

# Install runtime dependencies only
RUN apt-get update && apt-get install -y \
    openjdk-11-jre-headless \
    perl \
    fontconfig \
    && rm -rf /var/lib/apt/lists/*

# Copy FastQC from builder
COPY --from=builder /FastQC /opt/fastqc

# Add to PATH
ENV PATH="/opt/fastqc:${PATH}"

# Create non-root user (security best practice)
RUN useradd -m -u 1000 -s /bin/bash biouser
USER biouser
WORKDIR /home/biouser

# Health check (optional but recommended)
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD fastqc --version || exit 1

# Default command
ENTRYPOINT ["fastqc"]
CMD ["--help"]

# ============================================================================
# BUILD AND RUN
# ============================================================================
#
# Build:
#   docker build -t rnaseq-fastqc:0.12.1 .
#
# Run:
#   docker run --rm -v $(pwd):/data rnaseq-fastqc:0.12.1 \
#     -t 2 -o /data /data/sample_R1.fastq.gz
#
# Test:
#   docker run --rm rnaseq-fastqc:0.12.1 --version
#
# ============================================================================
