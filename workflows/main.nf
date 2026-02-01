#!/usr/bin/env nextflow

/*
 * RNA-Seq Analysis Pipeline
 * ==========================
 * 
 * This pipeline processes RNA sequencing data to quantify gene expression.
 * 
 * PIPELINE STAGES:
 * 1. FastQC: Quality control (like log validation)
 * 2. STAR: Alignment (like JOIN query on 3 billion rows)
 * 3. Salmon: Quantification (like GROUP BY aggregation)
 * 4. MultiQC: Report generation (like Grafana dashboard)
 * 
 * EXECUTION:
 *   nextflow run main.nf -profile docker
 *   nextflow run main.nf -profile kubernetes
 */

// Enable DSL2 (modern Nextflow syntax)
// DSL2 allows modular, reusable processes
nextflow.enable.dsl = 2

/*
 * PARAMETERS
 * ==========
 * These are like CLI arguments or environment variables
 * Users can override them: --reads "/path/to/data/*.fastq.gz"
 */

// Input data parameters
params.reads = "${projectDir}/../data/fastq/*_R{1,2}.fastq.gz"  // Paired-end FASTQ files
params.genome = "${projectDir}/../data/reference/genome.fa"      // Reference genome (FASTA)
params.gtf = "${projectDir}/../data/reference/genes.gtf"         // Gene annotations
params.outdir = "${projectDir}/../data/results"                  // Output directory

// Reference genome index (pre-built for speed)
params.star_index = "${projectDir}/../data/reference/star_index"

// Tool-specific parameters
params.fastqc_threads = 2
params.star_threads = 8
params.salmon_threads = 4

// Help message
params.help = false

/*
 * HELP MESSAGE
 * ============
 * Display usage information
 */
def helpMessage() {
    log.info"""
    ╔═══════════════════════════════════════════════════════════════╗
    ║           RNA-Seq Analysis Pipeline v1.0                      ║
    ║           Production-Grade Bioinformatics Platform            ║
    ╚═══════════════════════════════════════════════════════════════╝
    
    Usage:
      nextflow run main.nf -profile <docker|kubernetes> [options]
    
    Required Arguments:
      --reads         Path to paired-end FASTQ files (use glob pattern)
                      Example: "/data/fastq/*_R{1,2}.fastq.gz"
      
      --genome        Path to reference genome (FASTA format)
                      Example: "/data/reference/genome.fa"
      
      --gtf           Path to gene annotations (GTF format)
                      Example: "/data/reference/genes.gtf"
    
    Optional Arguments:
      --outdir        Output directory (default: ../data/results)
      --star_index    Pre-built STAR index directory (speeds up alignment)
    
    Profiles:
      -profile docker       Run locally using Docker
      -profile kubernetes   Run on Kubernetes cluster
      -profile test         Run with test dataset (small, fast)
    
    Examples:
      # Run locally with Docker
      nextflow run main.nf -profile docker
      
      # Run on Kubernetes
      nextflow run main.nf -profile kubernetes
      
      # Custom data location
      nextflow run main.nf -profile docker \\
        --reads "/my/data/*_R{1,2}.fastq.gz" \\
        --genome "/my/reference/genome.fa" \\
        --outdir "/my/results"
    
    DevOps Analogy:
      This pipeline is like a data processing ETL:
        FASTQ (Raw Logs) → QC (Validation) → Align (Transform) → Count (Aggregate)
    
    For more information, see: docs/SETUP.md
    """.stripIndent()
}

// Show help message if requested
if (params.help) {
    helpMessage()
    exit 0
}

/*
 * VALIDATE INPUTS
 * ===============
 * Check that required files exist (like input validation)
 */
if (!params.reads) {
    log.error "ERROR: --reads parameter is required"
    helpMessage()
    exit 1
}

if (!params.genome) {
    log.error "ERROR: --genome parameter is required"
    helpMessage()
    exit 1
}

/*
 * PRINT PIPELINE INFORMATION
 * ==========================
 * Show what will be executed (like a deployment plan)
 */
log.info """
╔═══════════════════════════════════════════════════════════════╗
║           RNA-Seq Pipeline Execution Plan                     ║
╚═══════════════════════════════════════════════════════════════╝

Input Data:
  Reads:        ${params.reads}
  Genome:       ${params.genome}
  GTF:          ${params.gtf}
  
Output:
  Directory:    ${params.outdir}

Execution:
  Profile:      ${workflow.profile}
  Work Dir:     ${workflow.workDir}
  Container:    ${workflow.containerEngine}

Resources:
  FastQC:       ${params.fastqc_threads} CPUs
  STAR:         ${params.star_threads} CPUs
  Salmon:       ${params.salmon_threads} CPUs

═══════════════════════════════════════════════════════════════
""".stripIndent()

/*
 * IMPORT MODULES
 * ==============
 * Import process definitions from separate files (modular design)
 * This is optional - you can define processes inline too
 */
// include { FASTQC } from './modules/fastqc'
// include { STAR_ALIGN } from './modules/star'
// include { SALMON_QUANT } from './modules/salmon'
// include { MULTIQC } from './modules/multiqc'

/*
 * PROCESS DEFINITIONS
 * ===================
 * Each process is like a microservice - does one thing well
 */

/*
 * Process: FASTQC
 * ===============
 * Quality control for raw sequencing data
 * 
 * DEVOPS ANALOGY:
 *   Like validating log files - checking format, completeness, quality
 * 
 * WHAT IT DOES:
 *   - Checks per-base quality scores
 *   - Detects adapter contamination
 *   - Identifies overrepresented sequences
 *   - Generates HTML report with plots
 * 
 * RESOURCES:
 *   - CPU: 2 cores (can process multiple files in parallel)
 *   - Memory: 4 GB (lightweight tool)
 *   - Time: ~5 minutes per sample
 */
process FASTQC {
    tag "$sample_id"  // Tag for logging (shows which sample is being processed)
    publishDir "${params.outdir}/fastqc", mode: 'copy'  // Copy results to output dir
    
    input:
    tuple val(sample_id), path(reads)  // Tuple: (sample_name, [R1.fastq.gz, R2.fastq.gz])
    
    output:
    path("*.html"), emit: html  // HTML reports
    path("*.zip"), emit: zip    // Detailed results (ZIP)
    
    script:
    """
    # Run FastQC on both R1 and R2 files
    # -t: number of threads
    # -o: output directory
    fastqc -t ${params.fastqc_threads} -o . ${reads}
    
    # DevOps Note:
    # This is like running a log validator that checks:
    #   - Are the logs well-formed?
    #   - Are there any anomalies?
    #   - What's the data quality distribution?
    """
}

/*
 * Process: STAR_INDEX
 * ===================
 * Build genome index for STAR aligner (one-time setup)
 * 
 * DEVOPS ANALOGY:
 *   Like building a database index - slow to create, fast to query
 * 
 * WHAT IT DOES:
 *   - Creates a searchable index of the reference genome
 *   - Enables fast alignment (without index, alignment would take hours)
 * 
 * RESOURCES:
 *   - CPU: 8 cores
 *   - Memory: 32 GB (genome index is huge!)
 *   - Time: ~1 hour (one-time cost)
 *   - Disk: ~30 GB for human genome
 * 
 * NOTE: In production, you'd pre-build this and store it
 */
process STAR_INDEX {
    tag "genome_index"
    publishDir "${params.outdir}/star_index", mode: 'copy'
    
    input:
    path(genome)  // Reference genome (FASTA)
    path(gtf)     // Gene annotations (GTF)
    
    output:
    path("star_index"), emit: index
    
    when:
    !file(params.star_index).exists()  // Only run if index doesn't exist
    
    script:
    """
    mkdir -p star_index
    
    # Build STAR index
    # --runMode genomeGenerate: index building mode
    # --genomeDir: output directory
    # --genomeFastaFiles: reference genome
    # --sjdbGTFfile: gene annotations
    # --sjdbOverhang: read length - 1 (typically 100 for 101bp reads)
    # --runThreadN: number of threads
    STAR \\
        --runMode genomeGenerate \\
        --genomeDir star_index \\
        --genomeFastaFiles ${genome} \\
        --sjdbGTFfile ${gtf} \\
        --sjdbOverhang 100 \\
        --runThreadN ${params.star_threads}
    
    # DevOps Note:
    # This is like building a B-tree index on a 3 billion row database
    # Slow to create, but makes queries (alignment) 1000x faster
    """
}

/*
 * Process: STAR_ALIGN
 * ===================
 * Align RNA sequences to reference genome
 * 
 * DEVOPS ANALOGY:
 *   Like a massive JOIN query - matching millions of sequences to 3 billion positions
 * 
 * WHAT IT DOES:
 *   - Takes short sequences (50-150 bp)
 *   - Finds where they came from in the genome (3 billion bp)
 *   - Handles sequencing errors and splice junctions
 *   - Outputs BAM file (binary alignment format)
 * 
 * RESOURCES:
 *   - CPU: 8 cores (highly parallelizable)
 *   - Memory: 32 GB (genome index loaded in RAM)
 *   - Time: ~30 minutes per sample
 *   - Disk: 5-20 GB per sample (BAM file)
 * 
 * WHY IT'S RESOURCE INTENSIVE:
 *   - Genome index is ~30 GB (must fit in RAM)
 *   - Millions of sequences to align
 *   - Fuzzy matching (allows mismatches)
 */
process STAR_ALIGN {
    tag "$sample_id"
    publishDir "${params.outdir}/aligned", mode: 'copy'
    
    input:
    tuple val(sample_id), path(reads)  // (sample_name, [R1.fastq.gz, R2.fastq.gz])
    path(index)                         // STAR index directory
    
    output:
    tuple val(sample_id), path("${sample_id}.Aligned.sortedByCoord.out.bam"), emit: bam
    path("${sample_id}.Log.final.out"), emit: log
    
    script:
    """
    # Run STAR alignment
    # --runThreadN: number of threads
    # --genomeDir: path to genome index
    # --readFilesIn: input FASTQ files (R1 R2 for paired-end)
    # --readFilesCommand: command to decompress files (zcat for .gz)
    # --outFileNamePrefix: prefix for output files
    # --outSAMtype: output format (BAM, sorted by coordinate)
    # --outSAMunmapped: include unmapped reads in output
    # --outSAMattributes: SAM attributes to include
    STAR \\
        --runThreadN ${params.star_threads} \\
        --genomeDir ${index} \\
        --readFilesIn ${reads[0]} ${reads[1]} \\
        --readFilesCommand zcat \\
        --outFileNamePrefix ${sample_id}. \\
        --outSAMtype BAM SortedByCoordinate \\
        --outSAMunmapped Within \\
        --outSAMattributes Standard
    
    # DevOps Note:
    # This is like running:
    #   SELECT reads.sequence, genome.position
    #   FROM reads
    #   JOIN genome ON reads.sequence FUZZY_MATCH genome.region
    # 
    # Except the "genome" table has 3 billion rows and the "reads" table
    # has 50 million rows, and the JOIN allows fuzzy matching!
    """
}

/*
 * Process: SALMON_QUANT
 * ======================
 * Quantify gene expression (count reads per gene)
 * 
 * DEVOPS ANALOGY:
 *   Like a GROUP BY query - counting events per category
 * 
 * WHAT IT DOES:
 *   - Takes aligned reads (BAM file)
 *   - Counts how many reads map to each gene
 *   - Outputs count matrix (genes × samples)
 * 
 * RESOURCES:
 *   - CPU: 4 cores
 *   - Memory: 8 GB
 *   - Time: ~10 minutes per sample
 */
process SALMON_QUANT {
    tag "$sample_id"
    publishDir "${params.outdir}/counts", mode: 'copy'
    
    input:
    tuple val(sample_id), path(bam)  // (sample_name, aligned.bam)
    path(gtf)                         // Gene annotations
    
    output:
    tuple val(sample_id), path("${sample_id}_counts.txt"), emit: counts
    
    script:
    """
    # Count reads per gene using featureCounts (alternative to Salmon for BAM input)
    # -T: number of threads
    # -p: paired-end reads
    # -a: annotation file (GTF)
    # -o: output file
    featureCounts \\
        -T ${params.salmon_threads} \\
        -p \\
        -a ${gtf} \\
        -o ${sample_id}_counts.txt \\
        ${bam}
    
    # DevOps Note:
    # This is like running:
    #   SELECT gene_name, COUNT(*) as read_count
    #   FROM aligned_reads
    #   GROUP BY gene_name
    # 
    # Output: A table with gene names and counts
    """
}

/*
 * Process: MULTIQC
 * ================
 * Aggregate all QC reports into one dashboard
 * 
 * DEVOPS ANALOGY:
 *   Like Grafana - combines metrics from multiple sources into unified view
 * 
 * WHAT IT DOES:
 *   - Collects FastQC, STAR, and Salmon logs
 *   - Generates interactive HTML report
 *   - Shows summary statistics and plots
 * 
 * RESOURCES:
 *   - CPU: 1 core (lightweight)
 *   - Memory: 2 GB
 *   - Time: ~2 minutes
 */
process MULTIQC {
    publishDir "${params.outdir}", mode: 'copy'
    
    input:
    path('*')  // Collect all QC files from previous steps
    
    output:
    path("multiqc_report.html"), emit: report
    path("multiqc_data"), emit: data
    
    script:
    """
    # Run MultiQC to aggregate all QC reports
    # -f: force overwrite
    # -n: output filename
    multiqc . -f -n multiqc_report.html
    
    # DevOps Note:
    # This is like a Grafana dashboard that automatically discovers
    # and visualizes metrics from FastQC, STAR, and Salmon logs
    """
}

/*
 * WORKFLOW DEFINITION
 * ===================
 * This is the DAG (Directed Acyclic Graph) - defines execution order
 * 
 * DEVOPS ANALOGY:
 *   Like a CI/CD pipeline or Airflow DAG - defines task dependencies
 */
workflow {
    /*
     * STEP 1: Create input channel
     * =============================
     * Channel: like a message queue - passes data between processes
     * fromFilePairs: automatically pairs R1 and R2 files
     */
    read_pairs_ch = Channel
        .fromFilePairs(params.reads, checkIfExists: true)
        .ifEmpty { error "No FASTQ files found matching pattern: ${params.reads}" }
    
    // Print number of samples found
    read_pairs_ch.view { sample_id, files ->
        "Found sample: ${sample_id} with files: ${files}"
    }
    
    /*
     * STEP 2: Quality Control
     * ========================
     * Run FastQC on all samples in parallel
     */
    FASTQC(read_pairs_ch)
    
    /*
     * STEP 3: Build genome index (if needed)
     * =======================================
     * This runs once, not per sample
     */
    genome_ch = Channel.fromPath(params.genome, checkIfExists: true)
    gtf_ch = Channel.fromPath(params.gtf, checkIfExists: true)
    
    if (file(params.star_index).exists()) {
        // Use pre-built index
        star_index_ch = Channel.fromPath(params.star_index)
    } else {
        // Build index
        STAR_INDEX(genome_ch, gtf_ch)
        star_index_ch = STAR_INDEX.out.index
    }
    
    /*
     * STEP 4: Alignment
     * =================
     * Align all samples in parallel
     * Each sample gets its own pod with 8 CPUs and 32 GB RAM
     */
    STAR_ALIGN(read_pairs_ch, star_index_ch)
    
    /*
     * STEP 5: Quantification
     * ======================
     * Count reads per gene for each sample
     */
    SALMON_QUANT(STAR_ALIGN.out.bam, gtf_ch)
    
    /*
     * STEP 6: Generate Report
     * =======================
     * Collect all QC files and generate unified report
     */
    multiqc_input = FASTQC.out.zip
        .mix(STAR_ALIGN.out.log)
        .collect()  // Wait for all samples to finish
    
    MULTIQC(multiqc_input)
}

/*
 * WORKFLOW COMPLETION
 * ===================
 * Print summary when pipeline finishes
 */
workflow.onComplete {
    log.info """
    ╔═══════════════════════════════════════════════════════════════╗
    ║           Pipeline Execution Complete!                        ║
    ╚═══════════════════════════════════════════════════════════════╝
    
    Status:       ${workflow.success ? 'SUCCESS' : 'FAILED'}
    Duration:     ${workflow.duration}
    Work Dir:     ${workflow.workDir}
    Results:      ${params.outdir}
    
    Reports:
      MultiQC:    ${params.outdir}/multiqc_report.html
      FastQC:     ${params.outdir}/fastqc/
      Aligned:    ${params.outdir}/aligned/
      Counts:     ${params.outdir}/counts/
    
    DevOps Note:
      This pipeline processed your RNA-Seq data through:
        1. Quality Control (FastQC)
        2. Alignment (STAR)
        3. Quantification (Salmon/featureCounts)
        4. Report Generation (MultiQC)
      
      Open ${params.outdir}/multiqc_report.html in a browser to view results!
    
    ═══════════════════════════════════════════════════════════════
    """.stripIndent()
}

workflow.onError {
    log.error """
    ╔═══════════════════════════════════════════════════════════════╗
    ║           Pipeline Execution Failed!                          ║
    ╚═══════════════════════════════════════════════════════════════╝
    
    Error:        ${workflow.errorMessage}
    Work Dir:     ${workflow.workDir}
    
    Troubleshooting:
      1. Check the error message above
      2. Review logs in work directory: ${workflow.workDir}
      3. See docs/TROUBLESHOOTING.md for common issues
      4. Verify input files exist and are valid
      5. Check resource availability (CPU, memory, disk)
    
    Common Issues:
      - Out of memory: Increase memory in nextflow.config
      - Missing files: Check --reads, --genome, --gtf paths
      - Permission denied: Check RBAC settings (Kubernetes)
      - Pod eviction: Check resource quotas (Kubernetes)
    
    ═══════════════════════════════════════════════════════════════
    """.stripIndent()
}
