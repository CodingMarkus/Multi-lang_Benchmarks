import java.util.Locale;
import java.text.DecimalFormat;
import java.text.DecimalFormatSymbols;

class Mandelbrot
{
	static int BAILOUT = 16;
	static int MAX_ITERATIONS = 1000;

	private static int iterate(double x, double y)
	{
		double cr = y - 0.5f;
		double ci = x;
		double zi = 0.0f;
		double zr = 0.0f;
		int i = 0;
		while (true) {
			i++;
			double temp = zr * zi;
			double zr2 = zr * zr;
			double zi2 = zi * zi;
			zr = zr2 - zi2 + cr;
			zi = temp + temp + ci;
			if (zi2 + zr2 > BAILOUT) return i;
			if (i > MAX_ITERATIONS) return 0;
		}
	}

	private static void mandelbrot(int runs)
	{
		int x,y, i;
		for (i = 0; i < runs; i++) {
			for (y = -39; y < 39; y++) {
				System.out.print("\n");
				for (x = -39; x < 39; x++) {
					if (iterate(x / 40.0, y / 40.0) == 0)
						System.out.print("*");
					else
						System.out.print(" ");

				}
			}
			System.out.print("\n");
		}
	}

	public static void main(String args[])
	{
		long diff;
		long start;

		start =  System.currentTimeMillis();
		int runs = 1;
		if (args.length == 0) {
			mandelbrot(runs);
		} else {
			runs = Integer.parseInt(args[0]);
			mandelbrot(runs);
		}
		diff = System.currentTimeMillis() - start;
		DecimalFormat df = new DecimalFormat(
			"0.000", new DecimalFormatSymbols(Locale.US));

		System.err.println("Java Elapsed " + df.format(diff/1000.0f));
	}
}
