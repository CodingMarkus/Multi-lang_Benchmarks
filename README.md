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

Objective-C and C++ are only benchmarked when they can use their standard libraries at a meaningfully higher level than plain C. Both can of course also fall back to the same C implementation style when that is better for performance, so these benchmarks are not mainly about absolute performance. They are included to show how much higher-level objects and abstractions can slow things down compared to a C-style baseline.

Kotlin and TypeScript are not benchmarked separately because the same results as Java and JavaScript are expected in these cases.
