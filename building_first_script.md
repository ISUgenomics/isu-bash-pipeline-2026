# Running commands and making a script of the commands run

### What is a job?

- A job is a command or a script that is run on the command line.

### What is a head node?

- A head node is a node that is used to control the cluster.
- It is the node that will be used to submit your jobs to the cluster.
- Remember, we DO NOT run intensive jobs on this node. 

### What is a compute node?

- A compute node is a node that is used to run your intensive jobs.


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

### Checking the quality of the reads using FastQC

#### One file

```bash
module purge
module load fastqc
mkdir -p 02_fastqc
fastqc 01_data/bio_sample_01_R1.fastq.gz -o 02_fastqc/
```
-p flag is used to create the directory if it does not exist.

Once the program is run, it will create a directory called `02_fastqc` and put the output files in it.

```bash
ls 02_fastqc
```

<details>
<summary>Output</summary>
<pre>
bio_sample_01_R1_fastqc.html  bio_sample_01_R1_fastqc.zip
</pre>
</details>

Remove the folders created

```bash
rm -r 02_fastqc
```

Open `00_scripts/01_fastqc.sh` in the script window. 

```bash
module purge
module load fastqc
mkdir -p 02_fastqc logs
fastqc 01_data/bio_sample_01_R1.fastq.gz -o 02_fastqc/ > logs/01_fastqc.log 2>&1
```

- Explanation of the command in the script:
  - `fastqc 01_data/bio_sample_01_R1.fastq.gz -o 02_fastqc/` runs FastQC on the input file and writes the results to the `02_fastqc/` directory.
  - `> logs/01_fastqc.log` redirects standard output (stdout, file descriptor 1) to the log file, overwriting it if it exists.
  - `2>&1` redirects standard error (stderr, file descriptor 2) to the same destination as stdout, so both stdout and stderr end up in `logs/01_fastqc.log`.
  - This pattern is useful to capture all program messages for troubleshooting and record-keeping. Ensure `logs/` exists (we created it with `mkdir -p logs`).
  - Tip: If you want to see the output live and also save it, you can use `tee`, e.g., `... 2>&1 | tee logs/01_fastqc.log`.

**Make the script an executable file**

```bash
chmod +x 00_scripts/01_fastqc.sh
```

**Run the script**

```bash
time ./00_scripts/01_fastqc.sh 
```

**Output**

```
real    0m6.949s
user    0m7.568s
sys     0m0.597s
```

- `real`: The wall-clock time — how long the command took from start to finish
          Includes everything: CPU time, waiting for I/O (disk, network), scheduling delays, etc.
- `user`: The amount of CPU time spent in user space (your program’s own code, libraries, calculations).
          Example: crunching numbers in Python, sorting data, compressing a file.
- `sys` : The amount of CPU time spent in kernel space (system calls and OS overhead).
          Example: reading/writing files, allocating memory, handling I/O requests.

#### Multiple files (looping through files)

A simple example:

```bash
# A simple loop example: list files in 01_data/
for file in 01_data/*.fastq.gz 
do
  echo "Found file: $file"
done
```

- The `for ... in ... do ... done` construct repeats the commands between `do` and `done` for each matched file.
- `01_data/*.fastq.gz` expands (globs) to all FASTQ files in the `01_data/` directory.
- `$file` is a shell variable that holds the current filename; `echo` prints text to the terminal.

**Run `FastQC` on all files in `01_data/`**

```bash
module purge
module load fastqc

mkdir -p 03_fastqc_loop

for file in 01_data/*.fastq.gz
do
  echo "Running FastQC on: $file"
  fastqc $file -o 03_fastqc_loop/ > logs/02_fastqc_loop.log 2>&1
done
```

Save this script as `02_fastqc_loop.sh` in `00_scripts` directory.

Make it executable:

```bash
chmod +x 00_scripts/02_fastqc_loop.sh
```

**Run the script**

```bash
time ./00_scripts/02_fastqc_loop.sh
```

<details>
<summary>Output</summary>
<pre>
Running FastQC on: 01_data/bio_sample_01_R1.fastq.gz
Running FastQC on: 01_data/bio_sample_01_R2.fastq.gz
Running FastQC on: 01_data/bio_sample_02_R1.fastq.gz
Running FastQC on: 01_data/bio_sample_02_R2.fastq.gz
Running FastQC on: 01_data/bio_sample_03_R1.fastq.gz
Running FastQC on: 01_data/bio_sample_03_R2.fastq.gz
Running FastQC on: 01_data/bio_sample_04_R1.fastq.gz
Running FastQC on: 01_data/bio_sample_04_R2.fastq.gz
Running FastQC on: 01_data/bio_sample_05_R1.fastq.gz
Running FastQC on: 01_data/bio_sample_05_R2.fastq.gz

real    1m12.560s
user    1m37.585s
sys     0m2.792s
</pre>
</details>

Check the log file:

```bash
cat logs/02_fastqc_loop.log
```

<details>
<summary>Output</summary>
<pre>
Started analysis of bio_sample_05_R2.fastq.gz
Approx 5% complete for bio_sample_05_R2.fastq.gz
Approx 10% complete for bio_sample_05_R2.fastq.gz
Approx 15% complete for bio_sample_05_R2.fastq.gz
Approx 20% complete for bio_sample_05_R2.fastq.gz
Approx 25% complete for bio_sample_05_R2.fastq.gz
Approx 30% complete for bio_sample_05_R2.fastq.gz
Approx 35% complete for bio_sample_05_R2.fastq.gz
Approx 40% complete for bio_sample_05_R2.fastq.gz
Approx 45% complete for bio_sample_05_R2.fastq.gz
Approx 50% complete for bio_sample_05_R2.fastq.gz
Approx 55% complete for bio_sample_05_R2.fastq.gz
Approx 60% complete for bio_sample_05_R2.fastq.gz
Approx 65% complete for bio_sample_05_R2.fastq.gz
Approx 70% complete for bio_sample_05_R2.fastq.gz
Approx 75% complete for bio_sample_05_R2.fastq.gz
Approx 80% complete for bio_sample_05_R2.fastq.gz
Approx 85% complete for bio_sample_05_R2.fastq.gz
Approx 90% complete for bio_sample_05_R2.fastq.gz
Approx 95% complete for bio_sample_05_R2.fastq.gz
Approx 100% complete for bio_sample_05_R2.fastq.gz
Analysis complete for bio_sample_05_R2.fastq.gz
</pre>
</details>

The log file shows the progress of the FastQC analysis for just the last file.

Let us now make sure that we have a log file for each file. 

```bash
module purge
module load fastqc

INPUT_DIR=01_data
OUTPUT_DIR=04_fastqc_loop_samplename
LOG_DIR=logs

mkdir -p $OUTPUT_DIR $LOG_DIR

for file in $INPUT_DIR/*.fastq.gz 
do  
  sample_id=$(basename "$file" .fastq.gz)
  echo "Running FastQC on: $sample_id"
  fastqc $file -o $OUTPUT_DIR/ > $LOG_DIR/03_fastqc_loop_$sample_id.log 2>&1
done
```

Using shell variables in the loop helps to make the script more readable, maintainable, and reusable.

Save this script as `03_fastqc_loop_samplename.sh` in `00_scripts` directory.

Make it executable:

```bash
chmod +x 00_scripts/03_fastqc_loop_samplename.sh
```

**Run the script:**

```bash
time ./00_scripts/03_fastqc_loop_samplename.sh
```

<details>
<summary>Output</summary>
<pre>
Running FastQC on: bio_sample_01_R1
Running FastQC on: bio_sample_01_R2
Running FastQC on: bio_sample_02_R1
Running FastQC on: bio_sample_02_R2
Running FastQC on: bio_sample_03_R1
Running FastQC on: bio_sample_03_R2
Running FastQC on: bio_sample_04_R1
Running FastQC on: bio_sample_04_R2
Running FastQC on: bio_sample_05_R1
Running FastQC on: bio_sample_05_R2

real    1m11.971s
user    1m31.266s
sys     0m3.074s
</pre>
</details>

Check the log files:

```bash
less logs/*bio_sample*log
```

Using `less` we can view the contents of the log files. To move from one file to the next, use the `:n` command within `less`. To move to the previous file, use the `:p` command.

To check if all files have been processed, we can use the `grep` command.

```bash
grep "Analysis complete" logs/*bio_sample*log
```

<details>
<summary>Output</summary>
<pre>
logs/02_fastqc_loop_bio_sample_01_R1.log:Analysis complete for bio_sample_01_R1.fastq.gz
logs/02_fastqc_loop_bio_sample_01_R2.log:Analysis complete for bio_sample_01_R2.fastq.gz
logs/02_fastqc_loop_bio_sample_02_R1.log:Analysis complete for bio_sample_02_R1.fastq.gz
logs/02_fastqc_loop_bio_sample_02_R2.log:Analysis complete for bio_sample_02_R2.fastq.gz
logs/02_fastqc_loop_bio_sample_03_R1.log:Analysis complete for bio_sample_03_R1.fastq.gz
logs/02_fastqc_loop_bio_sample_03_R2.log:Analysis complete for bio_sample_03_R2.fastq.gz
logs/02_fastqc_loop_bio_sample_04_R1.log:Analysis complete for bio_sample_04_R1.fastq.gz
logs/02_fastqc_loop_bio_sample_04_R2.log:Analysis complete for bio_sample_04_R2.fastq.gz
logs/02_fastqc_loop_bio_sample_05_R1.log:Analysis complete for bio_sample_05_R1.fastq.gz
logs/02_fastqc_loop_bio_sample_05_R2.log:Analysis complete for bio_sample_05_R2.fastq.gz
</pre>
</details>

#### Multiple files (GNU Parallel)

Let us now use GNU Parallel to run the FastQC analysis on all files in parallel.
The first step is go for a dry run to see what commands will be executed.

```bash
module load parallel 
mkdir -p 05_fastqc_parallel
parallel --dry-run -j 10 fastqc {} -o 05_fastqc_parallel/ ::: 01_data/*.fastq.gz
```

- `parallel --dry-run -j 10 fastqc {} -o 05_fastqc_parallel/ ::: 01_data/*.fastq.gz`
  - `--dry-run` prints the commands that would be executed, without running them. Use this to verify first.
  - `-j 10` means run up to 10 jobs at the same time (choose based on cores available to you).
  - `fastqc {}` is the command template; `{}` will be replaced by each input filename.
  - `-o 05_fastqc_parallel/` sends FastQC outputs into that directory.
  - `:::` introduces the list of inputs to feed to GNU Parallel; here the shell expands `01_data/*.fastq.gz` to all matching files.

To actually run the commands (not just show them), remove `--dry-run`:

```bash
module purge
module load parallel
module load fastqc 

mkdir -p 05_fastqc_parallel

parallel -j10 \
  'fastqc {1} -o 05_fastqc_parallel/ > logs/04_fastqc_parallel_{1/.}.log 2>&1' \
  ::: 01_data/*.fastq.gz
```

- The trailing `\` characters are line continuations so the long command is split across multiple lines for readability.
- Quotes `'...'` keep the whole FastQC template as one string so that GNU Parallel, not your shell, substitutes `{1}` and `{1/.}`.
- `{1}` is the first input argument (each file matched by the glob). With a single input source, `{}` and `{1}` are equivalent.
- `{1/.}` is a GNU Parallel filename modifier: it expands to the basename of the first input with the final extension removed (and without the directory). This lets us name per-file logs like `logs/02_fastqc_parallel_bio_sample_01_R1.log`.
- `> logs/02_fastqc_parallel_{1/.}.log 2>&1` writes both stdout and stderr of each FastQC run to a separate log file derived from the input name.

Add the above script to `00_scripts/04_fastqc_parallel.sh`.

Make it executable:

```bash
chmod +x 00_scripts/04_fastqc_parallel.sh
```

**Run the script**

```bash
time ./00_scripts/04_fastqc_parallel.sh
```

<details>
<summary>Output</summary>
<pre>
real    0m26.453s
user    2m1.143s
sys     0m3.962s
</pre>
</details>

- **Why `user` > `real` here**
  - Because we ran multiple tasks concurrently (e.g., via loops or GNU Parallel), CPU time across cores adds up. If 8 cores each do ~15 seconds of work, `user` could be ~120 seconds while `real` is ~15–30 seconds.

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
OUTPUT_DIR="06_fastqc_parallel_improved"

# Log directory
LOG_DIR="logs"

# Create required directories
mkdir -p "$OUTPUT_DIR" "$LOG_DIR"

# make them visible to subshells that parallel spawns
export OUTPUT_DIR LOG_DIR INPUT_DIR

# Load required modules
module load parallel
module load fastqc

# Run FastQC
parallel -j10 \
  'fastqc "{1}" -o "$OUTPUT_DIR/" > "$LOG_DIR/05_fastqc_parallel_improved_{1/.}.log" 2>&1' \
  ::: $INPUT_DIR/*.fastq.gz
```

Add the above script to `00_scripts/05_fastqc_parallel_improved.sh`.

Make it executable:

```bash
chmod +x 00_scripts/05_fastqc_parallel_improved.sh
```

Run the script:

```bash
time ./00_scripts/05_fastqc_parallel_improved.sh
```

<details>
<summary>Output</summary>
<pre>
real    0m30.624s
user    2m53.930s
sys     0m6.853s
</pre>
</details>
