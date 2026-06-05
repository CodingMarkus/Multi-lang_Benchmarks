<?php

define("BAILOUT", 16);
define("MAX_ITERATIONS", 1000);

function iterate($x,$y) {
	$cr = $y-0.5;
	$ci = $x;
	$zi = 0.0;
	$zr = 0.0;
	$i = 0;
	while (true) {
		$i++;
		$temp = $zr * $zi;
		$zr2 = $zr * $zr;
		$zi2 = $zi * $zi;
		$zr = $zr2 - $zi2 + $cr;
		$zi = $temp + $temp + $ci;
		if ($zi2 + $zr2 > BAILOUT) return $i;
		if ($i > MAX_ITERATIONS) return 0;
	}

}

function mandelbrot($runs)
{
	for ($i = 0; $i < $runs; $i++) {
		for ($y = -39; $y < 39; $y++) {
			echo("\n");
			for ($x = -39; $x < 39; $x++) {
				if (iterate($x / 40.0,$y / 40.0) == 0)
					echo("*");
				else
					echo(" ");

			}
		}
		echo("\n");
	}
}

$d1 = microtime(1);
$runs = 1;
if ($argc > 1) {
	$runs = $argv[1];
}
mandelbrot($runs);
$diff = microtime(1) - $d1;
fprintf(STDERR, "PHP Elapsed %0.3f\n", $diff);
?>
