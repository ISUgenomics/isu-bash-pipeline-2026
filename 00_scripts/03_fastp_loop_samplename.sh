#!/usr/bin/env bash

module purge
module load fastp

INPUT_DIR="01_data"
OUTPUT_DIR="05_fastp_loop_samplename"
LOG_DIR="logs"

mkdir -p "$OUTPUT_DIR" "$LOG_DIR"

for r1 in "$INPUT_DIR"/*_R1.fastq.gz
do
  sample_id=$(basename "$r1" _R1.fastq.gz)
  r2="$INPUT_DIR/${sample_id}_R2.fastq.gz"
  echo "Running fastp on: $sample_id"
  fastp \
    -i "$r1" -I "$r2" \
    -o "$OUTPUT_DIR/${sample_id}_R1.trimmed.fastq.gz" \
    -O "$OUTPUT_DIR/${sample_id}_R2.trimmed.fastq.gz" \
    -h "$OUTPUT_DIR/${sample_id}.html" \
    -j "$OUTPUT_DIR/${sample_id}.json" \
    > "$LOG_DIR/03_fastp_loop_${sample_id}.log" 2>&1
done
