const BAILOUT = 16;
const MAX_ITERATIONS = 1000;

function iterate ( x, y )
{
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

function mandelbrot ( runs )
{
	for (var i = 0; i < runs; i++) {
		for (var y = -39; y < 39; y++) {
			document.write("\n");
			for (var x = -39; x < 39; x++) {
				if (iterate(x / 40.0, y / 40.0) == 0) {
					document.write("*");
                } else {
					document.write(" ");
                }
			}
		}
		document.write("\n");
	}
}

function getRuns()
{
	var params = new URLSearchParams(window.location.search);
	var runs = parseInt(params.get("runs"), 10);

	if (!Number.isFinite(runs) || runs < 1) {
		return 1;
	}
	return runs;
}

var runs = getRuns();
var date = new Date();
mandelbrot(runs);
var date2 = new Date();
document.write("\nJavaScript Elapsed " +
	(date2.getTime() - date.getTime()) / 1000);
