#!/usr/bin/env bash
#SBATCH --job-name=pipeline_all
#SBATCH --cpus-per-task=10
#SBATCH --mem=16G
#SBATCH --time=01:00:00
#SBATCH --output=logs/slurm_%j.out
#SBATCH --error=logs/slurm_%j.err

set -euo pipefail

# How many samples to run at the same time
export JOBS="${JOBS:-2}"

# Threads per sample: share the CPUs between the samples (2 are left for samtools sort)
export THREADS=$(( SLURM_CPUS_PER_TASK / JOBS - 2 ))
[[ "$THREADS" -ge 1 ]] || THREADS=1

echo "Job $SLURM_JOB_ID on $(hostname): $JOBS samples at a time, $THREADS threads each"

./00_scripts/10_run_pipeline.sh
