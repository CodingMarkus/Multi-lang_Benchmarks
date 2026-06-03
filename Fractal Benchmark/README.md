Fractal Benchmark
=================

## What this benchmark does

This benchmark renders an ASCII Mandelbrot set repeatedly. For each
iteration it walks a fixed 78 by 78 grid of complex-plane sample points,
computes the Mandelbrot escape iteration count for each point, and
writes either `*` or a space depending on whether the point stays in the
set.

The benchmark therefore mainly measures floating-point arithmetic,
tightly nested loops, branch-heavy escape checks, and repeated text
output while keeping the rendered image identical across languages.

## Benchmark system

- Apple M1 Pro (`arm64`)
- 10 CPU cores

Use `./run.sh` for benchmark-only timings reported by each implementation. Use `./timed_run.sh` to pre-build compiled implementations and then measure only the benchmark command with `/usr/bin/time`; on supported platforms it also reports peak RSS.

## Results

| Language | Time (s) | Total Time (s) | Start Time (s) | Max RSS (MiB) |
| --- | ---: | ---: | ---: | ---: |
| C | 0.540 | 0.54 | 0.000 | 2.125 |
| Rust | 0.330 | 0.33 | 0.000 | 2.125 |
| Swift | 0.350 | 0.35 | 0.000 | 3.203 |
| Go | 0.460 | 0.46 | 0.000 | 3.953 |
| Java | 0.340 | 0.34 | 0.000 | 63.578 |
| C# | 0.530 | 0.53 | 0.000 | 17.859 |
| JavaScript (Node.js) | 0.300 | 0.30 | 0.000 | 52.250 |
| Interpreted Java | 2.500 | 2.50 | 0.000 | 38.859 |
| Interpreted JavaScript (Node.js) | 2.840 | 2.84 | 0.000 | 46.562 |
| JavaScript (QuickJS) | 3.850 | 3.85 | 0.000 | 2.469 |
| Python | 8.110 | 8.11 | 0.000 | 8.938 |
| Ruby | 5.790 | 5.79 | 0.000 | 25.281 |
| PHP | 2.500 | 2.50 | 0.000 | 8.438 |
| Perl | 9.100 | 9.10 | 0.000 | 4.469 |
| Lua | 1.790 | 1.79 | 0.000 | 1.969 |

![Benchmark results time](assets/results-time.png)

![Benchmark results memory](assets/results-memory.png)
