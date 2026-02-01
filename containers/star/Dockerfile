# STAR Aligner Container
# ======================
# STAR is a fast RNA-seq aligner.
#
# WHAT IT DOES:
# - Aligns RNA sequences to a reference genome.
# - Handles spliced reads (a key feature for RNA-seq).
# - Produces BAM files as output.
#
# RESOURCES:
# - CPU: 8+ cores (highly parallelizable)
# - Memory: 32+ GB (genome index is huge!)
# - Time: ~30 minutes per sample
#
# ============================================================================

# Use Ubuntu as base image
FROM ubuntu:22.04

# Metadata
LABEL maintainer="devops-team@alphonse.com"
LABEL description="STAR aligner for RNA-Seq pipelines"
LABEL version="2.7.10a"

# Avoid interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt-get update && apt-get install -y \
    wget \
    build-essential \
    zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

# Download and install STAR
RUN wget https://github.com/alexdobin/STAR/archive/2.7.10a.tar.gz \
    && tar -xzf 2.7.10a.tar.gz \
    && cd STAR-2.7.10a/source \
    && make STAR \
    && mv STAR /usr/local/bin/ \
    && cd ../.. \
    && rm -rf STAR-2.7.10a 2.7.10a.tar.gz

# Create non-root user
RUN useradd -m -u 1000 -s /bin/bash biouser
USER biouser
WORKDIR /home/biouser

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD STAR --version || exit 1

# Default command
ENTRYPOINT ["STAR"]
CMD ["--help"]

# ============================================================================
# BUILD AND RUN
# ============================================================================
#
# Build:
#   docker build -t rnaseq-star:2.7.10a .
#
# Run (genome generation):
#   docker run --rm -v $(pwd):/data rnaseq-star:2.7.10a \
#     --runThreadN 8 --runMode genomeGenerate --genomeDir /data/star_index \
#     --genomeFastaFiles /data/genome.fa --sjdbGTFfile /data/genes.gtf
#
# Run (alignment):
#   docker run --rm -v $(pwd):/data rnaseq-star:2.7.10a \
#     --runThreadN 8 --genomeDir /data/star_index --readFilesIn /data/sample_R1.fastq.gz /data/sample_R2.fastq.gz
#
# ============================================================================
