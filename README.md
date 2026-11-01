# isu-bash-pipeline-2026
Introduction to pipeline development in bash

## Instructor 
Viswanathan Satheesh

## Agenda (4 hours)

| Time | Block | Material |
|---|---|---|
| 0:00 | Setup and orientation | `00_setup.md` |
| 0:20 | From one command to a script, loops and GNU Parallel | `building_first_script.md` |
| 1:35 | Break | |
| 1:45 | Trimming pairs and aligning reads | `alignment_bwa_mem2.md` (Step 4, GNU Parallel alignment, is optional) |
| 2:45 | Break | |
| 2:55 | A restartable per-sample pipeline | `pipeline_combined.md` |
| 3:25 | Scaling out with a Slurm job array | `pipeline_combined.md` (Slurm section) |
| 3:50 | Wrap-up and questions | |

Timings are a draft and need to be confirmed after a test run on Nova.

## Prerequisites

- A Nova account with access to OnDemand (or ssh) and a terminal.
- Basic command-line use (`ls`, `cd`, `pwd`). Variables and loops are taught in the first lesson.

## Run everything from the project root

All scripts use relative paths (`01_data/`, `00_scripts/`, `logs/`), so run them from the top-level project directory, not from inside `00_scripts/`.
