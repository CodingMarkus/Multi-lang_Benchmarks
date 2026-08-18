#!/usr/bin/perl

use strict;
use warnings;
use utf8;
use bytes;
use Time::HiRes qw( gettimeofday );

my $TARGET_SIZE = 1024 * 1024;
my $WORD_COUNT = 16;
my $LINE_LIMIT = 80;
my $FNV_OFFSET_HI = 0xcbf29ce4;
my $FNV_OFFSET_LO = 0x84222325;
my $FNV_PRIME_SMALL = 0x1b3;
my $REFERENCE_HASH_HI = 0xc6be9b92;
my $REFERENCE_HASH_LO = 0x67a2fb8e;

sub random_next {
	my ($state_ref) = @_;
	$$state_ref = (($$state_ref * 1664525) + 1013904223) & 0xffffffff;
	return $$state_ref;
}

sub multiply_hash {
	my ($hi, $lo) = @_;

	my $low_product = $lo * $FNV_PRIME_SMALL;
	my $new_lo = $low_product % 4294967296;
	my $carry = int($low_product / 4294967296);
	my $high_product =
		$hi * $FNV_PRIME_SMALL + $carry + (($lo << 8) & 0xffffffff);
	my $new_hi = $high_product % 4294967296;

	return ($new_hi, $new_lo);
}

sub hash_bytes {
	my ($text) = @_;
	my $hash_hi = $FNV_OFFSET_HI;
	my $hash_lo = $FNV_OFFSET_LO;
	my $i;

	for ($i = 0; $i < length($text); $i++) {
		$hash_lo = ($hash_lo ^ ord(substr($text, $i, 1))) & 0xffffffff;
		($hash_hi, $hash_lo) = multiply_hash($hash_hi, $hash_lo);
	}

	return ($hash_hi, $hash_lo);
}

sub build_source_text {
	my ($words_ref) = @_;
	my @parts = ();
	my $length = 0;
	my $word_count = 0;
	my $state = 0x12345678;

	while (1) {
		my $word = $words_ref->[random_next(\$state) % $WORD_COUNT];

		if ($word_count > 0) {
			push @parts, " ";
			$length += 1;
		}

		push @parts, $word;
		$length += length($word);
		$word_count++;

		if ($length > $TARGET_SIZE) {
			last;
		}
	}

	my $text = join("", @parts);
	my ($hash_hi, $hash_lo) = hash_bytes($text);
	return ($text, $word_count, $hash_hi, $hash_lo);
}

sub wrap_words {
	my ($words_ref) = @_;
	my @parts = ();
	my $line_length = 0;
	my $i;

	for ($i = 0; $i < scalar(@$words_ref); $i++) {
		my $word = $words_ref->[$i];
		my $word_length = length($word);

		if ($i == 0) {
			push @parts, $word;
			$line_length = $word_length;
			next;
		}

		if ($line_length + 1 + $word_length >= $LINE_LIMIT) {
			push @parts, "\n", $word;
			$line_length = $word_length;
		}
		else {
			push @parts, " ", $word;
			$line_length += 1 + $word_length;
		}
	}

	return join("", @parts);
}

sub hash_wrapped_text {
	my ($text) = @_;
	my @lines = split(/\n/, $text, -1);
	my $hash_hi = $FNV_OFFSET_HI;
	my $hash_lo = $FNV_OFFSET_LO;
	my ($i, $j);

	for ($i = 0; $i < scalar(@lines); $i++) {
		if ($i > 0) {
			$hash_lo = ($hash_lo ^ 32) & 0xffffffff;
			($hash_hi, $hash_lo) = multiply_hash($hash_hi, $hash_lo);
		}

		for ($j = 0; $j < length($lines[$i]); $j++) {
			$hash_lo =
				($hash_lo ^ ord(substr($lines[$i], $j, 1))) & 0xffffffff;
			($hash_hi, $hash_lo) = multiply_hash($hash_hi, $hash_lo);
		}
	}

	return ($hash_hi, $hash_lo);
}

sub format_hash {
	my ($hi, $lo) = @_;
	return sprintf("0x%08x%08x", $hi, $lo);
}

sub run_benchmark {
	my ($source_text, $source_hash_hi, $source_hash_lo, $runs) = @_;
	my $i;

	for ($i = 0; $i < $runs; $i++) {
		my @split_words = split(/ /, $source_text);
		my $wrapped_text = wrap_words(\@split_words);
		my ($wrapped_hi, $wrapped_lo) = hash_wrapped_text($wrapped_text);

		if (
			$wrapped_hi != $source_hash_hi ||
			$wrapped_lo != $source_hash_lo
		) {
			print STDERR
				"Hash mismatch: "
				. format_hash($wrapped_hi, $wrapped_lo)
				. " != "
				. format_hash($source_hash_hi, $source_hash_lo)
				. "\n";
			exit(1);
		}
	}
}

my @words = (
	"I",
	"we",
	"cat",
	"tree",
	"café",
	"naïve",
	"jalapeño",
	"mountain",
	"blueberry",
	"basketball",
	"grandfather",
	"microbiology",
	"determination",
	"responsibility",
	"experimentation",
	"counterclockwise"
);
my $runs = $#ARGV == -1 ? 1 : $ARGV[0];
my ($source_text, $source_word_count, $source_hash_hi, $source_hash_lo) =
	build_source_text(\@words);

if (
	$source_hash_hi != $REFERENCE_HASH_HI ||
	$source_hash_lo != $REFERENCE_HASH_LO
) {
	print STDERR
		"Source hash mismatch: "
		. format_hash($source_hash_hi, $source_hash_lo)
		. " != "
		. format_hash($REFERENCE_HASH_HI, $REFERENCE_HASH_LO)
		. "\n";
	exit(1);
}

my $begin = gettimeofday();
run_benchmark($source_text, $source_hash_hi, $source_hash_lo, $runs);
my $end = gettimeofday() - $begin;
printf STDERR "Perl: %0.3f s\n", $end;
