# Troubleshooting Guide: RNA-Seq Analysis Platform

This guide provides solutions to common problems you may encounter when running the RNA-Seq analysis platform. It is organized by error category, from general debugging to specific pipeline issues.

## 🎯 General Debugging Strategy

When you encounter an error, follow these steps to diagnose the problem:

1.  **Read the Error Message Carefully**: Nextflow and Kubernetes provide detailed error messages. The answer is often right there.
2.  **Check the Logs**: The primary source of truth. Check the logs for the main Nextflow process and the specific task pod that failed.
3.  **Isolate the Problem**: Is the issue with Nextflow, Kubernetes, the container, or the script itself?
4.  **Consult the Work Directory**: Nextflow creates a unique `work/` directory for each task. This contains the script, stdout, stderr, and exit code for the failed process.

---

##  diagnosing-nextflow-issues

### 1. Pipeline Fails to Start

-   **Symptom**: The `nextflow run` command exits immediately with an error.
-   **Common Causes & Solutions**:
    -   **Syntax Error in `main.nf` or `nextflow.config`**: 
        -   **Action**: Run `nextflow config workflows/nextflow.config` to validate the configuration. Carefully check the syntax of the file mentioned in the error.
    -   **Input Files Not Found**:
        -   **Symptom**: `ERROR ~ No files matching glob pattern: ...`
        -   **Action**: Double-check the path provided in the `--reads` parameter. Ensure the files exist and the glob pattern is correct.
    -   **Invalid Profile**:
        -   **Symptom**: `ERROR ~ Unknown profile: ...`
        -   **Action**: Check the spelling of the profile name in your command (`-profile <name>`). Ensure it is defined in `nextflow.config`.

### 2. Task Fails with a Non-Zero Exit Code

-   **Symptom**: The pipeline starts, but a specific task (e.g., `STAR_ALIGN`) fails. The log shows `Error executing process > ...`
-   **Debugging Steps**:
    1.  **Find the Work Directory**: The error message will specify the task's work directory, which looks like `work/d3/a8a20ca...`.
    2.  **Inspect the Logs**: Navigate to that directory and inspect the `.command.log` (stderr) and `.command.out` (stdout) files.
    3.  **Examine the Script**: The `.command.sh` file shows the exact script that was executed inside the container. You can try running this script manually for debugging.
    4.  **Check the Exit Code**: The `.exitcode` file contains the exit code of the failed command. Common codes include:
        -   `1`: General error.
        -   `127`: Command not found (tool not in container PATH).
        -   `137`: Process was killed (often due to OOM - Out of Memory).

---

##  diagnosing-kubernetes-issues

### 1. Pods are Stuck in `Pending` State

-   **Symptom**: `kubectl get pods -n bioinformatics` shows pods that never start running.
-   **DevOps Analogy**: Like an EC2 instance that fails to launch.
-   **Debugging Steps**:
    1.  **Describe the Pod**: `kubectl describe pod <pod-name> -n bioinformatics`.
    2.  **Check the Events Section**: This is the most important part. Look for messages like:
        -   **`Insufficient cpu/memory`**: The cluster doesn't have enough resources to satisfy the pod's requests. 
            -   **Solution**: Add more nodes to the cluster or reduce the resource requests in `nextflow.config`.
        -   **`exceeded quota`**: The namespace has hit its `ResourceQuota` limits.
            -   **Solution**: Delete old pods or increase the quota in `k8s/resource-quota.yaml`.
        -   **`failed to mount volume`**: The pod cannot access the requested `PersistentVolumeClaim`.
            -   **Solution**: Check that the PVC exists and is `Bound`. `kubectl describe pvc genomics-data-pvc -n bioinformatics`.

### 2. Pods are in `ImagePullBackOff` or `ErrImagePull`

-   **Symptom**: Pods fail to start because they can't pull the container image.
-   **DevOps Analogy**: Like a `docker pull` command failing.
-   **Common Causes & Solutions**:
    -   **Incorrect Image Name or Tag**: 
        -   **Action**: Verify the container image name and tag in `nextflow.config` are correct and exist in the registry.
    -   **Authentication Failure**: 
        -   **Action**: If using a private registry, ensure the cluster has the necessary `imagePullSecrets` configured.
    -   **Network Issues**: 
        -   **Action**: Ensure the Kubernetes nodes have network access to the container registry.

### 3. Pods are Crashing (`CrashLoopBackOff`)

-   **Symptom**: Pods start, run for a short time, and then restart repeatedly.
-   **DevOps Analogy**: Like a service that fails its health check and gets restarted by a process manager.
-   **Debugging Steps**:
    1.  **Check the Logs of the Crashing Pod**: Use `kubectl logs <pod-name> -n bioinformatics`. This shows the output from the current container.
    2.  **Check the Logs of the Previous Container**: If the pod is restarting, you need to see why the *previous* one failed. Use `kubectl logs --previous <pod-name> -n bioinformatics`.
    3.  **Common Causes**:
        -   **Application Error**: The bioinformatics tool itself is crashing. The logs should contain a specific error message.
        -   **Out of Memory (OOMKilled)**: The container is using more memory than its limit. `kubectl describe pod ...` will show the reason as `OOMKilled`.
            -   **Solution**: Increase the `memory` limit for that process in `nextflow.config`.
        -   **Misconfiguration**: An incorrect command-line argument is causing the tool to exit immediately.

---

##  diagnosing-pipeline-logic-issues

### 1. STAR Alignment Fails

-   **Symptom**: The `STAR_ALIGN` process fails.
-   **Common Causes & Solutions**:
    -   **Out of Memory**: This is the most common issue. STAR requires a lot of RAM to hold the genome index.
        -   **Symptom**: The process exits with code `137`. The pod status is `OOMKilled`.
        -   **Solution**: Increase the memory for the `STAR_ALIGN` process in `nextflow.config` to at least `32.GB` for the human genome.
    -   **Incorrect Genome Index**: 
        -   **Action**: Ensure the STAR index was built correctly and is compatible with the STAR version being used.
    -   **Read Length Mismatch**: 
        -   **Action**: The `--sjdbOverhang` parameter used to build the index should match the read length of your FASTQ files minus one.

### 2. FastQC Fails

-   **Symptom**: The `FASTQC` process fails.
-   **Common Causes & Solutions**:
    -   **Corrupt FASTQ file**: The input file may be truncated or malformed.
        -   **Action**: Try running `gunzip -c <fastq-file> | tail` to see if the file is readable.
    -   **Java Memory Issues**: FastQC is a Java application.
        -   **Action**: If you see Java heap space errors, you may need to increase the memory for the `FASTQC` process.

---

##  diagnosing-performance-issues

### 1. Pipeline is Running Very Slowly

-   **Symptom**: Tasks are taking much longer than expected.
-   **Common Causes & Solutions**:
    -   **CPU Throttling**: The container is trying to use more CPU than its limit.
        -   **Action**: Monitor CPU usage (`kubectl top pods`). If a pod is consistently at its CPU limit, increase the `cpus` limit in `nextflow.config`.
    -   **Storage Bottleneck**: The shared storage (EFS/Filestore) is slow.
        -   **Action**: Check the IOPS and throughput metrics in your cloud provider's console. You may need to upgrade to a higher performance tier.
    -   **Insufficient Parallelism**: Not enough tasks are running at once.
        -   **Action**: Check the Nextflow logs to see the queue size. If many tasks are queued, it may be due to resource quotas or lack of cluster capacity.

### 2. High Costs

-   **Symptom**: Your cloud bill is higher than expected.
-   **Common Causes & Solutions**:
    -   **Cluster Not Scaling Down**: The cluster autoscaler is not configured to scale down to zero nodes when idle.
        -   **Action**: Review your cluster autoscaler configuration.
    -   **Not Using Spot Instances**: You are paying on-demand prices for all nodes.
        -   **Action**: Configure a node group to use spot instances and add a `nodeSelector` to your Kubernetes profile in `nextflow.config` to target them.
    -   **Resources Not Right-Sized**: You are requesting far more CPU/memory than the tasks actually need.
        -   **Action**: Use monitoring tools like Prometheus to track actual resource usage and adjust the requests in `nextflow.config` accordingly.

This guide covers the most common issues. For more specific problems, the Nextflow and Kubernetes documentation, as well as community forums, are excellent resources.
