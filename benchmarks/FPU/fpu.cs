using System;
using System.Diagnostics;

public class FPU
{
    private const int BAILOUT = 16;
    private const int MAX_ITERATIONS = 1000;

    private static int Iterate ( double x, double y )
    {
        double cr = y - 0.5;
        double ci = x;
        double zi = 0.0;
        double zr = 0.0;
        int i = 0;

        while (true)
        {
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


    private static void DrawMandelbrot ( int runs )
    {
        for (int run = 0; run < runs; run++)
        {
            for (int y = -39; y < 39; y++)
            {
                Console.WriteLine();
                for (int x = -39; x < 39; x++)
                {
                    if (Iterate(x / 40.0, y / 40.0) > 0)
                        Console.Write(" ");
                    else
                        Console.Write("*");
                }
            }
            Console.WriteLine();
        }
    }


    public static void Main ( string[] args )
    {
        int runs = 1;

        if (args.Length > 0) {
            if (int.TryParse(args[0], out int parsedRuns)) {
                runs = parsedRuns;
            }
        }

        long startTimestamp = Stopwatch.GetTimestamp();
        DrawMandelbrot(runs);
        double queryTime = (Stopwatch.GetTimestamp() - startTimestamp)
            / (double) Stopwatch.Frequency;
        Console.Error.WriteLine($"C#: {queryTime:F3} s");
    }
}
