String Benchmark
================

## What this benchmark does

This benchmark generates a deterministic source text of a bit more than 1 MiB by concatenating pseudo-randomly selected UTF-8 or UTF-16 words from a fixed word list. It then measures how fast each implementation can:

- split the source text into words,
- re-wrap those words into lines below 80 characters, and
- hash the resulting wrapped text to verify the output stays correct.

The workload is repeated for the configured iteration count. The
benchmark therefore mainly measures string splitting, concatenation,
line-wrapping logic, and result verification on a large in-memory text.

## String-specific variants

- **C (UTF-16):** Alternative C implementation using fixed-width UTF-16 code units instead of UTF-8 bytes.
- **Rust (UTF-16):** Alternative Rust implementation working on UTF-16 code units rather than byte-oriented string handling.

## Benchmark system

- Apple M1 Pro (`arm64`)
- 10 CPU cores

Use `./run.sh` for benchmark-only timings reported by each implementation. Use `./timed_run.sh` to pre-build compiled implementations and then measure only the benchmark command with `/usr/bin/time`; on supported platforms it also reports peak RSS.

## Results

| Language | Time (s) | Total Time (s) | Start Time (s) | Max RSS (MiB) |
| --- | ---: | ---: | ---: | ---: |
| C | 0.116 | 0.25 | 0.000 | 13.906 |
| C UTF-16 | 0.125 | 0.28 | 0.000 | 27.922 |
| Rust | 0.155 | 0.32 | 0.000 | 22.297 |
| Rust UTF-16 | 0.120 | 0.29 | 0.000 | 9.172 |
| Swift | 2.376 | 2.55 | 0.000 | 35.406 |
| Objective-C | 1.989 | 2.17 | 0.000 | 33.391 |
| Go | 0.172 | 0.35 | 0.000 | 14.641 |
| Java | 0.264 | 0.31 | 0.000 | 413.328 |
| C# | 0.412 | 0.42 | 0.000 | 50.484 |
| Node.js JavaScript | 3.956 | 4.05 | 0.000 | 212.188 |
| Bun JavaScript | 4.294 | 4.40 | 0.000 | 178.625 |
| Bun (compiled) JavaScript | 4.302 | 4.95 | 0.000 | 166.922 |
| Interpreted Java | 14.104 | 14.32 | 0.000 | 397.719 |
| Node.js (Interpreted) JavaScript | 17.149 | 17.33 | 0.000 | 268.797 |
| QuickJS JavaScript | 18.345 | 18.80 | 0.000 | 67.031 |
| Python | 5.336 | 5.55 | 0.000 | 56.344 |
| Ruby | 7.124 | 7.27 | 0.000 | 81.938 |
| PHP | 6.762 | 6.90 | 0.000 | 34.172 |
| Perl | 20.548 | 21.11 | 0.000 | 40.484 |
| Lua | 7.017 | 7.14 | 0.000 | 91.016 |

![Benchmark results time](assets/results-time.png)

![Benchmark results memory](assets/results-memory.png)
