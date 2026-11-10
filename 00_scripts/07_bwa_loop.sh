#!/usr/bin/env bash

set -euo pipefail

REF="02_reference/b73_chr1_150000001-151000000.fasta"
INPUT_DIR="07_fastp_parallel_improved"
OUTPUT_DIR="08_alignment"
LOG_DIR="logs"
THREADS=8

mkdir -p "$OUTPUT_DIR" "$LOG_DIR"

module purge
module load bwa
module load samtools

for r1 in $INPUT_DIR/*_R1.trimmed.fastq.gz
do
  sample_id=$(basename "$r1" _R1.trimmed.fastq.gz)
  r2=$INPUT_DIR/${sample_id}_R2.trimmed.fastq.gz

  echo "Aligning: $sample_id"

  bwa mem -t "$THREADS" \
    -R "@RG\tID:${sample_id}\tSM:${sample_id}\tPL:ILLUMINA" \
    "$REF" "$r1" "$r2" \
    2> "$LOG_DIR/07_bwa_loop_${sample_id}.log" \
    | samtools sort -@ 4 -o "$OUTPUT_DIR/${sample_id}.sorted.bam" -

  samtools index "$OUTPUT_DIR/${sample_id}.sorted.bam"
done
