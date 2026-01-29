# MultiQC Container
# =================
# MultiQC aggregates results from bioinformatics analyses across many samples into a single report.
#
# DEVOPS ANALOGY:
# Like Grafana or Datadog - creates a unified dashboard from multiple data sources.
#
# WHAT IT DOES:
# - Scans a directory for log files from supported tools (FastQC, STAR, etc.).
# - Parses the logs and extracts key metrics.
# - Generates a single, interactive HTML report.
#
# RESOURCES:
# - CPU: 1 core
# - Memory: 2 GB
# - Time: ~2 minutes
#
# ============================================================================

# Use a Python base image
FROM python:3.9-slim

# Metadata
LABEL maintainer="devops-team@company.com"
LABEL description="MultiQC for aggregating bioinformatics QC results"
LABEL version="1.14"

# Install MultiQC using pip
RUN pip install multiqc==1.14

# Create non-root user
RUN useradd -m -u 1000 -s /bin/bash biouser
USER biouser
WORKDIR /home/biouser

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD multiqc --version || exit 1

# Default command
ENTRYPOINT ["multiqc"]
CMD ["--help"]

# ============================================================================
# BUILD AND RUN
# ============================================================================
#
# Build:
#   docker build -t rnaseq-multiqc:1.14 .
#
# Run:
#   # Run in a directory containing QC logs
#   docker run --rm -v $(pwd):/data -w /data rnaseq-multiqc:1.14 .
#
# ============================================================================
