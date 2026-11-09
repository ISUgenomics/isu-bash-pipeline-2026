# Combining trimming and alignment into one pipeline

Previous steps: `01_building_first_script.md` (fastp) and `02_alignment_bwa.md` (bwa).

Assumptions (same as before):

- Reference genome at `02_reference/b73_chr1_150000001-151000000.fasta` (from the setup), already indexed with `bwa index` in the alignment lesson.
- Module names `fastp`, `bwa`, `samtools`, `parallel`.
- Paired-end input named `01_data/<sample>_R1.fastq.gz` and `01_data/<sample>_R2.fastq.gz`.

### Design

Instead of one long script that loops over everything, we split the work in two:

1. **`09_pipeline_sample.sh <sample_id>`**: runs the whole pipeline (fastp, then bwa piped to samtools, then index and flagstat) for **one** sample.
2. **`10_run_pipeline.sh`**: finds the samples and runs script 1 on them with GNU Parallel.

Why split it this way:

- The per-sample script can be tested on one sample before running everything.
- A failure in one sample does not stop the others.
- Re-running only does the work that is missing (each step is skipped if its output already exists).
- Later, the same per-sample script can be reused unchanged with a Slurm job array.

### Directory layout

```
00_scripts/09_pipeline_sample.sh
00_scripts/10_run_pipeline.sh
01_data/                 raw reads
02_reference/            reference genome (+ bwa index files)
10_fastp_paired/         trimmed reads + fastp reports
11_alignment/            sorted BAM + index + flagstat
logs/                    one log per sample and step
```

### The per-sample script

Create the script using `touch`.

```bash
touch 00_scripts/09_pipeline_sample.sh
```

Then open the new file `00_scripts/09_pipeline_sample.sh` in the editor and add:

```bash
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
```

Explanation of the new pieces:

- `"${1:?Usage: ...}"` exits with a message if no sample name is given. `"${2:-02_reference/b73_chr1_150000001-151000000.fasta}"` uses a default when the reference argument is omitted.
- `THREADS="${THREADS:-4}"` lets the launcher (or you) override the thread count without editing the script.
- The input check stops the script immediately, with a clear message, instead of failing halfway through. The `.bwt` file is one of the `bwa` index files. If it is missing, the reference has not been indexed yet.
- **Skip if done**: each step checks for its final output. Re-running the pipeline after a failure only redoes the missing work.
- **Write to `tmp_` / `.tmp`, then `mv`**: if a step is killed halfway, the partial file has a temporary name and is not mistaken for a finished result on the next run. (fastp decides on gzip output from the `.gz` ending, so the temporary fastp names keep it.)
- `set -euo pipefail` stops the script if `bwa` fails, even though it sits in a pipe with `samtools sort`.

Make it executable and test on **one** sample first:

```bash
chmod +x 00_scripts/09_pipeline_sample.sh
time ./00_scripts/09_pipeline_sample.sh bio_sample_01
```

<details>
<summary>Output</summary>
<pre>
[bio_sample_01] fastp: running
[bio_sample_01] bwa: running
[bio_sample_01] done

real    0m45.8s
user    2m45.6s
sys     0m1.8s
</pre>
</details>

Check the results:

```bash
ls 10_fastp_paired 11_alignment logs
cat 11_alignment/bio_sample_01.flagstat.txt
```

<details>
<summary>Output</summary>
<pre>
10_fastp_paired:
bio_sample_01.html  bio_sample_01.json  bio_sample_01_R1.trimmed.fastq.gz  bio_sample_01_R2.trimmed.fastq.gz

11_alignment:
bio_sample_01.flagstat.txt  bio_sample_01.sorted.bam  bio_sample_01.sorted.bam.bai

logs:
bio_sample_01_bwa.log  bio_sample_01_fastp.log

735716 + 0 in total (QC-passed reads + QC-failed reads)
729490 + 0 primary
0 + 0 secondary
6226 + 0 supplementary
0 + 0 duplicates
0 + 0 primary duplicates
363985 + 0 mapped (49.47% : N/A)
357759 + 0 primary mapped (49.04% : N/A)
729490 + 0 paired in sequencing
364745 + 0 read1
364745 + 0 read2
278086 + 0 properly paired (38.12% : N/A)
331058 + 0 with itself and mate mapped
26701 + 0 singletons (3.66% : N/A)
0 + 0 with mate mapped to a different chr
0 + 0 with mate mapped to a different chr (mapQ>=5)
</pre>
</details>

Your numbers may differ by a few reads, because the result of `bwa` can change a little with the number of threads. The mapped rate is about 49% because our reference is only a 1 Mb piece of a chromosome.

Run it a second time. Both steps should now be skipped almost instantly:

```bash
time ./00_scripts/09_pipeline_sample.sh bio_sample_01
```

<details>
<summary>Output</summary>
<pre>
[bio_sample_01] fastp: output exists, skipping
[bio_sample_01] bwa: output exists, skipping
[bio_sample_01] done

real    0m3.0s
user    0m2.2s
sys     0m0.4s
</pre>
</details>

### The launcher: all samples with GNU Parallel

Create the script using `touch`.

```bash
touch 00_scripts/10_run_pipeline.sh
```

Then open the new file `00_scripts/10_run_pipeline.sh` in the editor and add:

```bash
#!/usr/bin/env bash

set -euo pipefail

# Concurrency: JOBS samples at a time, THREADS threads for each
JOBS="${JOBS:-2}"
export THREADS="${THREADS:-3}"

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
  ./00_scripts/09_pipeline_sample.sh {} ::: $SAMPLES
```

- `JOBS` samples run at the same time, each with `THREADS` threads. **Cores used is about `JOBS x THREADS`** (plus 2 samtools sort threads per sample), so keep this at or below the cores you requested.
  - Example: with 16 cores, `JOBS=3 THREADS=3` uses about 3 x (3 + 2) = 15 cores. The defaults (`JOBS=2 THREADS=3`) use about 2 x (3 + 2) = 10 cores, which is the size of our session.
  - Override from the command line: `JOBS=2 THREADS=8 ./00_scripts/10_run_pipeline.sh`.
- `export THREADS` makes the value visible to the per-sample script that parallel starts.
- `--joblog` records the start time, runtime and exit code of every sample.

Do a dry run first, which prints the commands without running them:

```bash
parallel --dry-run -j2 ./00_scripts/09_pipeline_sample.sh {} ::: bio_sample_01 bio_sample_02
```

<details>
<summary>Output</summary>
<pre>
./00_scripts/09_pipeline_sample.sh bio_sample_01
./00_scripts/09_pipeline_sample.sh bio_sample_02
</pre>
</details>

Make it executable and run:

```bash
chmod +x 00_scripts/10_run_pipeline.sh
time ./00_scripts/10_run_pipeline.sh
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
[bio_sample_01] fastp: running
[bio_sample_01] bwa: running
[bio_sample_03] fastp: running
...
[bio_sample_02] done

real    3m47.1s
user    21m2.4s
sys     0m12.5s
</pre>
</details>

The lines from different samples are mixed, because the samples run at the same time. `bio_sample_02` is the biggest sample and needs about 3.5 minutes alone, so it decides the total time. Running 2 or 4 samples at a time gives about the same total here.

### Checking that everything worked

Look at the exit code column of the job log (column 7; `0` means success):

```bash
cut -f1,4,7,9 logs/pipeline_joblog.tsv
```

<details>
<summary>Output</summary>
<pre>
Seq	JobRuntime	Exitval	Command
1	    55.154	0	./00_scripts/09_pipeline_sample.sh bio_sample_01
3	    47.082	0	./00_scripts/09_pipeline_sample.sh bio_sample_03
4	    57.789	0	./00_scripts/09_pipeline_sample.sh bio_sample_04
5	    51.090	0	./00_scripts/09_pipeline_sample.sh bio_sample_05
2	   225.881	0	./00_scripts/09_pipeline_sample.sh bio_sample_02
</pre>
</details>

List any failed samples (no output means that all samples worked):

```bash
awk -F'\t' 'NR>1 && $7!=0 {print $9}' logs/pipeline_joblog.tsv
```

Then check the BAMs and per-sample logs:

```bash
ls -lh 11_alignment/*.sorted.bam
grep "mapped (" 11_alignment/*.flagstat.txt
```

### Restarting after a failure

Fix the problem (for example, a missing file or too little memory), then either:

- run the launcher again. Finished samples are skipped, because the per-sample script skips steps whose outputs exist; or
- rerun only the failed jobs with parallel: add `--resume-failed` to the `parallel` line (it uses the same `--joblog` file). In our test, a sample that failed (a missing input file) was tried again, and the samples that had worked were not run again.

### Alternative: the launcher inside one Slurm job

So far we ran `10_run_pipeline.sh` by hand in our interactive session. If the session ends, the run stops. We can instead put the launcher in a **batch job**. Slurm runs it for us in the background, even after we log out.

This is a small wrapper around the launcher. Create the script using `touch`.

```bash
touch 00_scripts/11_pipeline_single_job.sh
```

Then open the new file `00_scripts/11_pipeline_single_job.sh` in the editor and add:

```bash
#!/usr/bin/env bash
#SBATCH --job-name=pipeline_all
#SBATCH --cpus-per-task=10
#SBATCH --mem=16G
#SBATCH --time=01:00:00
#SBATCH --output=logs/slurm_%j.out
#SBATCH --error=logs/slurm_%j.err

set -euo pipefail

# How many samples to run at the same time
export JOBS="${JOBS:-2}"

# Threads per sample: share the CPUs between the samples (2 are left for samtools sort)
export THREADS=$(( SLURM_CPUS_PER_TASK / JOBS - 2 ))
[[ "$THREADS" -ge 1 ]] || THREADS=1

echo "Job $SLURM_JOB_ID on $(hostname): $JOBS samples at a time, $THREADS threads each"

./00_scripts/10_run_pipeline.sh
```

- `#SBATCH` lines ask Slurm for **one** job with 10 CPUs. All the samples share these 10 CPUs.
- `SLURM_CPUS_PER_TASK` is the number of CPUs Slurm gave us. We use it to set `THREADS`, so the number of threads always fits the request. With 10 CPUs and 2 samples at a time: 10 / 2 - 2 = 3 threads per sample, so 2 x (3 + 2) = 10 cores are used.
- `export` makes `JOBS` and `THREADS` visible to the launcher. The launcher reads them (`JOBS="${JOBS:-2}"`), so we do not edit it.
- `%j` is the job ID, so the Slurm output files are named after the job.

Submit it. The `logs/` directory must exist before submitting:

```bash
chmod +x 00_scripts/11_pipeline_single_job.sh
```

```bash
mkdir -p logs
```

```bash
sbatch 00_scripts/11_pipeline_single_job.sh
```

<details>
<summary>Output</summary>
<pre>
Submitted batch job 17338045
</pre>
</details>

Check the job (use your own job ID):

```bash
sacct -j 17338045 --format=JobID,JobName,State,Elapsed,MaxRSS,ExitCode
```

<details>
<summary>Output</summary>
<pre>
JobID           JobName      State    Elapsed     MaxRSS ExitCode
------------ ---------- ---------- ---------- ---------- --------
17338045     pipeline_+  COMPLETED   00:04:28                 0:0
17338045.ba+      batch  COMPLETED   00:04:28   4074552K      0:0
</pre>
</details>

The first line of `logs/slurm_<jobid>.out` is the message from our script, followed by the launcher output:

<details>
<summary>Output</summary>
<pre>
Job 17338045 on nova21-19: 2 samples at a time, 3 threads each
Samples to process:
bio_sample_01
...
</pre>
</details>

The job log, the joblog and the BAM files are the same as before. Use the same checks as above (`cut -f1,4,7,9 logs/pipeline_joblog.tsv`). In our test all 5 samples ended with exit code `0`, and the job took about 4.5 minutes. The job waited in the queue first, so the total time depends on how busy the cluster is.

- To change the number of samples at a time, set `JOBS` when you submit: `sbatch --export=ALL,JOBS=5 --cpus-per-task=15 00_scripts/11_pipeline_single_job.sh`. With 15 CPUs and 5 samples at a time: 15 / 5 - 2 = 1 thread per sample.
- If a sample fails, fix the problem and submit the same script again. Finished samples are skipped.

### Alternative: a Slurm job array

GNU Parallel runs all samples inside **one** allocation. With a Slurm job array, each sample becomes its **own job** with its own CPUs and memory, scheduled independently. The same `09_pipeline_sample.sh` is reused unchanged.

**Step 1: make a sample list** (one sample name per line):

```bash
ls 01_data/*_R1.fastq.gz | xargs -n1 basename | sed 's/_R1.fastq.gz$//' > samples.txt
cat samples.txt
```

<details>
<summary>Output</summary>
<pre>
bio_sample_01
bio_sample_02
bio_sample_03
bio_sample_04
bio_sample_05
</pre>
</details>

**Step 2: the array script.** Create the script using `touch`.

```bash
touch 00_scripts/12_pipeline_array.sh
```

Then open the new file `00_scripts/12_pipeline_array.sh` in the editor and add:

```bash
#!/usr/bin/env bash
#SBATCH --job-name=pipeline
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --time=04:00:00
#SBATCH --output=logs/slurm_%A_%a.out
#SBATCH --error=logs/slurm_%A_%a.err
# Add --account=<your_account> if Slurm asks for one (not needed in our test)
# --mem=32G is more than this small data needs (see MaxRSS below); tune --mem and --time for your data

set -euo pipefail

SAMPLE_LIST="${SAMPLE_LIST:-samples.txt}"

# Pick the line of samples.txt that matches this array task
SAMPLE=$(sed -n "${SLURM_ARRAY_TASK_ID}p" "$SAMPLE_LIST")
[[ -n "$SAMPLE" ]] || { echo "ERROR: no sample for task $SLURM_ARRAY_TASK_ID" >&2; exit 1; }

# Use the CPUs Slurm gave us (2 are left for samtools sort)
export THREADS=$(( SLURM_CPUS_PER_TASK > 2 ? SLURM_CPUS_PER_TASK - 2 : 1 ))

echo "Task $SLURM_ARRAY_TASK_ID: sample $SAMPLE on $(hostname) with $THREADS threads"

./00_scripts/09_pipeline_sample.sh "$SAMPLE"
```

- Lines starting with `#SBATCH` are read by Slurm as job options; they must come before the first command.
- `--cpus-per-task`, `--mem` and `--time` are **per array task** (per sample), not for the whole array.
- `%A` is the array job ID and `%a` the task index, so each task gets its own Slurm output and error file.
- `SLURM_ARRAY_TASK_ID` is set by Slurm for each task. `sed -n "${SLURM_ARRAY_TASK_ID}p"` prints only that line number of `samples.txt`, so task 1 handles the first sample, task 2 the second, and so on.
- `THREADS` is derived from `SLURM_CPUS_PER_TASK`, so the pipeline uses exactly the cores requested. Changing `--cpus-per-task` is enough; nothing else needs editing. This is how concurrency is matched to the requested resources.

**Step 3: submit.** The `logs/` directory must exist before submitting, because Slurm opens the output files before the script starts:

```bash
chmod +x 00_scripts/12_pipeline_array.sh
mkdir -p logs
sbatch --array=1-$(wc -l < samples.txt) 00_scripts/12_pipeline_array.sh
```

<details>
<summary>Output</summary>
<pre>
Submitted batch job 17318743
</pre>
</details>

Optional: limit how many tasks run at once with `%`, e.g. `--array=1-5%2` runs at most 2 samples at a time.

**Step 4: monitor**

```bash
squeue -u $USER
sacct -j <jobid> --format=JobID,JobName,State,Elapsed,MaxRSS,ExitCode
```

<details>
<summary>Output</summary>
<pre>
JobID           JobName      State    Elapsed     MaxRSS ExitCode
------------ ---------- ---------- ---------- ---------- --------
17318743_1     pipeline  COMPLETED   00:00:40                 0:0
17318743_1.+      batch  COMPLETED   00:00:40   1429820K      0:0
17318743_2     pipeline  COMPLETED   00:02:25                 0:0
17318743_2.+      batch  COMPLETED   00:02:25   2612592K      0:0
17318743_3     pipeline  COMPLETED   00:00:42                 0:0
17318743_3.+      batch  COMPLETED   00:00:42   1427156K      0:0
17318743_4     pipeline  COMPLETED   00:00:53                 0:0
17318743_4.+      batch  COMPLETED   00:00:53   1470940K      0:0
17318743_5     pipeline  COMPLETED   00:00:36                 0:0
17318743_5.+      batch  COMPLETED   00:00:36   1428156K      0:0
</pre>
</details>

(The `extern` lines are left out. Your job ID will be different. While the tasks wait to start, `squeue` shows them as `PD` (pending).)

- `MaxRSS` shows the memory each task actually used. Use it to tune `--mem`. Here the tasks used 1.4 to 2.6 GB, so the 32 GB we asked for is much more than needed.
- Per-sample pipeline logs are in `logs/<sample>_fastp.log` and `logs/<sample>_bwa.log`; Slurm's own output is in `logs/slurm_<jobid>_<task>.out/.err`. The `.err` files may contain `Lmod Warning` messages about modules. They are harmless.

**Step 5: rerun only failures.** Because finished steps are skipped, rerunning is cheap. Resubmit just the failed task indices:

```bash
sbatch --array=2,4 00_scripts/12_pipeline_array.sh
```

In our test, tasks 2 and 4 had already finished, so both only printed "output exists, skipping" and ended after about 5 seconds.

**Which one should I use?**

| | GNU Parallel by hand (`10_run_pipeline.sh`) | One batch job (`11_pipeline_single_job.sh`) | Slurm array (`12_pipeline_array.sh`) |
|---|---|---|---|
| Runs | In your interactive session | In the background, as one job | In the background, one job per sample |
| Resources | The session you asked for | One request shared by all samples | Separate request per sample |
| Scheduling | Starts now, stops if you log out | Starts when the one job starts | Tasks start as resources free up |
| Best for | Testing, few samples | Few samples, one node | Many samples, or many nodes |
| Failure handling | Joblog, `--resume-failed` | Joblog, submit again | Resubmit failed indices |

### Things to know

- **Intermediate files are kept.** `10_fastp_paired/` holds the trimmed reads, which are as large as the raw data. Keep them while developing. Once you are confident in the results, you can delete them to save disk space, but then the fastp step has to be redone for any re-run.
- **Module loads inside the script.** The per-sample script loads its own modules so it can be run alone. If your cluster's `module` command is not available in non-interactive shells, load the modules in `10_run_pipeline.sh` instead and remove the `module` lines from the per-sample script. On Nova this was not needed: the `module` lines worked inside the script, both under GNU Parallel and under `sbatch`.
- **Reuse:** `09_pipeline_sample.sh` is used unchanged by all three ways of starting it. Only the way samples are started differs.
