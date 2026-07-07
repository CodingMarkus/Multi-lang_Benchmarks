Multi-lang Benchmarks
=====================

Compare performance of multiple popular languages across different tasks.


Benchmarks
----------

- [String Benchmark](./String%20Benchmark/README.md)
- [Fractal Benchmark](./Fractal%20Benchmark/README.md)
- [Integer Benchmark](./Integer%20Benchmark/README.md)


Tested Languages
----------------

- **C:** Native optimized baseline implementation compiled with `clang -O3`.
- **Rust:** Native optimized Rust implementation compiled with `rustc -C opt-level=3`.
- **Swift:** Native optimized Swift implementation run with `swift -O`.
- **Objective-C:** Objective-C implementation built against Foundation, only included where that higher-level runtime is expected to matter.
- **Go:** Native compiled Go implementation built with `go build`.
- **Java:** Normal JVM execution with JIT compilation enabled.
- **Java (interpreted):** JVM execution forced into interpreter mode with `java -Xint`, disabling JIT compilation.
- **C#:** C# implementation compiled with `mcs` and run on Mono with optimizations enabled.
- **Node.js JavaScript:** Standard Node.js execution with the normal V8 JIT pipeline enabled.
- **Node.js (Interpreted) JavaScript:** Node.js run with `--jitless`, disabling the V8 JIT so execution stays in non-JIT mode.
- **QuickJS JavaScript:** JavaScript executed with QuickJS instead of Node.js and V8.
- **Python:** CPython execution using `python` or `python3`, depending on what is available.
- **Ruby:** Standard Ruby interpreter execution.
- **PHP:** Standard PHP CLI interpreter execution.
- **Perl:** Standard Perl interpreter execution.
- **Lua:** Standard Lua interpreter execution.

Objective-C and C++ are only benchmarked when they can use their standard libraries at a meaningfully higher level than plain C. Both can of course also fall back to the same C implementation style when that is better for performance, so these benchmarks are not mainly about absolute performance. They are included to show how much higher-level objects and abstractions can slow things down compared to a C-style baseline.

Kotlin and TypeScript are not benchmarked separately because the same results as Java and JavaScript are expected in these cases.


Chart Style
-----------

Benchmark result charts should use one shared visual style across all benchmark folders so regenerated assets stay comparable over time.

- Use horizontal bar charts on a white background.
- Use a chart width of 1280 px.
- Use Arial for labels and axis text, and Arial Bold for titles and value labels.
- Use a 24 px title font size.
- Use a 16 px font size for axis text and numeric value labels.
- Use an 18 px font size for language labels on the y-axis.
- Use a left chart margin of 300 px, a right margin of 40 px, a top plot margin of 60 px, and a bottom margin of 84 px.
- The left chart margin includes the y-axis labels. The plotted bars should start at the right edge of that margin.
- If a y-axis label does not fit into the left chart margin at the default font size, reduce that label's font size until it fits, down to a minimum of 13 px.
- Use a row height of 48 px and a bar height of 26 px.
- Center the title horizontally near the top with the benchmark name followed by either `(Elapsed Time in Seconds)` or `(Peak RSS in MiB)`.
- Draw a solid left and bottom axis line in a medium gray.
- Draw vertical grid lines in a light gray dashed style.
- Place language labels to the left of the bars and numeric value labels just to the right of the bar ends.
- Format displayed benchmark values with three decimal places.
- Label the x-axis as `Elapsed Time (seconds)` for time charts and `Memory Consumption (MiB)` for memory charts.
- Keep one bar per benchmarked language in README table order.
- Use the same repeating color palette for every benchmark chart.
