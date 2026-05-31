# Multi-lang Benchmarks

Compare performance of multiple popular languages across different tasks.

## Benchmarks

- [String Benchmark](./String%20Benchmark/README.md)
- [Fractal Benchmark](./Fractal%20Benchmark/README.md)


## Tested Languages

- **C:** Native optimized baseline implementation compiled with
  `clang -O3`.
- **Rust:** Native optimized Rust implementation compiled with
  `rustc -C opt-level=3`.
- **Swift:** Native optimized Swift implementation run with `swift -O`.
- **Objective-C:** Objective-C implementation built against Foundation,
  only included where that higher-level runtime is expected to matter.
- **Go:** Native compiled Go implementation built with `go build`.
- **Java:** Normal JVM execution with JIT compilation enabled.
- **Java (interpreted):** JVM execution forced into interpreter mode
  with `java -Xint`, disabling JIT compilation.
- **C#:** C# implementation compiled with `mcs` and run on Mono with
  optimizations enabled.
- **JavaScript (Node.js):** Standard Node.js execution with the normal
  V8 JIT pipeline enabled.
- **JavaScript (Node.js, interpreted):** Node.js run with `--jitless`,
  disabling the V8 JIT so execution stays in non-JIT mode.
- **JavaScript (QuickJS):** JavaScript executed with QuickJS instead of
  Node.js and V8.
- **Python:** CPython execution using `python` or `python3`, depending
  on what is available.
- **Ruby:** Standard Ruby interpreter execution.
- **PHP:** Standard PHP CLI interpreter execution.
- **Perl:** Standard Perl interpreter execution.
- **Lua:** Standard Lua interpreter execution.

Objective-C and C++ are only benchmarked when a meaningful difference
from the C implementation is expected. If both would mainly exercise the
same underlying C-style implementation, benchmarking them separately
does not add much value.

Kotlin and TypeScript are not benchmarked separately because the same
results as Java and JavaScript are expected in these cases.
