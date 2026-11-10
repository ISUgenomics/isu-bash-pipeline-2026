#!/usr/bin/env bash

module purge
module load fastp
mkdir -p 03_fastp logs
fastp \
  -i 01_data/bio_sample_01_R1.fastq.gz -I 01_data/bio_sample_01_R2.fastq.gz \
  -o 03_fastp/bio_sample_01_R1.trimmed.fastq.gz \
  -O 03_fastp/bio_sample_01_R2.trimmed.fastq.gz \
  -h 03_fastp/bio_sample_01.html \
  -j 03_fastp/bio_sample_01.json \
  > logs/01_fastp.log 2>&1
