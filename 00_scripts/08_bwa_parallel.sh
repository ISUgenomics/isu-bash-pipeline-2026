#!/usr/bin/env bash

set -euo pipefail

REF="02_reference/b73_chr1_150000001-151000000.fasta"
INPUT_DIR="07_fastp_parallel_improved"
OUTPUT_DIR="09_alignment_parallel"
LOG_DIR="logs"

mkdir -p "$OUTPUT_DIR" "$LOG_DIR"
export REF INPUT_DIR OUTPUT_DIR LOG_DIR

module purge
module load parallel
module load bwa
module load samtools

align_one() {
  set -euo pipefail
  sample_id=$1
  bwa mem -t 4 \
    -R "@RG\tID:${sample_id}\tSM:${sample_id}\tPL:ILLUMINA" \
    "$REF" \
    "$INPUT_DIR/${sample_id}_R1.trimmed.fastq.gz" \
    "$INPUT_DIR/${sample_id}_R2.trimmed.fastq.gz" \
    2> "$LOG_DIR/08_bwa_parallel_${sample_id}.log" \
    | samtools sort -@ 2 -o "$OUTPUT_DIR/${sample_id}.sorted.bam" -
  samtools index "$OUTPUT_DIR/${sample_id}.sorted.bam"
}
export -f align_one

parallel -j4 align_one {} ::: $(ls $INPUT_DIR/*_R1.trimmed.fastq.gz | xargs -n1 basename | sed 's/_R1.trimmed.fastq.gz//')
