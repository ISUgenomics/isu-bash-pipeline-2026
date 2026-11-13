# Cheat sheet: bash pipelines on Nova

Run everything from the project root.

## Script skeleton

```bash
#!/usr/bin/env bash
set -euo pipefail        # -e stop on error, -u unset variable is an error, -o pipefail fail if any pipe stage fails

SAMPLE="${1:?Usage: $0 <sample_id>}"   # required argument
THREADS="${THREADS:-4}"                # optional, default 4
mkdir -p outdir logs
module purge && module load fastp samtools
```

Make runnable: `chmod +x script.sh`. Run: `time ./script.sh`.

## Variables, loops, names

| Task | Syntax |
|---|---|
| Set / use variable | `DIR=01_data` / `"$DIR"` (quote it) |
| Command output into variable | `n=$(zcat f.gz \| wc -l)` |
| Arithmetic | `$(( n / 4 ))` |
| Strip directory and suffix | `basename "$f" _R1.fastq.gz` |
| Loop over files | `for f in 01_data/*_R1.fastq.gz; do ...; done` |
| Test file exists and is non-empty | `[[ -s "$f" ]]` |

## Redirection

| | |
|---|---|
| `> file` | stdout to file (overwrite) |
| `2> file` | stderr to file |
| `> file 2>&1` | both to file |
| `\| tee file` | show and save |
| `a \| b` | stdout of `a` becomes stdin of `b` |

## Tool commands used in the workshop

```bash
# Trim a pair (fastp)
fastp -i R1.fq.gz -I R2.fq.gz -o out_R1.fq.gz -O out_R2.fq.gz -h s.html -j s.json -w 4

# Index reference (once)
bwa index 02_reference/b73_chr1_150000001-151000000.fasta

# Align, sort, index (bwa + samtools)
bwa mem -t 8 -R '@RG\tID:s\tSM:s\tPL:ILLUMINA' ref.fa R1.fq.gz R2.fq.gz 2> s.log \
  | samtools sort -@ 2 -o s.sorted.bam -
samtools index s.sorted.bam
samtools flagstat s.sorted.bam
```

## GNU Parallel

```bash
parallel --dry-run -j4 cmd {} ::: a b c      # always dry-run first
parallel -j4 --joblog logs/joblog.tsv cmd {} ::: a b c
parallel --resume-failed -j4 --joblog logs/joblog.tsv cmd {} ::: a b c
```

| Placeholder | Meaning |
|---|---|
| `{}` | the input |
| `{/}` | basename (no directory) |
| `{/.}` | basename, one extension removed (`x.fastq.gz` becomes `x.fastq`) |
| `--rpl '{sample} s:.*/::; s/_R1\.fastq\.gz$//'` | our own placeholder `{sample}`: the sample name from an R1 path (`01_data/s1_R1.fastq.gz` becomes `s1`) |

Quote the command template with `'...'` so parallel, not your shell, fills in the placeholders. Export variables and functions used inside: `export VAR`, `export -f func`.

**Cores used is about `JOBS x (threads per job)`.** Keep it at or below your allocation.

## Slurm

| Task | Command |
|---|---|
| Interactive session | `salloc --account=short_term --partition=interactive --cpus-per-task=10 --mem=16G --time=04:00:00` |
| Submit | `sbatch 00_scripts/11_pipeline_single_job.slurm` |
| Submit array | `sbatch --array=1-5 00_scripts/12_pipeline_array.slurm` (limit running: `1-5%2`; select: `2,4`) |
| My jobs | `squeue -u $USER` |
| Finished job details | `sacct -j <jobid> --format=JobID,State,Elapsed,MaxRSS,ExitCode` |
| Cancel | `scancel <jobid>` (one array task: `scancel <jobid>_<task>`) |

In a batch script: `#SBATCH --cpus-per-task=8`, `--mem=32G`, `--time=04:00:00`, `--output=logs/slurm_%A_%a.out` (`logs/` must exist before submitting). Inside an array task: `$SLURM_ARRAY_TASK_ID`, `$SLURM_CPUS_PER_TASK`.

## Restartable pipeline pattern

```bash
if [[ -s "$OUT" ]]; then echo "skip"; else
  tool ... -o "${OUT}.tmp" && mv "${OUT}.tmp" "$OUT"    # write temp, rename when done
fi
```

## Checking results

```bash
grep -L "Real time" logs/*bwa*.log               # logs missing the finish line (possible failures)
awk -F'\t' 'NR>1 && $7!=0 {print $9}' logs/pipeline_joblog.tsv   # failed jobs from the joblog
ls -lh 11_alignment/*.bam                      # BAMs exist and have a plausible size
```

## Common problems

| Symptom | Likely cause |
|---|---|
| `command not found` | module not loaded in this shell or job |
| Script exits with no message | `set -e` stopped it; check the last log file |
| `unbound variable` | a variable is misspelled or not exported (`set -u`) |
| Parallel job cannot see a variable | missing `export` |
| `fail to locate the index files` | reference not indexed, or wrong path |
| Low properly paired % in `flagstat` | R1 and R2 trimmed separately, or listed in the wrong order |
| Job killed, out of memory | raise `--mem`; check `MaxRSS` with `sacct` |
| Slurm job fails instantly with no output | `logs/` did not exist when you submitted |
