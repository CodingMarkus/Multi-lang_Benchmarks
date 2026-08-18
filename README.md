Multi-lang Benchmarks
=====================

Compare performance of multiple popular languages across different tasks.

The original and actively developed project is hosted on [Codeberg](https://codeberg.org/CodingMarkus/MultiLang-Benchmarks). \
Additionally this project is also mirrored on [GitHub](https://github.com/CodingMarkus/MultiLang-Benchmarks).


Benchmarks
----------

- [String](./benchmarks/String/README.md)
- [FPU](./benchmarks/FPU/README.md)
- [Integer](./benchmarks/Integer/README.md)

Run `./run` to measure every benchmark in every available language. Use
`-b` or `--bench` to select benchmarks, and `-l` or `--lang` to select
languages. A selected language that a benchmark does not offer is skipped.

Use `./util/update-benchmarks.sh` after measuring results to refresh each
benchmark table and its SVG charts. It only accepts benchmark selection and
always runs every language available for each selected benchmark.


Tested Languages
----------------

### Compiled languages

- **C (`c`):** C compiled with `clang -O3`.
- **C UTF-16 (`c16`):** C UTF-16 variant using fixed-width UTF-16 code units.
- **Rust (`rust`):** Rust compiled with `rustc -C opt-level=3`.
- **Rust UTF-16 (`rust16`):** Rust UTF-16 variant using UTF-16 code units.
- **Swift (`swift`):** Swift compiled with `swiftc -O`.
- **Objective-C (`objc`):** Objective-C compiled with `-Os`.
- **Go (`go`):** Go compiled with `go build`.
- **ScriptC TypeScript executable (`scriptcc`):** TypeScript compiled to a native executable with ScriptC.
- **Bun executable (`bunc`):** JavaScript compiled to a standalone Bun executable.

### VM languages

- **Java (`java`):** Java running with the normal JVM JIT enabled.
- **C# (`cs`):** C# compiled with `mcs` and run on Mono with optimizations.

### TypeScript/JavaScript Engines

- **Node.js (`node`):** Node.js running with the V8 JIT enabled.
- **Bun (`bun`):** JavaScript running on the Bun runtime.
- **ScriptC TypeScript (`scriptc`):** TypeScript run with ScriptC.
- **QuickJS (`qjs`):** QuickJS JavaScript interpreter.

### Interpreted VM languages

- **Java interpreted (`javai`):** Java running with `-Xint`, disabling the JVM JIT.
- **Node.js interpreted (`nodei`):** Node.js running with `--jitless`, disabling V8 JIT.

### Script languages

- **Python (`py`):** Python running on CPython, using `python` or `python3`.
- **Ruby (`ruby`):** Ruby running on the standard Ruby interpreter.
- **PHP (`php`):** PHP running on the standard PHP CLI interpreter.
- **Perl (`perl`):** Perl running on the standard Perl interpreter.
- **Lua (`lua`):** Lua running on the standard Lua interpreter.

`Objective-C` and `C++` are only benchmarked when they can use their standard libraries at a meaningfully higher level than plain C. Both can of course also fall back to the same C implementation style when that is better for performance, so these benchmarks are not mainly about absolute performance. They are included to show how higher-level objects and abstractions can slow things down compared to a C-style baseline or maybe even speed them up due to better optimized implementation.

`C UTF-16` and `Rust UTF-16` are only tested for benchmarks that deal with strings that might be Unicode and where this probably has an impact on performance or memory usage.

TypeScript is only benchmarked because ScriptC can only compile TS; Bun can also compile and directly run TS yet there is no measurable difference to Bun compiling and running the JS implementation (JS is a strict subset of TS).

Kotlin is not benchmarked separately because the same results as for Java are expected.


Chart Style
-----------

Benchmark result charts should use one shared visual style across all benchmark folders so regenerated assets stay comparable over time.

- Use horizontal bar charts with a transparent background.
- Generate each chart as a MarkShup image bundle named `<name>.img` that contains `light.svg` and `dark.svg` variants.
- Use dark-mode colors for text, axes, grid lines, and bars in `dark.svg`.
- Use a chart width of 1280 px.
- Use Arial for labels and axis text, and Arial Bold for titles and value labels.
- Use a 24 px title font size.
- Use a 16 px font size for axis text and numeric value labels.
- Use an 18 px font size for language labels on the y-axis.
- Use a left chart margin of 300 px, a right margin of 40 px, a top plot margin of 60 px, and a bottom margin of 84 px.
- The left chart margin includes the y-axis labels. The plotted bars should start at the right edge of that margin.
- If a y-axis label does not fit into the left chart margin at the default font size, reduce that label's font size until it fits, down to a minimum of 13 px.
- Use a row height of 48 px and a bar height of 26 px.
- Center the title horizontally near the top with the benchmark name followed by the displayed metric and unit.
- Draw a solid left and bottom axis line in a medium gray.
- Draw vertical grid lines in a light gray dashed style.
- Place language labels to the left of the bars and numeric value labels just to the right of the bar ends.
- Format displayed benchmark values with three decimal places.
- Label the x-axis with the displayed metric and unit.
- Keep one bar per benchmarked language in README table order


My other projects
------------------

See my [other projects](https://CodingMarkus.codeberg.page/).
