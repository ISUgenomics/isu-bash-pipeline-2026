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

#### One file

```bash
module purge
module load fastp
mkdir -p 02_fastp
fastp \
  -i 01_data/bio_sample_01_R1.fastq.gz \
  -o 02_fastp/bio_sample_01_R1.trimmed.fastq.gz \
  -h 02_fastp/bio_sample_01_R1.html \
  -j 02_fastp/bio_sample_01_R1.json
```
- `mkdir -p` creates the directory if it does not exist (and does not complain if it already does).
- `-i` is the input FASTQ file and `-o` is the output (quality filtered and adapter trimmed) FASTQ file.
- `-h` writes the HTML quality report and `-j` writes the JSON report.

Once the program is run, it will create a directory called `02_fastp` and put the output files in it.

```bash
ls 02_fastp
```

<details>
<summary>Output</summary>
<pre>
bio_sample_01_R1.html  bio_sample_01_R1.json  bio_sample_01_R1.trimmed.fastq.gz
</pre>
</details>

Remove the folder created so we can repeat the run from a script:

```bash
rm -r 02_fastp
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
mkdir -p 02_fastp logs
fastp \
  -i 01_data/bio_sample_01_R1.fastq.gz \
  -o 02_fastp/bio_sample_01_R1.trimmed.fastq.gz \
  -h 02_fastp/bio_sample_01_R1.html \
  -j 02_fastp/bio_sample_01_R1.json \
  > logs/01_fastp.log 2>&1
```

- Explanation of the command in the script:
  - `fastp -i ... -o ... -h ... -j ...` runs fastp on the input file and writes the trimmed reads and the HTML/JSON reports to the `02_fastp/` directory.
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

**Run `fastp` on all files in `01_data/`**

```bash
#!/usr/bin/env bash

module purge
module load fastp

mkdir -p 03_fastp_loop logs

for file in 01_data/*.fastq.gz
do
  sample_id=$(basename "$file" .fastq.gz)
  echo "Running fastp on: $sample_id"
  fastp \
    -i "$file" \
    -o "03_fastp_loop/${sample_id}.trimmed.fastq.gz" \
    -h "03_fastp_loop/${sample_id}.html" \
    -j "03_fastp_loop/${sample_id}.json" \
    > logs/02_fastp_loop.log 2>&1
done
```

- `basename "$file" .fastq.gz` strips the directory and the `.fastq.gz` suffix, giving e.g. `bio_sample_01_R1`. We need this because fastp does not name its reports after the input: without unique `-h`/`-j` names every file would overwrite the same `fastp.html`/`fastp.json`.

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
Running fastp on: bio_sample_01_R1
Running fastp on: bio_sample_01_R2
Running fastp on: bio_sample_02_R1
Running fastp on: bio_sample_02_R2
Running fastp on: bio_sample_03_R1
Running fastp on: bio_sample_03_R2
Running fastp on: bio_sample_04_R1
Running fastp on: bio_sample_04_R2
Running fastp on: bio_sample_05_R1
Running fastp on: bio_sample_05_R2

real    TODO
user    TODO
sys     TODO
</pre>
</details>

Check the log file:

```bash
cat logs/02_fastp_loop.log
```

The log file only contains the fastp summary (read counts before/after filtering, adapter trimming, duplication rate) for the last file, because each iteration overwrites the log with `>`.

Let us now make sure that we have a log file for each file.

```bash
#!/usr/bin/env bash

module purge
module load fastp

INPUT_DIR="01_data"
OUTPUT_DIR="04_fastp_loop_samplename"
LOG_DIR="logs"

mkdir -p "$OUTPUT_DIR" "$LOG_DIR"

for file in "$INPUT_DIR"/*.fastq.gz
do
  sample_id=$(basename "$file" .fastq.gz)
  echo "Running fastp on: $sample_id"
  fastp \
    -i "$file" \
    -o "$OUTPUT_DIR/${sample_id}.trimmed.fastq.gz" \
    -h "$OUTPUT_DIR/${sample_id}.html" \
    -j "$OUTPUT_DIR/${sample_id}.json" \
    > "$LOG_DIR/03_fastp_loop_${sample_id}.log" 2>&1
done
```

Using shell variables in the loop (and quoting them, `"$file"`, so names with spaces do not break the command) helps to make the script more readable, maintainable, and reusable.

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
Running fastp on: bio_sample_01_R1
Running fastp on: bio_sample_01_R2
Running fastp on: bio_sample_02_R1
Running fastp on: bio_sample_02_R2
Running fastp on: bio_sample_03_R1
Running fastp on: bio_sample_03_R2
Running fastp on: bio_sample_04_R1
Running fastp on: bio_sample_04_R2
Running fastp on: bio_sample_05_R1
Running fastp on: bio_sample_05_R2

real    TODO
user    TODO
sys     TODO
</pre>
</details>

Check the log files:

```bash
less logs/03_fastp_loop_bio_sample*log
```

Using `less` we can view the contents of the log files. To move from one file to the next, use the `:n` command within `less`. To move to the previous file, use the `:p` command.

To check if all files have been processed, we can use the `grep` command. fastp prints a final line with the run time when it finishes successfully.

```bash
grep "time used" logs/03_fastp_loop_bio_sample*log
```

<details>
<summary>Output</summary>
<pre>
logs/03_fastp_loop_bio_sample_01_R1.log:fastp v&lt;version&gt;, time used: &lt;N&gt; seconds
...
(one line per sample file; TODO: paste real output)
</pre>
</details>

#### Multiple files (GNU Parallel)

Let us now use GNU Parallel to run fastp on all files in parallel.
The first step is go for a dry run to see what commands will be executed.

```bash
module load parallel
mkdir -p 05_fastp_parallel
parallel --dry-run -j 10 'fastp -i {} -o 05_fastp_parallel/{/..}.trimmed.fastq.gz -h 05_fastp_parallel/{/..}.html -j 05_fastp_parallel/{/..}.json -w 1' ::: 01_data/*.fastq.gz
```

- `--dry-run` prints the commands that would be executed, without running them. Use this to verify first.
- `-j 10` means run up to 10 jobs at the same time (choose based on cores available to you).
- The quoted string is the command template; `{}` will be replaced by each input filename.
- `{/..}` is a GNU Parallel modifier: it removes the directory and two extensions, so `01_data/bio_sample_01_R1.fastq.gz` becomes `bio_sample_01_R1`.
- `-w 1` tells fastp to use one worker thread per job (the default is 3), so 10 parallel jobs do not oversubscribe the cores.
- `:::` introduces the list of inputs to feed to GNU Parallel; here the shell expands `01_data/*.fastq.gz` to all matching files.

To actually run the commands (not just show them), remove `--dry-run`:

```bash
#!/usr/bin/env bash

module purge
module load parallel
module load fastp

mkdir -p 05_fastp_parallel logs

parallel -j10 \
  'fastp -i {1} -o 05_fastp_parallel/{1/..}.trimmed.fastq.gz -h 05_fastp_parallel/{1/..}.html -j 05_fastp_parallel/{1/..}.json -w 1 > logs/04_fastp_parallel_{1/..}.log 2>&1' \
  ::: 01_data/*.fastq.gz
```

- The trailing `\` characters are line continuations so the long command is split across multiple lines for readability.
- Quotes `'...'` keep the whole fastp template as one string so that GNU Parallel, not your shell, substitutes `{1}` and `{1/..}`.
- `{1}` is the first input argument (each file matched by the glob). With a single input source, `{}` and `{1}` are equivalent.
- `{1/..}` expands to the basename of the first input with the directory and both extensions (`.fastq.gz`) removed. This lets us name per-file outputs and logs like `logs/04_fastp_parallel_bio_sample_01_R1.log`.
- `> logs/04_fastp_parallel_{1/..}.log 2>&1` writes both stdout and stderr of each fastp run to a separate log file derived from the input name.

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
real    TODO
user    TODO
sys     TODO
</pre>
</details>

- **Why `user` > `real` here**
  - CPU time across cores adds up. fastp is itself multi-threaded, so `user` was already slightly above `real` for the single-file run. With GNU Parallel running many jobs at once, the gap grows. If 8 cores each do ~15 seconds of work, `user` could be ~120 seconds while `real` is ~15–30 seconds.

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
OUTPUT_DIR="06_fastp_parallel_improved"

# Log directory
LOG_DIR="logs"

# Create required directories
mkdir -p "$OUTPUT_DIR" "$LOG_DIR"

# make them visible to subshells that parallel spawns
export OUTPUT_DIR LOG_DIR INPUT_DIR

# Load required modules
module load parallel
module load fastp

# Run fastp
parallel -j10 \
  'fastp -i "{1}" \
     -o "$OUTPUT_DIR/{1/..}.trimmed.fastq.gz" \
     -h "$OUTPUT_DIR/{1/..}.html" \
     -j "$OUTPUT_DIR/{1/..}.json" \
     -w 1 > "$LOG_DIR/05_fastp_parallel_improved_{1/..}.log" 2>&1' \
  ::: "$INPUT_DIR"/*.fastq.gz
```

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
real    TODO
user    TODO
sys     TODO
</pre>
</details>
