#!/usr/bin/env bash

set -euo pipefail

module purge
module load bwa

bwa index 02_reference/b73_chr1_150000001-151000000.fasta
