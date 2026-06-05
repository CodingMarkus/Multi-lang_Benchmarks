package main

import (
	"fmt"
	"os"
	"strconv"
	"time"
)

var bailout float64 = 16
var maxIterations = 1000

func main ( ) {
	start := time.Now()
	var runs = 1
	if len(os.Args) > 1 {
		runs, _ = strconv.Atoi(os.Args[1])
	}
	mandelbrot(runs)
	diff := time.Since(start)
	fmt.Fprintf(os.Stderr, "Go Elapsed %.3f\n", diff.Seconds())
	// fmt.Fprintf(os.Stderr, "Go Elapsed %s\n", diff)
}


func iterate ( x float64, y float64 ) int {
	cr := y - 0.5
	ci := x
	zi := 0.0
	zr := 0.0
	i := 0

	for {
		i++
		temp := zr * zi
		zr2 := zr * zr
		zi2 := zi * zi
		zr = zr2 - zi2 + cr
		zi = temp + temp + ci
		if zi2+zr2 > bailout {
			return i
		}
		if i > maxIterations {
			return 0
		}
	}
	return 0
}


func mandelbrot ( runs int ) {
	for i := 0; i < runs; i++ {
		for y := -39; y < 39; y++ {
			fmt.Println("")
			for x := -39; x < 39; x++ {
				if iterate(float64(x)/40.0, float64(y)/40.0) == 0 {
					fmt.Print("*")
				} else {
					fmt.Print(" ")
				}
			}
		}
		fmt.Println("")
	}
}
