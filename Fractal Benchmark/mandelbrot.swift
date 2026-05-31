import Foundation

let BAILOUT = 16.0
let MAX_ITERATIONS = 1000

private
func iterate(_ x: Double, _ y: Double) -> Int
{
	let cr: Double = y - 0.5
	let ci: Double = x
	var zi: Double = 0.0
	var zr: Double = 0.0
	var i: Int = 0

	while true {
		i += 1
		let temp: Double = zr * zi
		let zr2: Double = zr * zr
		let zi2: Double = zi * zi
		zr = zr2 - zi2 + cr;
		zi = temp + temp + ci;
		if zi2 + zr2 > BAILOUT {
			return i
		}
		if i > MAX_ITERATIONS { return 0 }
	}
}


private
func mandelbrot(runs: Int)
{
	for _ in 0 ..< runs {
		for y in -39 ..< 39 {
			print("\n", terminator: "")
			for x in -39 ..< 39 {
				if iterate(Double(x) / 40.0, Double(y) / 40.0) > 0 {
					print(" ", terminator: "")
				} else {
					print("*", terminator: "")
				}
			}
		}
	}
}


public struct StderrOutputStream: TextOutputStream {
    public static let stream = StderrOutputStream ( )
    public func write(_ string: String) { fputs(string, stderr) }
}
var errStream = StderrOutputStream()


private func main ( )
{
	let startTime = CFAbsoluteTimeGetCurrent()
	let runs = if CommandLine.arguments.count <= 1
		|| CommandLine.arguments[1] == ""
	{
		1
	} else {
		Int(CommandLine.arguments[1]) ?? 1
	}
	mandelbrot(runs: runs)
	let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
	let timeString = String(format: "%.2f", timeElapsed)
	print("Swift Elapsed \(timeString)", to: &errStream)
}

main()
