# Introduction to Pipeline Development

Build your first pipeline in bash: from one command to a script, then to a multi-step pipeline that runs in parallel and on Slurm.

**Date and time:** Tuesday, November 10, 2026, 1:00 PM - 5:00 PM

## What you will learn

- Convert commands into reusable Bash scripts
- Use variables, loops, paths, and naming conventions
- Organize inputs, outputs, scripts, and log files
- Build reproducible multi-step pipelines
- Add error handling and logging
- Parallelize independent tasks with GNU Parallel
- Integrate scripts and pipelines with Slurm
- Match pipeline concurrency to requested HPC resources

## Instructor

Viswanathan Satheesh  
Bioinformatics Facility, Office of Biotechnology  
Iowa State University, Ames, IA

**Contact:** bioinformatics@iastate.edu | satheesh@iastate.edu

## Prerequisites

- A Nova account with access to OnDemand (or ssh) and a terminal.
- Basic command-line familiarity (`ls`, `cd`, `pwd`) and understanding of variables and loops.

## Getting started

Follow `01_setup.md`. It takes you from logging in to Nova OnDemand to a project folder with the data and the tools ready.

## What is in this repository

| File or folder | What it is |
|---|---|
| `01_setup.md` | Log in, get a session, clone this repository, copy the data, check the tools |
| `02_building_first_script.md` | Lesson 1: fastp, loops and GNU Parallel |
| `03_alignment_bwa.md` | Lesson 2: align reads with bwa and samtools |
| `04_pipeline_combined.md` | Lesson 3: one pipeline for all samples, GNU Parallel, Slurm batch job and job array |
| `exercises.md` | One short exercise per lesson |
| `cheatsheet.md` | The commands used in the workshop on one page |
| `00_scripts/` | A copy of every script from the lessons (`01_fastp.sh` to `12_pipeline_array.sh`) |
| `assets/` | Screenshots used in the setup |

## Run everything from the project folder

All scripts use relative paths (`01_data/`, `00_scripts/`, `logs/`), so run them from the project folder (`/work/short_term/$USER`, the folder that has `01_data/` and `02_reference/`), not from inside `00_scripts/` and not from inside the cloned `isu-bash-pipeline-2026` folder. See `01_setup.md`.

## License

MIT License. See `LICENSE`.
