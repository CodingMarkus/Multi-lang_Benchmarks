const BAILOUT = 16;
const MAX_ITERATIONS = 1000;

function iterate(x: number, y: number): number
{
	const cr = y - 0.5;
	const ci = x;
	let zi = 0.0;
	let zr = 0.0;
	let i = 0;

	while (true) {
		i++;
		const temp = zr * zi;
		const zr2 = zr * zr;
		const zi2 = zi * zi;
		zr = zr2 - zi2 + cr;
		zi = temp + temp + ci;
		if (zi2 + zr2 > BAILOUT) return i;
		if (i > MAX_ITERATIONS) return 0;
	}
}

function mandelbrot(runs: number): void
{
	for (let i = 0; i < runs; i++) {
		for (let y = -39; y < 39; y++) {
			process.stdout.write("\n");
			for (let x = -39; x < 39; x++) {
				process.stdout.write(
					iterate(x / 40.0, y / 40.0) === 0 ? "*" : " "
				);
			}
		}
		process.stdout.write("\n");
	}
}

const args = process.argv.slice(2);
const runs = args.length > 0 ? parseInt(args[0], 10) : 1;
const start = Date.now();
mandelbrot(runs);
const elapsed = (Date.now() - start) / 1000;
process.stderr.write("JavaScript: " + elapsed.toFixed(3) + " s\n");
