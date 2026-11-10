#!/usr/bin/env bash

set -euo pipefail # error handling:
                  # -e: exit immediately if any command returns a non-zero exit status (error)
                  # -u: treat unset variables as an error and exit (useful for debugging)
                  # -o pipefail: exit if any command in a pipeline fails (useful for debugging)

# Directories
# Input directory
INPUT_DIR="01_data"

# Output directory
OUTPUT_DIR="07_fastp_parallel_improved"

# Log directory
LOG_DIR="logs"

# Number of samples to run at the same time
JOBS=5

# Create required directories
mkdir -p "$OUTPUT_DIR" "$LOG_DIR"

# make them visible to subshells that parallel spawns
export OUTPUT_DIR LOG_DIR INPUT_DIR

# Load required modules
module load parallel
module load fastp

# Run fastp
parallel -j"$JOBS" --rpl '{sample} s:.*/::; s/_R1\.fastq\.gz$//' \
  'fastp -i "{}" -I "$INPUT_DIR/{sample}_R2.fastq.gz" \
     -o "$OUTPUT_DIR/{sample}_R1.trimmed.fastq.gz" \
     -O "$OUTPUT_DIR/{sample}_R2.trimmed.fastq.gz" \
     -h "$OUTPUT_DIR/{sample}.html" \
     -j "$OUTPUT_DIR/{sample}.json" \
     > "$LOG_DIR/05_fastp_parallel_improved_{sample}.log" 2>&1' \
  ::: "$INPUT_DIR"/*_R1.fastq.gz
