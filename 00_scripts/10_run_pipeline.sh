#!/usr/bin/env bash

set -euo pipefail

# Concurrency: JOBS samples at a time, THREADS threads for each
JOBS="${JOBS:-2}"
export THREADS="${THREADS:-3}"

INPUT_DIR="01_data"
LOG_DIR="logs"
mkdir -p "$LOG_DIR"

module purge
module load parallel

# Sample names = R1 file names without the directory and the _R1.fastq.gz suffix
SAMPLES=$(ls "$INPUT_DIR"/*_R1.fastq.gz | xargs -n1 basename | sed 's/_R1.fastq.gz$//')

echo "Samples to process:"
echo "$SAMPLES"

parallel -j"$JOBS" --joblog "$LOG_DIR/pipeline_joblog.tsv" \
  ./00_scripts/09_pipeline_sample.sh {} ::: $SAMPLES
