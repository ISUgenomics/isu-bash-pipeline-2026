# Setup

Everything in this workshop runs from one project directory on Nova. Several items below are marked TODO because they have not been verified on Nova yet.

## 1. Get an interactive session

Do not run the workshop commands on the head node. Request a session with a few cores (for example, 8 cores) through OnDemand, or from a terminal:

```bash
salloc --cpus-per-task=8 --mem=16G --time=04:00:00
```

TODO: confirm the partition/account options needed on Nova.

## 2. Create the project directory

```bash
mkdir -p isu-bash-pipeline-workshop
cd isu-bash-pipeline-workshop
mkdir -p 00_scripts 00_ref 01_data logs
pwd
```

Every later command assumes your working directory is this folder.

## 3. Copy the data and reference

- Reads: 5 paired-end samples, `bio_sample_01_R1.fastq.gz` ... `bio_sample_05_R2.fastq.gz`, go in `01_data/`.
- Reference: the genome these reads come from goes in `00_ref/genome.fa`.

TODO: add the copy commands, the source path, and the size of the data and reference.

## 4. Check the tools

```bash
module purge
module load fastp
module load parallel
module load bwa-mem2
module load samtools
fastp --version
parallel --version | head -n 1
bwa-mem2 version
samtools --version | head -n 1
```

TODO: confirm module names with `module avail`.

## 5. Editing files

Scripts are created in the editor (VSCode on OnDemand, or `nano 00_scripts/01_fastp.sh`). A script starts with a shebang line, `#!/usr/bin/env bash`, which tells the system to run it with bash. Make it runnable with `chmod +x` and run it with `./00_scripts/01_fastp.sh`.
