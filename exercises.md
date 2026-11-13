# Exercises

One short exercise per lesson. Try each on your own first, then open the solution. Run everything from the project root (see `README.md`).

## Exercise 0: Where am I? (`01_setup.md`, about 3 minutes)

Using only commands from the setup lesson, confirm that:

1. You are **not** on the head node.
2. You can see how many CPUs your session has.
3. `01_data/` contains 10 files.

<details>
<summary>Solution</summary>

```bash
hostname                 # should be a compute node name, not the head node
echo $SLURM_CPUS_PER_TASK   # CPUs in your allocation (empty if you did not use --cpus-per-task)
nproc                    # CPUs visible to your session
ls 01_data | wc -l       # 10
```

</details>

## Exercise 1: Count reads per sample (`02_building_first_script.md`, about 10 minutes)

Write `00_scripts/ex1_count_reads.sh` that loops over the **R1** files in `01_data/` and prints one line per sample: the sample name, a tab, and the number of reads. A FASTQ record is 4 lines, so reads = lines / 4.

Requirements: use variables for the input directory, use `basename` to get the sample name, and start with `set -euo pipefail`.

Hint: `zcat file.fastq.gz | wc -l` counts lines in a gzipped file.

Extension: also save the result to `reads_per_sample.tsv`.

<details>
<summary>Solution</summary>

```bash
#!/usr/bin/env bash

set -euo pipefail

INPUT_DIR=01_data

for file in "$INPUT_DIR"/*_R1.fastq.gz
do
  sample_id=$(basename "$file" _R1.fastq.gz)
  n_reads=$(( $(zcat "$file" | wc -l) / 4 ))
  echo -e "${sample_id}\t${n_reads}"
done
```

Run it, and save the output with `tee`:

```bash
chmod +x 00_scripts/ex1_count_reads.sh
./00_scripts/ex1_count_reads.sh | tee reads_per_sample.tsv
```

Cross-check: the read count should match the `Read1 before filtering: total reads` line in the matching fastp log.

</details>

## Exercise 2: Mapping rate summary (`03_alignment_bwa.md`, about 10 minutes)

Write `00_scripts/ex2_mapped_pct.sh` that loops over the sorted BAM files from the alignment step and prints the sample name and the percentage of reads that mapped, one line per sample. Use `samtools flagstat`.

Hint: the line you want looks like `123456 + 0 mapped (98.52% : N/A)`.

<details>
<summary>Solution</summary>

```bash
#!/usr/bin/env bash

set -euo pipefail

module purge
module load samtools

for bam in 08_alignment/*.sorted.bam
do
  sample_id=$(basename "$bam" .sorted.bam)
  pct=$(samtools flagstat "$bam" | grep -m1 " mapped (" | sed 's/.*(\([0-9.]*\)%.*/\1/')
  echo -e "${sample_id}\t${pct}"
done
```

- `grep -m1` keeps only the first match, which is the "mapped" line (not "primary mapped").
- `sed` keeps just the number inside the parentheses.
- If a sample is far below the others, look at its fastp and bwa logs first.

</details>

## Exercise 3: Predict, then restart (`04_pipeline_combined.md`, about 10 minutes)

1. Make sure the whole pipeline has finished (all five samples done).
2. Delete **one** sample's BAM and its index:

   ```bash
   rm 11_alignment/bio_sample_03.sorted.bam 11_alignment/bio_sample_03.sorted.bam.bai
   ```

3. **Before running anything**, write down which steps you expect to run for each sample when you start the launcher again.
4. Run `./00_scripts/10_run_pipeline.sh` and compare with your prediction.

Extension: with a 16-core allocation, which `JOBS` and `THREADS` would you choose? Remember the cores used are about `JOBS x (THREADS + 2)`.

<details>
<summary>Solution</summary>

- `bio_sample_03`: fastp is **skipped** (trimmed reads still exist) and bwa **runs** (BAM is missing).
- All other samples: both steps **skipped**.
- The output messages should show exactly that (`output exists, skipping` for 9 of the 10 step checks), and the whole run should be quick, because only one alignment is redone.

Extension: `JOBS=3 THREADS=3` uses 3 x (3 + 2) = 15 cores, which fits in 16. `JOBS=4 THREADS=4` would need 24.

</details>

## Exercise 4: Rerun selected array tasks (`04_pipeline_combined.md`, Slurm section, about 5 minutes)

Using the sample list `samples.txt` and `12_pipeline_array.slurm`, submit an array that processes **only samples 2 and 4**, and at most one at a time. Then check how the tasks finished. If one is still queued and you change your mind, cancel it.

<details>
<summary>Solution</summary>

```bash
sbatch --array=2,4%1 00_scripts/12_pipeline_array.slurm
squeue -u $USER
sacct -j <jobid> --format=JobID,State,Elapsed,ExitCode
scancel <jobid>_4        # cancel a single array task (use scancel <jobid> to cancel all)
```

- `--array=2,4` picks task indices 2 and 4 (lines 2 and 4 of `samples.txt`).
- `%1` limits it to one running task at a time.
- If the BAMs for those samples already exist, the tasks finish within seconds because both steps are skipped.

</details>
