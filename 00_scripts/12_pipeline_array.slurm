#!/usr/bin/env bash
#SBATCH --job-name=pipeline
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --time=04:00:00
#SBATCH --output=logs/slurm_%A_%a.out
#SBATCH --error=logs/slurm_%A_%a.err
# Add --account=<your_account> if Slurm asks for one (not needed in our test)
# --mem=32G is more than this small data needs (see MaxRSS below); tune --mem and --time for your data

set -euo pipefail

SAMPLE_LIST="${SAMPLE_LIST:-samples.txt}"

# Pick the line of samples.txt that matches this array task
SAMPLE=$(sed -n "${SLURM_ARRAY_TASK_ID}p" "$SAMPLE_LIST")
[[ -n "$SAMPLE" ]] || { echo "ERROR: no sample for task $SLURM_ARRAY_TASK_ID" >&2; exit 1; }

# Use the CPUs Slurm gave us (2 are left for samtools sort)
export THREADS=$(( SLURM_CPUS_PER_TASK > 2 ? SLURM_CPUS_PER_TASK - 2 : 1 ))

echo "Task $SLURM_ARRAY_TASK_ID: sample $SAMPLE on $(hostname) with $THREADS threads"

./00_scripts/09_pipeline_sample.sh "$SAMPLE"
