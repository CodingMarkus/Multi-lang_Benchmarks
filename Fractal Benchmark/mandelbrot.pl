#!/usr/bin/perl

use strict;
use warnings;
use Time::HiRes qw( gettimeofday );

my $BAILOUT = 16;
my $MAX_ITERATIONS = 1000;

sub iterate {
    my ( $x, $y ) = @_;

    my $cr = $y - 0.5;
    my $ci = $x;
    my $zi = 0;
    my $zr = 0;
    my $i = 0;

    # Code runs much faster if the vars below are declared
    # outside the loop; in Perl scope really matters!
    my ($temp, $zr2, $zi2);
    while (1) {
        $i += 1;
        $temp = $zr * $zi;
        $zr2  = $zr * $zr;
        $zi2  = $zi * $zi;
        $zr = $zr2 - $zi2 + $cr;
        $zi = $temp + $temp + $ci;
        return $i if ($zi2 + $zr2 > $BAILOUT);
        return 0 if ($i > $MAX_ITERATIONS);
    }
}

sub mandelbrot {
    my $runs = $_[0];

    my ($i, $x, $y, $z);
    for ($i = 0; $i < $runs; $i++) {
        for ($y = -39; $y < 39; $y++ ) {
            print "\n";
            for ($x = -39; $x < 39; $x++ ) {
                $z = iterate( $x / 40.0, $y / 40.0 );
                if (!$z) {
                    print '*';
                }
                else {
                    print ' ';
                }
            }
        }
        print "\n";
    }
}

my $begin = gettimeofday();
if ($#ARGV == -1) {
    mandelbrot(1);
} else {
    mandelbrot($ARGV[0]);
}
my $end = gettimeofday() - $begin;
printf STDERR "Perl Elapsed %0.3f\n", $end;
