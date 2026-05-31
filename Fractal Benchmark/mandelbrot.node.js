const BAILOUT = 16;
const MAX_ITERATIONS = 1000;

function iterate(x, y) {
	var cr = y - 0.5;
	var ci = x;
	var zi = 0.0;
	var zr = 0.0;
	var i = 0;

	while(1) {
		i++;
		var temp = zr * zi;
		var zr2 = zr * zr;
		var zi2 = zi * zi;
		zr = zr2 - zi2 + cr;
		zi = temp + temp + ci;
		if (zi2 + zr2 > BAILOUT) return i;
		if (i > MAX_ITERATIONS)	return 0;
	}

}

function mandelbrot(runs)
{
	for (var i = 0; i < runs; i++) {
		for (var y = -39; y < 39; y++) {
			process.stdout.write("\n");
			for (var x = -39; x < 39; x++) {
				if (iterate(x / 40.0, y / 40.0) == 0) {
					process.stdout.write("*");
                } else {
					process.stdout.write(" ");
                }
			}
		}
		process.stdout.write("\n");
	}
}

const args = process.argv.slice(2);
const runs = args.length > 0 ? parseInt(args[0]) : 1;

var start = process.hrtime();
mandelbrot(runs);
var diff = process.hrtime(start);
var elapsed = diff[0] + diff[1] / 1e9;
process.stderr.write(
	"JavaScript (Node.js) Elapsed " + elapsed.toFixed(6) + " seconds\n"
);
