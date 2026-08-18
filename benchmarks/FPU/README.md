FPU
===

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

Use `../../run -b fpu` to measure this benchmark. It pre-builds compiled
implementations and measures each benchmark command with `/usr/bin/time`.

## Results

| Language | Total (s) | Benchmark (s) | Binary (KiB) | Memory (MiB) |
| --- | ---: | ---: | ---: | ---: |
| C | 0.410 | 0.184 | 33 | 1.110 |
| Rust | 0.310 | 0.167 | 461 | 1.235 |
| Swift | 0.340 | 0.203 | 57 | 2.516 |
| Go | 0.430 | 0.269 | 2452 | 3.672 |
| ScriptC TS | 0.370 | 0.227 | 390 | 1.188 |
| Bun Compiled JS | 0.840 | 0.239 | 61960 | 36.750 |
| Java | 0.320 | 0.272 | n/a | 61.985 |
| C# | 0.520 | 0.508 | n/a | 17.235 |
| Node.js | 0.290 | 0.262 | n/a | 52.188 |
| Bun JS | 0.230 | 0.220 | n/a | 39.266 |
| ScriptC Compiled TS | 1.420 | 0.011 | n/a | 295.391 |
| QuickJS | 4.020 | 4.018 | n/a | 2.250 |
| Interpreted Java | 2.510 | 2.467 | n/a | 40.344 |
| Interpreted Node.js | 2.870 | 2.837 | n/a | 46.750 |
| Python | 8.130 | 8.102 | n/a | 8.344 |
| Ruby | 5.690 | 5.640 | n/a | 24.172 |
| PHP | 2.500 | 2.496 | n/a | 8.438 |
| Perl | 9.040 | 9.033 | n/a | 4.235 |
| Lua | 1.810 | 1.807 | n/a | 1.500 |

![Benchmark time](assets/results-time.svg)

![Peak RSS](assets/results-memory.svg)

![Binary size](assets/results-binary-size.svg)
