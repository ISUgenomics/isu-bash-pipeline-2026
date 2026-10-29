# Combining trimming and alignment into one pipeline

Previous steps: `building_first_script.md` (fastp) and `alignment_bwa_mem2.md` (bwa-mem2).

Assumptions (same as before; TODO items need to be verified on Nova):

- Reference genome at `00_ref/genome.fa`, already indexed with `bwa-mem2 index` (TODO: confirm path).
- Module names `fastp`, `bwa-mem2`, `samtools`, `parallel` (TODO: confirm with `module avail`).
- Paired-end input named `01_data/<sample>_R1.fastq.gz` and `01_data/<sample>_R2.fastq.gz`.

### Design

Instead of one long script that loops over everything, we split the work in two:

1. **`10_pipeline_sample.sh <sample_id>`**: runs the whole pipeline (fastp, then bwa-mem2 piped to samtools, then index and flagstat) for **one** sample.
2. **`11_run_pipeline.sh`**: finds the samples and runs script 1 on them with GNU Parallel.

Why split it this way:

- The per-sample script can be tested on one sample before running everything.
- A failure in one sample does not stop the others.
- Re-running only does the work that is missing (each step is skipped if its output already exists).
- Later, the same per-sample script can be reused unchanged with a Slurm job array.

### Directory layout

```
00_ref/genome.fa (+ bwa-mem2 index files)
00_scripts/10_pipeline_sample.sh
00_scripts/11_run_pipeline.sh
01_data/                 raw reads
02_fastp_paired/         trimmed reads + fastp reports
03_alignment/            sorted BAM + index + flagstat
logs/                    one log per sample and step
```

### The per-sample script

Save as `00_scripts/10_pipeline_sample.sh`:

```bash
#!/usr/bin/env bash

set -euo pipefail

# Arguments
SAMPLE="${1:?Usage: $0 <sample_id> [reference.fa]}"
REF="${2:-00_ref/genome.fa}"

# Settings (can be overridden from the environment, e.g. THREADS=8)
THREADS="${THREADS:-4}"
INPUT_DIR="${INPUT_DIR:-01_data}"
TRIM_DIR="${TRIM_DIR:-02_fastp_paired}"
ALIGN_DIR="${ALIGN_DIR:-03_alignment}"
LOG_DIR="${LOG_DIR:-logs}"

mkdir -p "$TRIM_DIR" "$ALIGN_DIR" "$LOG_DIR"

module purge
module load fastp
module load bwa-mem2
module load samtools

R1="$INPUT_DIR/${SAMPLE}_R1.fastq.gz"
R2="$INPUT_DIR/${SAMPLE}_R2.fastq.gz"
TRIM_R1="$TRIM_DIR/${SAMPLE}_R1.trimmed.fastq.gz"
TRIM_R2="$TRIM_DIR/${SAMPLE}_R2.trimmed.fastq.gz"
BAM="$ALIGN_DIR/${SAMPLE}.sorted.bam"

# Fail early if inputs are missing
for f in "$R1" "$R2" "$REF" "${REF}.bwt.2bit.64"
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
  echo "[$SAMPLE] bwa-mem2: output exists, skipping"
else
  echo "[$SAMPLE] bwa-mem2: running"
  bwa-mem2 mem -t "$THREADS" \
    -R "@RG\tID:${SAMPLE}\tSM:${SAMPLE}\tPL:ILLUMINA" \
    "$REF" "$TRIM_R1" "$TRIM_R2" \
    2> "$LOG_DIR/${SAMPLE}_bwa_mem2.log" \
    | samtools sort -@ 2 -O bam -T "$ALIGN_DIR/tmp_${SAMPLE}" \
        -o "${BAM}.tmp" -
  mv "${BAM}.tmp" "$BAM"
  samtools index "$BAM"
fi

# Step 3: summary
samtools flagstat "$BAM" > "$ALIGN_DIR/${SAMPLE}.flagstat.txt"

echo "[$SAMPLE] done"
```

Explanation of the new pieces:

- `"${1:?Usage: ...}"` exits with a message if no sample name is given. `"${2:-00_ref/genome.fa}"` uses a default when the reference argument is omitted.
- `THREADS="${THREADS:-4}"` lets the launcher (or you) override the thread count without editing the script.
- The input check stops the script immediately, with a clear message, instead of failing halfway through. The `.bwt.2bit.64` file is one of the bwa-mem2 index files (TODO: confirm the name with `ls 00_ref/`).
- **Skip if done**: each step checks for its final output. Re-running the pipeline after a failure only redoes the missing work.
- **Write to `tmp_` / `.tmp`, then `mv`**: if a step is killed halfway, the partial file has a temporary name and is not mistaken for a finished result on the next run. (fastp decides on gzip output from the `.gz` ending, so the temporary fastp names keep it.)
- `set -euo pipefail` stops the script if `bwa-mem2` fails, even though it sits in a pipe with `samtools sort`.

Make it executable and test on **one** sample first:

```bash
chmod +x 00_scripts/10_pipeline_sample.sh
time ./00_scripts/10_pipeline_sample.sh bio_sample_01
```

<details>
<summary>Output</summary>
<pre>
[bio_sample_01] fastp: running
[bio_sample_01] bwa-mem2: running
[bio_sample_01] done

real    TODO
user    TODO
sys     TODO
</pre>
</details>

Check the results:

```bash
ls 02_fastp_paired 03_alignment logs
cat 03_alignment/bio_sample_01.flagstat.txt
```

<details>
<summary>Output</summary>
<pre>
TODO: paste real output
</pre>
</details>

Run it a second time. Both steps should now be skipped almost instantly:

```bash
time ./00_scripts/10_pipeline_sample.sh bio_sample_01
```

<details>
<summary>Output</summary>
<pre>
[bio_sample_01] fastp: output exists, skipping
[bio_sample_01] bwa-mem2: output exists, skipping
[bio_sample_01] done
</pre>
</details>

### The launcher: all samples with GNU Parallel

Save as `00_scripts/11_run_pipeline.sh`:

```bash
#!/usr/bin/env bash

set -euo pipefail

# Concurrency: JOBS samples at a time, THREADS threads for each
JOBS="${JOBS:-4}"
export THREADS="${THREADS:-4}"

INPUT_DIR="01_data"
LOG_DIR="logs"
mkdir -p "$LOG_DIR"

module purge
module load parallel

# Sample names = R1 file names without the directory and the _R1.fastq.gz suffix
SAMPLES=$(ls "$INPUT_DIR"/*_R1.fastq.gz | xargs -n1 basename | sed 's/_R1.fastq.gz$//')

echo "Samples to process:"
echo "$SAMPLES"

parallel -j"$JOBS" --joblog "$LOG_DIR/pipeline_joblog.tsv" \
  ./00_scripts/10_pipeline_sample.sh {} ::: $SAMPLES
```

- `JOBS` samples run at the same time, each with `THREADS` threads. **Cores used is about `JOBS x THREADS`** (plus 2 samtools sort threads per sample), so keep this at or below the cores you requested.
  - Example: 16 cores gives `JOBS=4 THREADS=3`.
  - Override from the command line: `JOBS=2 THREADS=8 ./00_scripts/11_run_pipeline.sh`.
- `export THREADS` makes the value visible to the per-sample script that parallel starts.
- `--joblog` records the start time, runtime and exit code of every sample.

Do a dry run first (prints the commands without running them), by adding `--dry-run` to the `parallel` line temporarily, or run:

```bash
parallel --dry-run -j4 ./00_scripts/10_pipeline_sample.sh {} ::: bio_sample_01 bio_sample_02
```

Make it executable and run:

```bash
chmod +x 00_scripts/11_run_pipeline.sh
time ./00_scripts/11_run_pipeline.sh
```

<details>
<summary>Output</summary>
<pre>
Samples to process:
bio_sample_01
bio_sample_02
bio_sample_03
bio_sample_04
bio_sample_05
...
real    TODO
user    TODO
sys     TODO
</pre>
</details>

### Checking that everything worked

Look at the exit code column of the job log (column 7; `0` means success):

```bash
cut -f1,4,7,9 logs/pipeline_joblog.tsv
```

<details>
<summary>Output</summary>
<pre>
TODO: paste real output (columns: Seq, Runtime, Exitval, Command)
</pre>
</details>

List any failed samples:

```bash
awk -F'\t' 'NR>1 && $7!=0 {print $9}' logs/pipeline_joblog.tsv
```

Then check the BAMs and per-sample logs:

```bash
ls -lh 03_alignment/*.sorted.bam
grep "mapped (" 03_alignment/*.flagstat.txt
```

### Restarting after a failure

Fix the problem (for example, a missing file or too little memory), then either:

- run the launcher again. Finished samples are skipped, because the per-sample script skips steps whose outputs exist; or
- rerun only the failed jobs with parallel: add `--resume-failed` to the `parallel` line (it uses the same `--joblog` file).

### Things to know

- **Intermediate files are kept.** `02_fastp_paired/` holds the trimmed reads, which are as large as the raw data. Keep them while developing. Once you are confident in the results, you can delete them to save disk space, but then the fastp step has to be redone for any re-run.
- **Module loads inside the script.** The per-sample script loads its own modules so it can be run alone. If your cluster's `module` command is not available in non-interactive shells, load the modules in `11_run_pipeline.sh` instead and remove the `module` lines from the per-sample script (TODO: verify on Nova).
- **Where this goes next:** the same `10_pipeline_sample.sh` can be used unchanged with a Slurm job array (one task per sample), which is covered in the Slurm part of the workshop.
