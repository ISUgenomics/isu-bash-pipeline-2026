# Building your first script: fastp, loops and GNU Parallel

## Some questions:
1. Have you used `VSCode server` on `Nova OnDemand` before?
2. Are you comfortable with basic bash commands like `ls`, `cd`, `mkdir`, `rm`, `cat`, `echo`?
3. Have you written simple bash scripts combining several steps into a pipeline before?
4. Are you comfortable with using bash variables and loops?
5. Are you comfortable with submitting batch jobs to a cluster?


### What is a job?

- A job is a command or a script that is run on the command line.

### What is a head node?

- A head node is a node that is used to control the cluster.
- It is the node that will be used to submit your jobs to the cluster.
- Remember, we DO NOT run intensive jobs on this node.

### What is a compute node?

- A compute node is a node that is used to run your intensive jobs.


### How we organise the project

A pipeline makes many files. A clear layout and clear names help you (and others) find things and re-run the work later.

```text
00_scripts/      our scripts
01_data/         the raw reads (we never change these)
02_reference/    the reference genome
03_fastp/        output of one step (one folder per step)
04_fastp_loop/   ...
logs/            one log file per run
```

Our simple rules:

- **One folder for each kind of file**: scripts, raw data, reference, results of each step, logs. Raw data is never edited. Results go into new folders, so we can delete and re-make them.
- **Numbers at the start of a name** keep the folders in the order we made them (`00`, `01`, `02`, ...). The scripts have their own numbers: `01_fastp.sh`, `02_fastp_loop.sh`, ...
- **A log starts with the number of the script that wrote it**, and ends with the sample name: `logs/03_fastp_loop_bio_sample_01.log`. So you can always tell which script made which log.
- **The sample name is part of every file name** (`bio_sample_01_R1.trimmed.fastq.gz`), so a file name tells you where it came from.
- **Use lowercase letters, numbers and `_`. No spaces.** Spaces break commands unless you quote them.
- **Run everything from the project folder**, so the paths (`01_data/`, `logs/`) work the same for every script.

### What are the files in the data folder?

```bash
ls 01_data/
```

<details>
<summary>Output</summary>
<pre>
bio_sample_01_R1.fastq.gz  bio_sample_02_R1.fastq.gz  bio_sample_03_R1.fastq.gz  bio_sample_04_R1.fastq.gz  bio_sample_05_R1.fastq.gz
bio_sample_01_R2.fastq.gz  bio_sample_02_R2.fastq.gz  bio_sample_03_R2.fastq.gz  bio_sample_04_R2.fastq.gz  bio_sample_05_R2.fastq.gz
</pre>
</details>

### Quality control and trimming of the reads using fastp

Our reads are **paired-end**: each sample has two files, `R1` and `R2`. Read N in R1 is the mate of read N in R2. We give both files to fastp in one command, so it keeps the pairs together. This matters later, when we align the reads.

#### One sample

Start with a clean set of modules:

```bash
module purge
```

Load fastp:

```bash
module load fastp
```

Make the output folder:

```bash
mkdir -p 03_fastp
```

- `mkdir -p` creates the directory if it does not exist (and does not complain if it already does).

Run fastp on one sample:

```bash
fastp \
  -i 01_data/bio_sample_01_R1.fastq.gz -I 01_data/bio_sample_01_R2.fastq.gz \
  -o 03_fastp/bio_sample_01_R1.trimmed.fastq.gz \
  -O 03_fastp/bio_sample_01_R2.trimmed.fastq.gz \
  -h 03_fastp/bio_sample_01.html \
  -j 03_fastp/bio_sample_01.json
```

- `-i` is the input FASTQ file for read 1 and `-o` is its output (quality filtered and adapter trimmed).
- `-I` is the input FASTQ file for read 2 and `-O` is its output.
- `-h` writes the HTML quality report and `-j` writes the JSON report. There is one report per sample, not one per file.

Once the program is run, it will create a directory called `03_fastp` and put the output files in it.

```bash
ls 03_fastp
```

<details>
<summary>Output</summary>
<pre>
bio_sample_01.html  bio_sample_01.json  bio_sample_01_R1.trimmed.fastq.gz  bio_sample_01_R2.trimmed.fastq.gz
</pre>
</details>

Remove the folder created so we can repeat the run from a script:

```bash
rm -r 03_fastp
```

Create the scripts directory (if you have not already):

```bash
mkdir -p 00_scripts
```

Then open a new file `00_scripts/01_fastp.sh` in the editor and add:

```bash
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
```

- Explanation of the command in the script:
  - `fastp -i ... -I ... -o ... -O ... -h ... -j ...` runs fastp on the sample and writes the trimmed reads and the HTML/JSON reports to the `03_fastp/` directory.
  - `> logs/01_fastp.log` redirects standard output (stdout, file descriptor 1) to the log file, overwriting it if it exists.
  - `2>&1` redirects standard error (stderr, file descriptor 2) to the same destination as stdout, so both stdout and stderr end up in `logs/01_fastp.log`. fastp writes its progress messages to stderr, so this is needed to capture them.
  - This pattern is useful to capture all program messages for troubleshooting and record-keeping. Ensure `logs/` exists (we created it with `mkdir -p logs`).
  - Tip: If you want to see the output live and also save it, you can use `tee`, e.g., `... 2>&1 | tee logs/01_fastp.log`.

**Make the script an executable file**

```bash
chmod +x 00_scripts/01_fastp.sh
```

**Run the script**

```bash
time ./00_scripts/01_fastp.sh
```

**Output**

```
real    0m5.4s
user    0m15.2s
sys     0m1.1s
```

Your times will be a little different. Note the time for one sample (about 5 seconds). We will compare it with the loop and with GNU Parallel.

- `real`: The wall-clock time — how long the command took from start to finish
          Includes everything: CPU time, waiting for I/O (disk, network), scheduling delays, etc.
- `user`: The amount of CPU time spent in user space (your program’s own code, libraries, calculations).
          Example: crunching numbers in Python, sorting data, compressing a file.
- `sys` : The amount of CPU time spent in kernel space (system calls and OS overhead).
          Example: reading/writing files, allocating memory, handling I/O requests.

Here `user` (15 s) is larger than `real` (5 s) because fastp uses several threads at the same time. The CPU time of all threads adds up.

#### Multiple samples (looping through samples)

A simple example:

```bash
# A simple loop example: list the R1 file of each sample in 01_data/
for r1 in 01_data/*_R1.fastq.gz
do
  echo "Found file: $r1"
done
```

- The `for ... in ... do ... done` construct repeats the commands between `do` and `done` for each matched file.
- `01_data/*_R1.fastq.gz` expands (globs) to the R1 file of every sample. We loop over R1 files only, so we get **one round per sample**, not one per file. The R2 file is found from the sample name.
- `$r1` is a shell variable that holds the current filename; `echo` prints text to the terminal.

**Run `fastp` on all samples in `01_data/`**

```bash
#!/usr/bin/env bash

module purge
module load fastp

mkdir -p 04_fastp_loop logs

for r1 in 01_data/*_R1.fastq.gz
do
  sample_id=$(basename "$r1" _R1.fastq.gz)
  r2="01_data/${sample_id}_R2.fastq.gz"
  echo "Running fastp on: $sample_id"
  fastp \
    -i "$r1" -I "$r2" \
    -o "04_fastp_loop/${sample_id}_R1.trimmed.fastq.gz" \
    -O "04_fastp_loop/${sample_id}_R2.trimmed.fastq.gz" \
    -h "04_fastp_loop/${sample_id}.html" \
    -j "04_fastp_loop/${sample_id}.json" \
    > logs/02_fastp_loop.log 2>&1
done
```

- `basename "$r1" _R1.fastq.gz` strips the directory and the `_R1.fastq.gz` ending, giving the sample name, e.g. `bio_sample_01`.
- `r2="01_data/${sample_id}_R2.fastq.gz"` builds the name of the matching R2 file from the sample name.
- We need the sample name because fastp does not name its reports after the input: without unique `-h`/`-j` names every sample would overwrite the same `fastp.html`/`fastp.json`.

Save this script as `02_fastp_loop.sh` in `00_scripts` directory.

Make it executable:

```bash
chmod +x 00_scripts/02_fastp_loop.sh
```

**Run the script**

```bash
time ./00_scripts/02_fastp_loop.sh
```

<details>
<summary>Output</summary>
<pre>
Running fastp on: bio_sample_01
Running fastp on: bio_sample_02
Running fastp on: bio_sample_03
Running fastp on: bio_sample_04
Running fastp on: bio_sample_05

real    0m30.5s
user    1m58.5s
sys     0m5.4s
</pre>
</details>

The samples are processed one after the other, so the total time is the sum of the times for each sample.

Check the log file:

```bash
cat logs/02_fastp_loop.log
```

The log file only contains the fastp summary (read counts before/after filtering, adapter trimming, duplication rate) for the last sample, because each iteration overwrites the log with `>`.

Let us now make sure that we have a log file for each sample.

```bash
#!/usr/bin/env bash

module purge
module load fastp

INPUT_DIR="01_data"
OUTPUT_DIR="05_fastp_loop_samplename"
LOG_DIR="logs"

mkdir -p "$OUTPUT_DIR" "$LOG_DIR"

for r1 in "$INPUT_DIR"/*_R1.fastq.gz
do
  sample_id=$(basename "$r1" _R1.fastq.gz)
  r2="$INPUT_DIR/${sample_id}_R2.fastq.gz"
  echo "Running fastp on: $sample_id"
  fastp \
    -i "$r1" -I "$r2" \
    -o "$OUTPUT_DIR/${sample_id}_R1.trimmed.fastq.gz" \
    -O "$OUTPUT_DIR/${sample_id}_R2.trimmed.fastq.gz" \
    -h "$OUTPUT_DIR/${sample_id}.html" \
    -j "$OUTPUT_DIR/${sample_id}.json" \
    > "$LOG_DIR/03_fastp_loop_${sample_id}.log" 2>&1
done
```

Using shell variables in the loop (and quoting them, `"$r1"`, so names with spaces do not break the command) helps to make the script more readable, maintainable, and reusable.

Save this script as `03_fastp_loop_samplename.sh` in `00_scripts` directory.

Make it executable:

```bash
chmod +x 00_scripts/03_fastp_loop_samplename.sh
```

**Run the script:**

```bash
time ./00_scripts/03_fastp_loop_samplename.sh
```

<details>
<summary>Output</summary>
<pre>
Running fastp on: bio_sample_01
Running fastp on: bio_sample_02
Running fastp on: bio_sample_03
Running fastp on: bio_sample_04
Running fastp on: bio_sample_05

real    0m33.9s
user    2m6.4s
sys     0m5.4s
</pre>
</details>

The time is the same as before. We only changed how the logs are saved.

Check the log files:

```bash
less logs/03_fastp_loop_bio_sample*log
```

Using `less` we can view the contents of the log files. To move from one file to the next, use the `:n` command within `less`. To move to the previous file, use the `:p` command.

To check if all samples have been processed, we can use the `grep` command. fastp prints a final line with the run time when it finishes successfully.

```bash
grep "time used" logs/03_fastp_loop_bio_sample*log
```

<details>
<summary>Output</summary>
<pre>
logs/03_fastp_loop_bio_sample_01.log:fastp v1.0.1, time used: 4 seconds
logs/03_fastp_loop_bio_sample_02.log:fastp v1.0.1, time used: 16 seconds
logs/03_fastp_loop_bio_sample_03.log:fastp v1.0.1, time used: 3 seconds
logs/03_fastp_loop_bio_sample_04.log:fastp v1.0.1, time used: 5 seconds
logs/03_fastp_loop_bio_sample_05.log:fastp v1.0.1, time used: 5 seconds
</pre>
</details>

You should see 5 lines, one for each sample. The times and the order of the lines may differ on your run. If a sample is missing, open its log to see what went wrong.

Notice that `bio_sample_02` takes much longer than the others (16 seconds). It is the biggest sample. Keep this in mind for the next section.

#### Multiple samples (GNU Parallel)

Let us now use GNU Parallel to run fastp on all samples at the same time.
The first step is go for a dry run to see what commands will be executed.

Load GNU Parallel:

```bash
module load parallel
```

Now the dry run (this is one long command):

```bash
parallel --dry-run -j 5 --rpl '{sample} s:.*/::; s/_R1\.fastq\.gz$//' 'fastp -i {} -I 01_data/{sample}_R2.fastq.gz -o 06_fastp_parallel/{sample}_R1.trimmed.fastq.gz -O 06_fastp_parallel/{sample}_R2.trimmed.fastq.gz -h 06_fastp_parallel/{sample}.html -j 06_fastp_parallel/{sample}.json' ::: 01_data/*_R1.fastq.gz
```

- `--dry-run` prints the commands that would be run, without running them. Always check first.
- `-j 5` means run up to 5 jobs at the same time. We have 5 samples, so we use 5 jobs. Do not set it much higher than the number of cores you have.
- The quoted string is the command template. `{}` is replaced by each input file name (the R1 file of a sample).
- `--rpl '{sample} s:.*/::; s/_R1\.fastq\.gz$//'` makes our own placeholder called `{sample}`. It removes the folder name and the `_R1.fastq.gz` ending, so `01_data/bio_sample_01_R1.fastq.gz` becomes `bio_sample_01`. (It is the same job `basename` did in the loop.) We use it to build the R2 file name and the output names.
- `:::` starts the list of inputs. The shell expands `01_data/*_R1.fastq.gz` to the R1 file of each sample.

Check the output. You should see 5 `fastp` commands, one per sample, with `{sample}` already replaced. For example:

<details>
<summary>Output (first line)</summary>
<pre>
fastp -i 01_data/bio_sample_01_R1.fastq.gz -I 01_data/bio_sample_01_R2.fastq.gz -o 06_fastp_parallel/bio_sample_01_R1.trimmed.fastq.gz -O 06_fastp_parallel/bio_sample_01_R2.trimmed.fastq.gz -h 06_fastp_parallel/bio_sample_01.html -j 06_fastp_parallel/bio_sample_01.json
</pre>
</details>

If you still see `{sample}` in the output, check that you typed the `--rpl` part exactly.

To actually run the commands (not just show them), remove `--dry-run`:

```bash
#!/usr/bin/env bash

module purge
module load parallel
module load fastp

mkdir -p 06_fastp_parallel logs

parallel -j5 --rpl '{sample} s:.*/::; s/_R1\.fastq\.gz$//' \
  'fastp -i {} -I 01_data/{sample}_R2.fastq.gz -o 06_fastp_parallel/{sample}_R1.trimmed.fastq.gz -O 06_fastp_parallel/{sample}_R2.trimmed.fastq.gz -h 06_fastp_parallel/{sample}.html -j 06_fastp_parallel/{sample}.json > logs/04_fastp_parallel_{sample}.log 2>&1' \
  ::: 01_data/*_R1.fastq.gz
```

- The trailing `\` characters split the long command over several lines, so it is easier to read.
- Quotes `'...'` keep the whole fastp template as one string, so that GNU Parallel (not your shell) fills in `{}` and `{sample}`.
- `{}` is the R1 file. `{sample}` is the sample name (defined by `--rpl`). We use it to name the outputs and the logs, e.g. `logs/04_fastp_parallel_bio_sample_01.log`.
- `> logs/04_fastp_parallel_{sample}.log 2>&1` writes the messages of each fastp run to its own log file.

Add the above script to `00_scripts/04_fastp_parallel.sh`.

Make it executable:

```bash
chmod +x 00_scripts/04_fastp_parallel.sh
```

**Run the script**

```bash
time ./00_scripts/04_fastp_parallel.sh
```

<details>
<summary>Output</summary>
<pre>
real    0m17.1s
user    1m44.3s
sys     0m4.6s
</pre>
</details>

The loop took about 30 seconds. GNU Parallel takes about 17 seconds. It is faster, but not 5 times faster. Why?

- All 5 samples start together, but the run is only finished when the **slowest** sample is finished. `bio_sample_02` alone needs about 16 seconds, so the total cannot be shorter than that.
- Parallel helps most when you have many jobs of similar size.

- **Why `user` > `real` here**
  - CPU time across cores adds up. fastp is itself multi-threaded, so `user` was already above `real` for the single-sample run. With GNU Parallel running 5 jobs at once, the gap grows: `user` is about 1m44s while `real` is only 17 seconds.

- **How to interpret**
  - Use `real` to estimate elapsed time for the end-to-end run (what you experience).
  - Use `user + sys` to gauge how much total CPU work was consumed. Large gaps between `real` and `user+sys` often indicate parallelism; very small `user`/`sys` compared to `real` can indicate waiting on I/O.

#### Cleaner shell script

```bash
#!/usr/bin/env bash

set -euo pipefail # error handling:
                  # -e: exit immediately if any command returns a non-zero exit status (error)
                  # -u: treat unset variables as an error and exit (useful for debugging)
                  # -o pipefail: exit if any command in a pipeline fails (useful for debugging)

# Directories
# Input directory
INPUT_DIR="01_data"

# Output directory
OUTPUT_DIR="07_fastp_parallel_improved"

# Log directory
LOG_DIR="logs"

# Number of samples to run at the same time
JOBS=5

# Create required directories
mkdir -p "$OUTPUT_DIR" "$LOG_DIR"

# make them visible to subshells that parallel spawns
export OUTPUT_DIR LOG_DIR INPUT_DIR

# Load required modules
module load parallel
module load fastp

# Run fastp
parallel -j"$JOBS" --rpl '{sample} s:.*/::; s/_R1\.fastq\.gz$//' \
  'fastp -i "{}" -I "$INPUT_DIR/{sample}_R2.fastq.gz" \
     -o "$OUTPUT_DIR/{sample}_R1.trimmed.fastq.gz" \
     -O "$OUTPUT_DIR/{sample}_R2.trimmed.fastq.gz" \
     -h "$OUTPUT_DIR/{sample}.html" \
     -j "$OUTPUT_DIR/{sample}.json" \
     > "$LOG_DIR/05_fastp_parallel_improved_{sample}.log" 2>&1' \
  ::: "$INPUT_DIR"/*_R1.fastq.gz
```

- `set -euo pipefail` makes the script stop at the first error, instead of carrying on silently.
- `export` is needed because GNU Parallel runs each job in a new shell. Without it, `$OUTPUT_DIR`, `$LOG_DIR` and `$INPUT_DIR` would be empty inside the quotes.
- The `parallel` command is the same as before, but now the folder names and the number of jobs come from the variables at the top. To use new folders or more jobs, change only those lines.

Add the above script to `00_scripts/05_fastp_parallel_improved.sh`.

Make it executable:

```bash
chmod +x 00_scripts/05_fastp_parallel_improved.sh
```

Run the script:

```bash
time ./00_scripts/05_fastp_parallel_improved.sh
```

<details>
<summary>Output</summary>
<pre>
real    0m15.2s
user    1m40.5s
sys     0m5.3s
</pre>
</details>

The time is the same as the previous script. The cleaner version only makes the script easier to read and to reuse.

**How many cores do I have?**

```bash
nproc
```

Set `JOBS` (the `-j` value) to a number that is not much higher than this. If you ask for more jobs than cores, the jobs compete with each other and nothing gets faster.

**What did we make?**

```bash
ls 07_fastp_parallel_improved | head
```

For each sample we have two trimmed FASTQ files (`R1` and `R2`), an HTML report and a JSON report. The trimmed pairs in `07_fastp_parallel_improved/` are the input for the next lesson (alignment).

#### Keep a record of what you used

Anyone (including you, in six months) should be able to get the same result again. Three habits help:

- **Load the modules inside the script.** Every script starts with `module purge` and `module load ...`, so it runs the same way in any session. It does not depend on what you loaded by hand before.
- **Keep the scripts and the logs.** The script shows *what* was run, and the log shows what the program said.
- **Write down the versions of the tools.** Different versions can give different results.

Check the version of a tool:

```bash
fastp --version
```

<details>
<summary>Output</summary>
<pre>
fastp 1.0.1
</pre>
</details>

See all the modules that are loaded:

```bash
module list
```

<details>
<summary>Output</summary>
<pre>
Currently Loaded Modules:
1) libisal/2.31.0-y37xm3e   4) libdeflate/1.18-qdyjwrz
2) gzip/1.13-dd46t2i        5) fastp/1.0.1-ph6eq7r
3) zlib-ng/2.2.1-4rxbcvx
</pre>
</details>

(Your list may be a little different. It depends on which modules you loaded.) fastp also writes its version into every log: look at the `grep "time used"` output above, it shows `fastp v1.0.1`.
