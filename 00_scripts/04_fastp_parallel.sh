#!/usr/bin/env bash

module purge
module load parallel
module load fastp

mkdir -p 06_fastp_parallel logs

parallel -j5 --rpl '{sample} s:.*/::; s/_R1\.fastq\.gz$//' \
  'fastp -i {} -I 01_data/{sample}_R2.fastq.gz -o 06_fastp_parallel/{sample}_R1.trimmed.fastq.gz -O 06_fastp_parallel/{sample}_R2.trimmed.fastq.gz -h 06_fastp_parallel/{sample}.html -j 06_fastp_parallel/{sample}.json > logs/04_fastp_parallel_{sample}.log 2>&1' \
  ::: 01_data/*_R1.fastq.gz
