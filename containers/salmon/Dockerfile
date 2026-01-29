_# featureCounts (from Subread package) Container
# ===============================================
#
# NOTE: This container provides `featureCounts`, which is used for the
# quantification step in this pipeline. While the process in Nextflow is
# named `SALMON_QUANT` for historical reasons, it uses `featureCounts`.
#
# WHAT IT DOES:
# - Counts how many reads from a BAM file map to each gene.
# - Produces a simple count matrix (genes x samples).
#
# DEVOPS ANALOGY:
# Like a `GROUP BY` query in SQL - `SELECT gene, COUNT(*) FROM alignments GROUP BY gene`.
#
# RESOURCES:
# - CPU: 4+ cores
# - Memory: 8+ GB
# - Time: ~10 minutes per sample
#
# ============================================================================

# Use a base image with build tools
FROM ubuntu:22.04

# Metadata
LABEL maintainer="devops-team@company.com"
LABEL description="featureCounts (from Subread) for gene quantification"
LABEL version="2.0.3"

# Avoid interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt-get update && apt-get install -y \
    wget \
    build-essential \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# Download and install Subread
RUN wget https://sourceforge.net/projects/subread/files/subread-2.0.3/subread-2.0.3-Linux-x86_64.tar.gz \
    && tar -xzf subread-2.0.3-Linux-x86_64.tar.gz \
    && mv subread-2.0.3-Linux-x86_64/bin/* /usr/local/bin/ \
    && rm -rf subread-2.0.3-Linux-x86_64.tar.gz subread-2.0.3-Linux-x86_64

# Create non-root user
RUN useradd -m -u 1000 -s /bin/bash biouser
USER biouser
WORKDIR /home/biouser

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD featureCounts -v || exit 1

# Default command
ENTRYPOINT ["featureCounts"]
CMD ["--help"]

# ============================================================================
# BUILD AND RUN
# ============================================================================
#
# Build:
#   docker build -t rnaseq-featurecounts:2.0.3 .
#
# Run:
#   docker run --rm -v $(pwd):/data rnaseq-featurecounts:2.0.3 \
#     -T 4 -a /data/genes.gtf -o /data/counts.txt /data/aligned.bam
#
# ============================================================================
