#!/usr/bin/python

import sys, time
stdout = sys.stdout

BAILOUT = 16
MAX_ITERATIONS = 1000

def iterate(x, y):
	cr = y - 0.5
	ci = x
	zi = 0.0
	zr = 0.0
	i = 0

	while True:
		i += 1
		temp = zr * zi
		zr2 = zr * zr
		zi2 = zi * zi
		zr = zr2 - zi2 + cr
		zi = temp + temp + ci
		if zi2 + zr2 > BAILOUT: return i
		if i > MAX_ITERATIONS: return 0

def mandelbrot(runs):
	for i in range(runs):
		for y in range(-39, 39):
			stdout.write('\n')
			for x in range(-39, 39):
				z = iterate(x / 40.0, y / 40.0)
				if z == 0:
					stdout.write('*')
				else:
					stdout.write(' ')
		stdout.write('\n')

t = time.time()

runs = 1
if len(sys.argv) > 1:
	runs = int(sys.argv[1])
mandelbrot(runs)
print('Python: %.03f s' % (time.time() - t), file=sys.stderr)
