#!/usr/bin/env bash

module purge
module load fastp

mkdir -p 04_fastp_loop logs

for r1 in 01_data/*_R1.fastq.gz
do
  sample_id=$(basename "$r1" _R1.fastq.gz)
  r2="01_data/${sample_id}_R2.fastq.gz"
  echo "Running fastp on: $sample_id"
  fastp \
    -i "$r1" -I "$r2" \
    -o "04_fastp_loop/${sample_id}_R1.trimmed.fastq.gz" \
    -O "04_fastp_loop/${sample_id}_R2.trimmed.fastq.gz" \
    -h "04_fastp_loop/${sample_id}.html" \
    -j "04_fastp_loop/${sample_id}.json" \
    > logs/02_fastp_loop.log 2>&1
done
