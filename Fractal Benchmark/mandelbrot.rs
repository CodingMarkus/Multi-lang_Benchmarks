use std::time::{SystemTime, UNIX_EPOCH};


const BAILOUT: f64 = 16.0;
const MAX_ITERATIONS: i32 = 1000;


fn iterate (x: f64, y: f64 ) -> i32
{
    let cr = y - 0.5;
    let ci = x;
    let mut zi = 0.0;
    let mut zr = 0.0;
    let mut i = 0;

    while i < MAX_ITERATIONS {
        i += 1;
        let temp = zr * zi;
        let zr2 = zr * zr;
        let zi2 = zi * zi;
        zr = zr2 - zi2 + cr;
        zi = temp + temp + ci;
        if zi2 + zr2 > BAILOUT {
            return i;
        }
    }
    return 0;
}

fn mandelbrot ( runs: i32 )
{
    for _ in 0..runs {
        for y in -39..39 {
            println!();
            for x in -39..39 {
                if iterate(x as f64 / 40.0, y as f64 / 40.0) > 0 {
                    print!(" ");
                } else {
                    print!("*");
                }
            }
        }
        println!();
    }
}

fn main ( )
{
    let args: Vec<String> = std::env::args().collect();

	let start = SystemTime::now();
	let runs = if args.len() <= 1 {
	    1
	} else {
	    args[1].parse::<i32>().unwrap_or(1)
	};

    mandelbrot(runs);

    let end = SystemTime::now();
    let elapsed = end.duration_since(UNIX_EPOCH).unwrap().as_secs_f64()
		- start.duration_since(UNIX_EPOCH).unwrap().as_secs_f64();
    eprintln!("Rust Elapsed {:.2}", elapsed);
}
