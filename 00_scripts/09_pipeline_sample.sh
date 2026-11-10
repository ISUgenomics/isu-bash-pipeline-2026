#!/usr/bin/env bash

set -euo pipefail

# Arguments
SAMPLE="${1:?Usage: $0 <sample_id> [reference.fa]}"
REF="${2:-02_reference/b73_chr1_150000001-151000000.fasta}"

# Settings (can be overridden from the environment, e.g. THREADS=8)
THREADS="${THREADS:-4}"
INPUT_DIR="${INPUT_DIR:-01_data}"
TRIM_DIR="${TRIM_DIR:-10_fastp_paired}"
ALIGN_DIR="${ALIGN_DIR:-11_alignment}"
LOG_DIR="${LOG_DIR:-logs}"

mkdir -p "$TRIM_DIR" "$ALIGN_DIR" "$LOG_DIR"

module purge
module load fastp
module load bwa
module load samtools

R1="$INPUT_DIR/${SAMPLE}_R1.fastq.gz"
R2="$INPUT_DIR/${SAMPLE}_R2.fastq.gz"
TRIM_R1="$TRIM_DIR/${SAMPLE}_R1.trimmed.fastq.gz"
TRIM_R2="$TRIM_DIR/${SAMPLE}_R2.trimmed.fastq.gz"
BAM="$ALIGN_DIR/${SAMPLE}.sorted.bam"

# Fail early if inputs are missing
for f in "$R1" "$R2" "$REF" "${REF}.bwt"
do
  [[ -s "$f" ]] || { echo "ERROR: missing or empty file: $f" >&2; exit 1; }
done

# Step 1: trim (skipped if already done)
if [[ -s "$TRIM_R1" && -s "$TRIM_R2" ]]
then
  echo "[$SAMPLE] fastp: output exists, skipping"
else
  echo "[$SAMPLE] fastp: running"
  fastp \
    -i "$R1" -I "$R2" \
    -o "$TRIM_DIR/tmp_${SAMPLE}_R1.trimmed.fastq.gz" \
    -O "$TRIM_DIR/tmp_${SAMPLE}_R2.trimmed.fastq.gz" \
    -h "$TRIM_DIR/${SAMPLE}.html" \
    -j "$TRIM_DIR/${SAMPLE}.json" \
    -w "$THREADS" \
    > "$LOG_DIR/${SAMPLE}_fastp.log" 2>&1
  mv "$TRIM_DIR/tmp_${SAMPLE}_R1.trimmed.fastq.gz" "$TRIM_R1"
  mv "$TRIM_DIR/tmp_${SAMPLE}_R2.trimmed.fastq.gz" "$TRIM_R2"
fi

# Step 2: align, sort (skipped if already done)
if [[ -s "$BAM" && -s "${BAM}.bai" ]]
then
  echo "[$SAMPLE] bwa: output exists, skipping"
else
  echo "[$SAMPLE] bwa: running"
  bwa mem -t "$THREADS" \
    -R "@RG\tID:${SAMPLE}\tSM:${SAMPLE}\tPL:ILLUMINA" \
    "$REF" "$TRIM_R1" "$TRIM_R2" \
    2> "$LOG_DIR/${SAMPLE}_bwa.log" \
    | samtools sort -@ 2 -O bam -T "$ALIGN_DIR/tmp_${SAMPLE}" \
        -o "${BAM}.tmp" -
  mv "${BAM}.tmp" "$BAM"
  samtools index "$BAM"
fi

# Step 3: summary
samtools flagstat "$BAM" > "$ALIGN_DIR/${SAMPLE}.flagstat.txt"

echo "[$SAMPLE] done"
