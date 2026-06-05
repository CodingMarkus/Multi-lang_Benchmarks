const BAILOUT = 16;
const MAX_ITERATIONS = 1000;

function iterate(x, y)
{
	var cr = y - 0.5;
	var ci = x;
	var zi = 0.0;
	var zr = 0.0;
	var i = 0;

	while (1) {
		i++;
		var temp = zr * zi;
		var zr2 = zr * zr;
		var zi2 = zi * zi;
		zr = zr2 - zi2 + cr;
		zi = temp + temp + ci;
		if (zi2 + zr2 > BAILOUT) return i;
		if (i > MAX_ITERATIONS) return 0;
	}
}

function mandelbrot(runs)
{
	for (var i = 0; i < runs; i++) {
		for (var y = -39; y < 39; y++) {
			var line = "";
			for (var x = -39; x < 39; x++) {
				if (iterate(x / 40.0, y / 40.0) == 0) {
					line += "*";
				} else {
					line += " ";
				}
			}
			print(line);
		}
		print("");
	}
}

const args = scriptArgs.slice(1);
const runs = args.length > 0 ? parseInt(args[0], 10) : 1;

var start = Date.now();
mandelbrot(runs);
var elapsed = (Date.now() - start) / 1000;
var elapsedLine =
	"JavaScript (QuickJS) Elapsed " + elapsed.toFixed(3) + " seconds";

if (typeof std !== "undefined" && std.err && std.err.puts) {
	std.err.puts(elapsedLine + "\n");
} else {
	print(elapsedLine);
}
