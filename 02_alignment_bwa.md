# Aligning reads to a reference genome with bwa

Previous step: `01_building_first_script.md` (quality control and trimming with fastp).

Before you start:

- The trimmed read pairs from the previous lesson are in `07_fastp_parallel_improved/` (for example `bio_sample_01_R1.trimmed.fastq.gz` and `bio_sample_01_R2.trimmed.fastq.gz`). Check that you have 10 files:

```bash
ls 07_fastp_parallel_improved/*.trimmed.fastq.gz | wc -l
```

- The reference genome is `02_reference/b73_chr1_150000001-151000000.fasta`, the file we copied in the setup. We use it from there.
- The modules are `bwa` and `samtools`.
- Alignment needs R1 and R2 reads to stay in sync (read N in R1 must be the mate of read N in R2). This is why we trimmed each sample as a pair with one fastp command.

Check the reference:

```bash
ls 02_reference/
```

<details>
<summary>Output</summary>
<pre>
b73_chr1_150000001-151000000.fasta
</pre>
</details>

- The FASTA file has one sequence, `chr1`: a 1 Mb piece of maize chromosome 1.

### What is alignment?

- Alignment (mapping) finds where each sequencing read best matches the reference genome.
- `bwa mem` is a widely used aligner for short reads.
- The output is SAM text, which is large. We pipe it into `samtools` to convert to compressed, sorted BAM.

### Step 1: Index the reference (once)

bwa needs an index of the reference before it can align. This is done once per reference. For large genomes it needs a lot of memory and time, so run it on a compute node (not the head node). Our reference is small (about 1 Mb), so it takes about a second.

Create the script using `touch`.

```bash
touch 00_scripts/06_bwa_index.sh
```

Then open the new file `00_scripts/06_bwa_index.sh` in the editor and add:

```bash
#!/usr/bin/env bash

set -euo pipefail

module purge
module load bwa

bwa index 02_reference/b73_chr1_150000001-151000000.fasta
```

Save the file (the index step writes no log of its own; its messages appear in the terminal), then make it executable and run it:

```bash
chmod +x 00_scripts/06_bwa_index.sh
./00_scripts/06_bwa_index.sh
```

- This creates five index files next to the reference, in `02_reference/`. They have the same name as the FASTA file, with `.amb`, `.ann`, `.bwt`, `.pac` or `.sa` added at the end.
- Check that they exist:

```bash
ls 02_reference/
```

<details>
<summary>Output</summary>
<pre>
b73_chr1_150000001-151000000.fasta
b73_chr1_150000001-151000000.fasta.amb
b73_chr1_150000001-151000000.fasta.ann
b73_chr1_150000001-151000000.fasta.bwt
b73_chr1_150000001-151000000.fasta.pac
b73_chr1_150000001-151000000.fasta.sa
</pre>
</details>

- You may see a `Lmod Warning` about `zlib-ng` when you load `bwa`. It is harmless. The module still loads.

### Step 2: Align one sample

```bash
module purge
module load bwa
module load samtools

mkdir -p 08_alignment logs

bwa mem -t 8 \
  -R '@RG\tID:bio_sample_01\tSM:bio_sample_01\tPL:ILLUMINA' \
  02_reference/b73_chr1_150000001-151000000.fasta \
  07_fastp_parallel_improved/bio_sample_01_R1.trimmed.fastq.gz \
  07_fastp_parallel_improved/bio_sample_01_R2.trimmed.fastq.gz \
  2> logs/06_bwa_bio_sample_01.log \
  | samtools sort -@ 4 -o 08_alignment/bio_sample_01.sorted.bam -

samtools index 08_alignment/bio_sample_01.sorted.bam
```

This takes about 25 seconds for sample 01.

- `bwa mem` aligns reads using the MEM algorithm.
  - `-t 8` uses 8 threads. Match this to the cores you requested.
  - `-R` adds a read group header. It records the sample name (`SM`) and is required by many downstream tools (e.g., GATK). The `\t` must be written literally; bwa converts it to a tab.
  - The first argument after the options is the reference; then R1 and R2.
- `2> logs/...` sends bwa's progress messages (stderr) to a log file. SAM output goes to stdout, so we must not redirect stdout to the log.
- `|` pipes the SAM stream straight into `samtools sort`, so the large uncompressed SAM file is never written to disk.
  - `-@ 4` gives samtools 4 additional threads (on top of the main thread).
  - `-o` is the sorted BAM output. The trailing `-` means read from stdin.
- `samtools index` creates the `.bai` index needed for viewing and variant calling.

Quick sanity check of the alignment:

```bash
samtools flagstat 08_alignment/bio_sample_01.sorted.bam
```

<details>
<summary>Output</summary>
<pre>
735717 + 0 in total (QC-passed reads + QC-failed reads)
729490 + 0 primary
0 + 0 secondary
6227 + 0 supplementary
0 + 0 duplicates
0 + 0 primary duplicates
363984 + 0 mapped (49.47% : N/A)
357757 + 0 primary mapped (49.04% : N/A)
729490 + 0 paired in sequencing
364745 + 0 read1
364745 + 0 read2
278070 + 0 properly paired (38.12% : N/A)
331054 + 0 with itself and mate mapped
26703 + 0 singletons (3.66% : N/A)
0 + 0 with mate mapped to a different chr
0 + 0 with mate mapped to a different chr (mapQ>=5)
</pre>
</details>

- `in total` is the number of alignment records (reads, plus a few extra records for split alignments).
- `mapped` is the share of reads that found a place on the reference. It is about 49% here because our reference is only a 1 Mb piece of chromosome 1, so reads from the rest of the genome do not map.
- `properly paired` means both mates mapped, facing each other, at a sensible distance.

### Step 3: Loop over all samples

Sample names come from the R1 files, and R2 is derived from the sample name.

Create the script using `touch`.

```bash
touch 00_scripts/07_bwa_loop.sh
```

Then open the new file `00_scripts/07_bwa_loop.sh` in the editor and add:

```bash
#!/usr/bin/env bash

set -euo pipefail

REF="02_reference/b73_chr1_150000001-151000000.fasta"
INPUT_DIR="07_fastp_parallel_improved"
OUTPUT_DIR="08_alignment"
LOG_DIR="logs"
THREADS=8

mkdir -p "$OUTPUT_DIR" "$LOG_DIR"

module purge
module load bwa
module load samtools

for r1 in $INPUT_DIR/*_R1.trimmed.fastq.gz
do
  sample_id=$(basename "$r1" _R1.trimmed.fastq.gz)
  r2=$INPUT_DIR/${sample_id}_R2.trimmed.fastq.gz

  echo "Aligning: $sample_id"

  bwa mem -t "$THREADS" \
    -R "@RG\tID:${sample_id}\tSM:${sample_id}\tPL:ILLUMINA" \
    "$REF" "$r1" "$r2" \
    2> "$LOG_DIR/07_bwa_loop_${sample_id}.log" \
    | samtools sort -@ 4 -o "$OUTPUT_DIR/${sample_id}.sorted.bam" -

  samtools index "$OUTPUT_DIR/${sample_id}.sorted.bam"
done
```

- `basename "$r1" _R1.trimmed.fastq.gz` strips the directory and suffix to leave `bio_sample_01`.
- `set -euo pipefail` matters here: with `pipefail`, the script stops if `bwa` fails even though `samtools sort` (the last command in the pipe) would otherwise succeed.

Save the file, make it executable, and run:

```bash
chmod +x 00_scripts/07_bwa_loop.sh
time ./00_scripts/07_bwa_loop.sh
```

<details>
<summary>Output</summary>
<pre>
Aligning: bio_sample_01
Aligning: bio_sample_02
Aligning: bio_sample_03
Aligning: bio_sample_04
Aligning: bio_sample_05

real    2m58.5s
user    21m22.4s
sys     0m11.1s
</pre>
</details>

This run used 10 cores. `bwa mem` already uses 8 threads and `samtools sort` uses 4 more, so the 10 cores are busy even though we align one sample at a time. The `user` time (about 21 minutes) is much larger than `real` (about 3 minutes) because many threads work at the same time.

You may also see `[bam_sort_core] merging from ...` lines in the terminal. They are normal `samtools sort` messages.

### Step 4: Several samples at once with GNU Parallel

Each alignment is already multi-threaded, so total cores used = (number of parallel jobs) x (threads per job). Do not request more than you have.

Example: 4 samples at a time, 4 bwa threads and 2 samtools sort threads each.

Create the script using `touch`.

```bash
touch 00_scripts/08_bwa_parallel.sh
```

Then open the new file `00_scripts/08_bwa_parallel.sh` in the editor and add:

```bash
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
```

- A shell function (`align_one`) keeps the multi-line command readable; `export -f` makes it visible to the subshells that parallel spawns.
- `set -euo pipefail` is repeated inside the function because the options set at the top of the script are not inherited by the fresh bash that parallel starts for each job. Without it, a failing `bwa` would go unnoticed.
- The last line builds the list of sample names (`bio_sample_01`, ...) from the R1 files by stripping the directory and the `_R1.trimmed.fastq.gz` suffix, and `parallel` passes one name per job to `align_one` via `{}`.
- Total cores here: 4 jobs x (4 bwa threads + 2 samtools threads) is about 24 threads at peak. This is more than the 10 cores we have, so adjust `-j` and the thread counts to your allocation.

Always dry-run the parallel command first. `--dry-run` prints the command that would run for each sample (here, just the call to `align_one`) without running it:

```bash
parallel --dry-run -j4 align_one {} ::: bio_sample_01 bio_sample_02
```

Save the file, make it executable and time it as before.

<details>
<summary>Output</summary>
<pre>
real    3m20.6s
user    22m50.3s
sys     0m10.4s
</pre>
</details>

**This is not faster than the loop (about 3 minutes in both cases; here it was even a little slower).** Why?

- The loop already kept all 10 cores busy with threads, so running samples side by side gives no extra speed.
- GNU Parallel helps most when each job uses **one or a few** threads and you have many jobs.
- Rule: (jobs) x (threads per job) should be at most the cores you have.

### Check that all samples aligned

```bash
ls -lh 08_alignment/*.bam 09_alignment_parallel/*.bam
grep -L "Real time" logs/06_bwa_*.log logs/07_bwa_loop_*.log logs/08_bwa_parallel_*.log
```

- bwa prints `Real time: ...` at the end of a successful run; `grep -L` lists log files that do **not** contain it, i.e., runs that may have failed. No output means all runs finished.

### Common problems

- **`fail to locate the index files`**: the reference was not indexed, or the path to the reference (`02_reference/b73_chr1_150000001-151000000.fasta`) is wrong.
- **Out of memory when indexing/aligning**: request more memory for the job. Large genomes need much more memory than our small reference.
- **`[E::bwa_set_rg] the read group line is not started with @RG`**: check the quoting of `-R`.
- **Reads not paired in the BAM** (`flagstat` shows 0% properly paired): R1/R2 were trimmed separately or listed in the wrong order.
