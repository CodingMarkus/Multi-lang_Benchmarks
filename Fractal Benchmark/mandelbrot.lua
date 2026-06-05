local BAILOUT = 16
local MAX_ITERATIONS = 1000

function iterate(x, y)
	local cr = y - 0.5
	local ci = x
	local zi = 0.0
	local zr = 0.0
	local i = 0

	while 1 do
		i = i+1
		local temp = zr * zi
		local zr2 = zr * zr
		local zi2 = zi * zi
		zr = zr2 - zi2 + cr
		zi = temp + temp + ci
		if (zi2 + zr2 > BAILOUT) then
			return i
		end

		if (i > MAX_ITERATIONS) then
			return 0
		end
	end

end

function mandelbrot(runs)
	for i = 1, runs do
		for y = -39, 38 do
			for x = -39, 38 do
				if (iterate(x / 40.0, y / 40) == 0) then
					io.write("*")
				else
					io.write(" ")
				end
			end
			io.write("\n")
		end
	end
end

local t = os.clock()
if (arg[1] ~= nil) then
	mandelbrot(tonumber(arg[1]) or 1)
else
	mandelbrot(1)
end
local diff = os.clock() - t
io.stderr:write(string.format("Lua Elapsed %.3f\n", diff))
