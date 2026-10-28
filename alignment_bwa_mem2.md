# Aligning reads to a reference genome with bwa-mem2

Previous step: `building_first_script.md` (quality control and trimming with fastp).

Assumptions (adjust to your setup; items marked TODO need to be verified on Nova):

- The reference genome is at `00_ref/genome.fa` (TODO: replace with the real path).
- Module names are `bwa-mem2` and `samtools` (TODO: confirm with `module avail`).
- Samples are paired-end: `bio_sample_01_R1.fastq.gz` / `bio_sample_01_R2.fastq.gz`, etc.

### What is alignment?

- Alignment (mapping) finds where each sequencing read best matches the reference genome.
- `bwa-mem2` is a faster re-implementation of `bwa mem` that produces the same alignments.
- The output is SAM text, which is large. We pipe it into `samtools` to convert to compressed, sorted BAM.

### Step 0: Trim the reads as pairs

Alignment needs R1 and R2 reads to stay in sync (read N in R1 must be the mate of read N in R2). Running fastp on each file separately (as in the loop sections of the previous step) can drop different reads from R1 and R2, which breaks the pairing. For alignment, trim both mates in a single fastp call using `-i/-I` and `-o/-O`:

```bash
module purge
module load fastp

mkdir -p 02_fastp_paired logs

fastp \
  -i 01_data/bio_sample_01_R1.fastq.gz -I 01_data/bio_sample_01_R2.fastq.gz \
  -o 02_fastp_paired/bio_sample_01_R1.trimmed.fastq.gz \
  -O 02_fastp_paired/bio_sample_01_R2.trimmed.fastq.gz \
  -h 02_fastp_paired/bio_sample_01.html \
  -j 02_fastp_paired/bio_sample_01.json \
  > logs/06_fastp_paired_bio_sample_01.log 2>&1
```

- `-i`/`-o` are read 1 input/output; `-I`/`-O` are read 2 input/output.
- The rest of this page uses `02_fastp_paired/` as the input to alignment.

### Step 1: Index the reference (once)

bwa-mem2 needs an index of the reference before it can align. This is done once per reference and is memory- and time-intensive for large genomes, so run it on a compute node (not the head node).

```bash
module purge
module load bwa-mem2

bwa-mem2 index 00_ref/genome.fa
```

- This creates several files next to the reference (`genome.fa.0123`, `.amb`, `.ann`, `.bwt.2bit.64`, `.pac`).
- Check that they exist:

```bash
ls 00_ref/
```

<details>
<summary>Output</summary>
<pre>
TODO: paste real output
</pre>
</details>

Save as `00_scripts/07_bwa_mem2_index.sh`, then:

```bash
chmod +x 00_scripts/07_bwa_mem2_index.sh
```

### Step 2: Align one sample

```bash
module purge
module load bwa-mem2
module load samtools

mkdir -p 03_alignment logs

bwa-mem2 mem -t 8 \
  -R '@RG\tID:bio_sample_01\tSM:bio_sample_01\tPL:ILLUMINA' \
  00_ref/genome.fa \
  02_fastp_paired/bio_sample_01_R1.trimmed.fastq.gz \
  02_fastp_paired/bio_sample_01_R2.trimmed.fastq.gz \
  2> logs/07_bwa_mem2_bio_sample_01.log \
  | samtools sort -@ 4 -o 03_alignment/bio_sample_01.sorted.bam -

samtools index 03_alignment/bio_sample_01.sorted.bam
```

- `bwa-mem2 mem` aligns reads using the MEM algorithm.
  - `-t 8` uses 8 threads. Match this to the cores you requested.
  - `-R` adds a read group header. It records the sample name (`SM`) and is required by many downstream tools (e.g., GATK). The `\t` must be written literally; bwa-mem2 converts it to a tab.
  - The first argument after the options is the reference; then R1 and R2.
- `2> logs/...` sends bwa-mem2's progress messages (stderr) to a log file. SAM output goes to stdout, so we must not redirect stdout to the log.
- `|` pipes the SAM stream straight into `samtools sort`, so the large uncompressed SAM file is never written to disk.
  - `-@ 4` gives samtools 4 additional threads.
  - `-o` is the sorted BAM output. The trailing `-` means read from stdin.
- `samtools index` creates the `.bai` index needed for viewing and variant calling.

Quick sanity check of the alignment:

```bash
samtools flagstat 03_alignment/bio_sample_01.sorted.bam
```

<details>
<summary>Output</summary>
<pre>
TODO: paste real output (total reads, mapped %, properly paired %)
</pre>
</details>

### Step 3: Loop over all samples

Sample names come from the R1 files, and R2 is derived from the sample name.

```bash
#!/usr/bin/env bash

set -euo pipefail

REF="00_ref/genome.fa"
INPUT_DIR="02_fastp_paired"
OUTPUT_DIR="03_alignment"
LOG_DIR="logs"
THREADS=8

mkdir -p "$OUTPUT_DIR" "$LOG_DIR"

module purge
module load bwa-mem2
module load samtools

for r1 in $INPUT_DIR/*_R1.trimmed.fastq.gz
do
  sample_id=$(basename "$r1" _R1.trimmed.fastq.gz)
  r2=$INPUT_DIR/${sample_id}_R2.trimmed.fastq.gz

  echo "Aligning: $sample_id"

  bwa-mem2 mem -t "$THREADS" \
    -R "@RG\tID:${sample_id}\tSM:${sample_id}\tPL:ILLUMINA" \
    "$REF" "$r1" "$r2" \
    2> "$LOG_DIR/08_bwa_mem2_loop_${sample_id}.log" \
    | samtools sort -@ 4 -o "$OUTPUT_DIR/${sample_id}.sorted.bam" -

  samtools index "$OUTPUT_DIR/${sample_id}.sorted.bam"
done
```

- `basename "$r1" _R1.trimmed.fastq.gz` strips the directory and suffix to leave `bio_sample_01`.
- `set -euo pipefail` matters here: with `pipefail`, the script stops if `bwa-mem2` fails even though `samtools sort` (the last command in the pipe) would otherwise succeed.

Save as `00_scripts/08_bwa_mem2_loop.sh`, make it executable, and run:

```bash
chmod +x 00_scripts/08_bwa_mem2_loop.sh
time ./00_scripts/08_bwa_mem2_loop.sh
```

<details>
<summary>Output</summary>
<pre>
Aligning: bio_sample_01
Aligning: bio_sample_02
Aligning: bio_sample_03
Aligning: bio_sample_04
Aligning: bio_sample_05

real    TODO
user    TODO
sys     TODO
</pre>
</details>

### Step 4: Several samples at once with GNU Parallel

Each alignment is already multi-threaded, so total cores used = (number of parallel jobs) x (threads per job). Do not request more than you have.

Example: 4 samples at a time, 4 bwa-mem2 threads and 2 samtools sort threads each.

```bash
#!/usr/bin/env bash

set -euo pipefail

REF="00_ref/genome.fa"
INPUT_DIR="02_fastp_paired"
OUTPUT_DIR="03_alignment_parallel"
LOG_DIR="logs"

mkdir -p "$OUTPUT_DIR" "$LOG_DIR"
export REF INPUT_DIR OUTPUT_DIR LOG_DIR

module purge
module load parallel
module load bwa-mem2
module load samtools

align_one() {
  sample_id=$1
  bwa-mem2 mem -t 4 \
    -R "@RG\tID:${sample_id}\tSM:${sample_id}\tPL:ILLUMINA" \
    "$REF" \
    "$INPUT_DIR/${sample_id}_R1.trimmed.fastq.gz" \
    "$INPUT_DIR/${sample_id}_R2.trimmed.fastq.gz" \
    2> "$LOG_DIR/09_bwa_mem2_parallel_${sample_id}.log" \
    | samtools sort -@ 2 -o "$OUTPUT_DIR/${sample_id}.sorted.bam" -
  samtools index "$OUTPUT_DIR/${sample_id}.sorted.bam"
}
export -f align_one

parallel -j4 align_one {} ::: $(ls $INPUT_DIR/*_R1.trimmed.fastq.gz | xargs -n1 basename | sed 's/_R1.trimmed.fastq.gz//')
```

- A shell function (`align_one`) keeps the multi-line command readable; `export -f` makes it visible to the subshells that parallel spawns.
- The last line builds the list of sample names (`bio_sample_01`, ...) from the R1 files by stripping the directory and the `_R1.trimmed.fastq.gz` suffix, and `parallel` passes one name per job to `align_one` via `{}`.
- Total cores here: 4 jobs x (4 bwa-mem2 threads + 2 samtools threads) is about 24 threads at peak, so adjust `-j` and the thread counts to your allocation.

Always dry-run the parallel command first (prefix the function call with `echo`):

```bash
parallel --dry-run -j4 align_one {} ::: bio_sample_01 bio_sample_02
```

Save as `00_scripts/09_bwa_mem2_parallel.sh`, make it executable and time it as before.

<details>
<summary>Output</summary>
<pre>
real    TODO
user    TODO
sys     TODO
</pre>
</details>

### Check that all samples aligned

```bash
ls -lh 03_alignment/*.bam
grep -L "Real time" logs/07_bwa_mem2_*.log logs/08_bwa_mem2_loop_*.log
```

- bwa-mem2 prints `Real time: ...` at the end of a successful run; `grep -L` lists log files that do **not** contain it, i.e., runs that may have failed. No output means all runs finished.

### Common problems

- **`fail to locate the index files`**: the reference was not indexed, or the path to `genome.fa` is wrong.
- **Out of memory when indexing/aligning**: request more memory for the job; bwa-mem2 uses noticeably more memory than bwa.
- **`[E::bwa_set_rg] the read group line is not started with @RG`**: check the quoting of `-R`.
- **Reads not paired in the BAM** (`flagstat` shows 0% properly paired): R1/R2 were trimmed separately or listed in the wrong order.
