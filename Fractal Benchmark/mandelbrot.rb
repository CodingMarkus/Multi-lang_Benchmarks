#!/usr/bin/ruby

BAILOUT = 16
MAX_ITERATIONS = 1000

def iterate(x,y)
	cr = y-0.5
	ci = x
	zi = 0.0
	zr = 0.0
	i = 0

	while (1)
		i += 1
		temp = zr * zi
		zr2 = zr * zr
		zi2 = zi * zi
		zr = zr2 - zi2 + cr
		zi = temp + temp + ci
		return i if (zi2 + zr2 > BAILOUT)
		return 0 if (i > MAX_ITERATIONS)
	end
end

def mandelbrot(runs)
	for i in 0...runs do
		for y in -39...39 do
			puts
			for x in -39...39 do
				z = iterate(x / 40.0,y / 40.0)
				if (z == 0)
					print "*"
				else
					print " "
				end
			end
		end
		puts
	end
end

time = Time.now
if (ARGV.length == 0)
  mandelbrot(1)
else
  mandelbrot(Integer(ARGV[0]))
end
diff = Time.now - time
$stderr.printf "Ruby Elapsed %.2f\n" % diff
