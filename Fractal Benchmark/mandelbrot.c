#include <stdio.h>
#include <sys/time.h>

// Escape radius squared used to stop points that diverge quickly.
#define BAILOUT 16

// Upper bound for points treated as part of the set.
#define MAX_ITERATIONS 1000


/**
	Iterates one complex point in the Mandelbrot recurrence and returns
	the iteration where it escaped. A return value of 0 means the point
	stayed bounded for the full iteration limit.
*/
static int iterate ( double x, double y )
{
	double cr = y - 0.5;
	double ci = x;
	double zi = 0.0;
	double zr = 0.0;
	int i = 0;

	while (1) {
		i++;

		// Expand z = z^2 + c using separate real and imaginary parts.
		double temp = zr * zi;
		double zr2 = zr * zr;
		double zi2 = zi * zi;
		zr = zr2 - zi2 + cr;
		zi = temp + temp + ci;
		if (zi2 + zr2 > BAILOUT) return i;
		if (i > MAX_ITERATIONS) return 0;
	}
}


/**
	Renders the benchmark's ASCII Mandelbrot view the requested number
	of times so every language performs the same amount of work.
*/
static void mandelbrot ( int runs )
{
	int i;
	for (i = 0; i < runs; i++) {
		int x,y;
		for (y = -39; y < 39; y++) {
			printf("\n");
			for (x = -39; x < 39; x++) {
				// Escaped points become spaces; stable points become stars.
				if (iterate(x / 40.0, y / 40.0))
					printf(" ");
				else
					printf("*");
			}
		}
		printf ("\n");
	}
}


/**
	Parses the optional run count, renders the benchmark output, and
	prints the total elapsed wall-clock time to stderr.
*/
int main ( int argc, const char * argv[] )
{
	double start;
	double query_time;
	struct timeval aTv;
	int runs = 1;

	if (argc > 1) {
		sscanf(argv[1], "%d", &runs);
	}
	gettimeofday(&aTv, NULL);
	mandelbrot(runs);

	start = aTv.tv_sec * 1000000.0 + aTv.tv_usec;
	gettimeofday(&aTv,NULL);
	query_time = (double)aTv.tv_sec * 1000000.0 + aTv.tv_usec;
	query_time -= start;
	query_time /= 1000000.0;
	fprintf(stderr, "C Elapsed %0.3f\n", query_time);
    return 0;
}
