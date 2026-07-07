#!/usr/bin/perl

use strict;
use warnings;
use bytes;
use Time::HiRes qw( gettimeofday );

my $TARGET_SIZE = 16 * 1024 * 1024;
my $CHUNK_SIZE = 4096;
my $FNV_OFFSET_HI = 0xcbf29ce4;
my $FNV_OFFSET_LO = 0x84222325;
my $FNV_PRIME_SMALL = 0x1b3;
my $REFERENCE_HASH_HI = 0xc637e6db;
my $REFERENCE_HASH_LO = 0x1fa57009;
my @REFERENCE_DIGEST = (
	0x99, 0x5e, 0x8c, 0x22, 0xa0, 0xda, 0x3f, 0x9e,
	0x01, 0x20, 0xf6, 0x9b, 0x09, 0x28, 0x7a, 0x16,
	0x92, 0xb9, 0x51, 0x7f, 0x1a, 0x58, 0xbd, 0xcb,
	0x75, 0xeb, 0x4e, 0x1d, 0xce, 0x56, 0x7f, 0x2b
);
my @SHA256_CONSTANTS = (
	0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5,
	0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
	0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
	0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
	0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc,
	0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
	0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
	0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
	0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
	0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
	0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3,
	0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
	0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5,
	0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
	0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
	0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
);

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

sub fnv1a_hash {
	my ($source_bytes) = @_;
	my $hash_hi = $FNV_OFFSET_HI;
	my $hash_lo = $FNV_OFFSET_LO;
	my $i;

	for ($i = 0; $i < length($source_bytes); $i++) {
		$hash_lo = ($hash_lo ^ ord(substr($source_bytes, $i, 1))) & 0xffffffff;
		($hash_hi, $hash_lo) = multiply_hash($hash_hi, $hash_lo);
	}

	return ($hash_hi, $hash_lo);
}

sub rotate_right {
	my ($value, $amount) = @_;
	$value &= 0xffffffff;
	return (($value >> $amount) | ($value << (32 - $amount))) & 0xffffffff;
}

sub load_be32 {
	my ($source_bytes, $offset) = @_;
	return (
		(ord(substr($source_bytes, $offset, 1)) << 24)
		| (ord(substr($source_bytes, $offset + 1, 1)) << 16)
		| (ord(substr($source_bytes, $offset + 2, 1)) << 8)
		| ord(substr($source_bytes, $offset + 3, 1))
	) & 0xffffffff;
}

sub store_be32 {
	my ($target_ref, $offset, $value) = @_;
	substr($$target_ref, $offset, 1) = chr(($value >> 24) & 0xff);
	substr($$target_ref, $offset + 1, 1) = chr(($value >> 16) & 0xff);
	substr($$target_ref, $offset + 2, 1) = chr(($value >> 8) & 0xff);
	substr($$target_ref, $offset + 3, 1) = chr($value & 0xff);
}

sub create_context {
	return {
		state => [
			0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
			0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19
		],
		message_schedule => [ (0) x 64 ],
		bit_count => 0,
		buffer => "\0" x 64,
		buffer_length => 0
	};
}

sub sha256_transform {
	my ($context, $block, $block_offset) = @_;
	my $i;

	for ($i = 0; $i < 16; $i++) {
		$context->{message_schedule}->[$i] =
			load_be32($block, $block_offset + $i * 4);
	}

	for ($i = 16; $i < 64; $i++) {
		my $s0 =
			rotate_right($context->{message_schedule}->[$i - 15], 7) ^
			rotate_right($context->{message_schedule}->[$i - 15], 18) ^
			($context->{message_schedule}->[$i - 15] >> 3);
		my $s1 =
			rotate_right($context->{message_schedule}->[$i - 2], 17) ^
			rotate_right($context->{message_schedule}->[$i - 2], 19) ^
			($context->{message_schedule}->[$i - 2] >> 10);
		$context->{message_schedule}->[$i] = (
			$context->{message_schedule}->[$i - 16] +
			$s0 +
			$context->{message_schedule}->[$i - 7] +
			$s1
		) & 0xffffffff;
	}

	my ($a, $b, $c, $d, $e, $f, $g, $h) = @{$context->{state}};

	for ($i = 0; $i < 64; $i++) {
		my $sum1 =
			rotate_right($e, 6) ^
			rotate_right($e, 11) ^
			rotate_right($e, 25);
		my $choice = ($e & $f) ^ ((~$e) & $g);
		my $temp1 = (
			$h +
			$sum1 +
			$choice +
			$SHA256_CONSTANTS[$i] +
			$context->{message_schedule}->[$i]
		) & 0xffffffff;
		my $sum0 =
			rotate_right($a, 2) ^
			rotate_right($a, 13) ^
			rotate_right($a, 22);
		my $majority = ($a & $b) ^ ($a & $c) ^ ($b & $c);
		my $temp2 = ($sum0 + $majority) & 0xffffffff;

		$h = $g;
		$g = $f;
		$f = $e;
		$e = ($d + $temp1) & 0xffffffff;
		$d = $c;
		$c = $b;
		$b = $a;
		$a = ($temp1 + $temp2) & 0xffffffff;
	}

	$context->{state}->[0] = ($context->{state}->[0] + $a) & 0xffffffff;
	$context->{state}->[1] = ($context->{state}->[1] + $b) & 0xffffffff;
	$context->{state}->[2] = ($context->{state}->[2] + $c) & 0xffffffff;
	$context->{state}->[3] = ($context->{state}->[3] + $d) & 0xffffffff;
	$context->{state}->[4] = ($context->{state}->[4] + $e) & 0xffffffff;
	$context->{state}->[5] = ($context->{state}->[5] + $f) & 0xffffffff;
	$context->{state}->[6] = ($context->{state}->[6] + $g) & 0xffffffff;
	$context->{state}->[7] = ($context->{state}->[7] + $h) & 0xffffffff;
}

sub sha256_update {
	my ($context, $source_bytes, $start, $length) = @_;
	my $offset = $start;
	my $end = $start + $length;
	my $i;

	$context->{bit_count} += $length * 8;

	if ($context->{buffer_length} > 0) {
		my $copy_length = 64 - $context->{buffer_length};

		if ($copy_length > $end - $offset) {
			$copy_length = $end - $offset;
		}

		for ($i = 0; $i < $copy_length; $i++) {
			substr($context->{buffer}, $context->{buffer_length} + $i, 1) =
				substr($source_bytes, $offset + $i, 1);
		}
		$context->{buffer_length} += $copy_length;
		$offset += $copy_length;

		if ($context->{buffer_length} == 64) {
			sha256_transform($context, $context->{buffer}, 0);
			$context->{buffer_length} = 0;
		}
	}

	while ($offset + 64 <= $end) {
		sha256_transform($context, $source_bytes, $offset);
		$offset += 64;
	}

	if ($offset < $end) {
		$context->{buffer_length} = $end - $offset;
		for ($i = 0; $i < $context->{buffer_length}; $i++) {
			substr($context->{buffer}, $i, 1) =
				substr($source_bytes, $offset + $i, 1);
		}
	}
}

sub sha256_final {
	my ($context) = @_;
	my $digest = "\0" x 32;
	my $i;

	substr($context->{buffer}, $context->{buffer_length}, 1) = chr(0x80);
	$context->{buffer_length}++;

	if ($context->{buffer_length} > 56) {
		for ($i = $context->{buffer_length}; $i < 64; $i++) {
			substr($context->{buffer}, $i, 1) = chr(0);
		}
		sha256_transform($context, $context->{buffer}, 0);
		$context->{buffer_length} = 0;
	}

	for ($i = $context->{buffer_length}; $i < 56; $i++) {
		substr($context->{buffer}, $i, 1) = chr(0);
	}

	my $bit_count = $context->{bit_count};
	substr($context->{buffer}, 56, 1) = chr(($bit_count >> 56) & 0xff);
	substr($context->{buffer}, 57, 1) = chr(($bit_count >> 48) & 0xff);
	substr($context->{buffer}, 58, 1) = chr(($bit_count >> 40) & 0xff);
	substr($context->{buffer}, 59, 1) = chr(($bit_count >> 32) & 0xff);
	substr($context->{buffer}, 60, 1) = chr(($bit_count >> 24) & 0xff);
	substr($context->{buffer}, 61, 1) = chr(($bit_count >> 16) & 0xff);
	substr($context->{buffer}, 62, 1) = chr(($bit_count >> 8) & 0xff);
	substr($context->{buffer}, 63, 1) = chr($bit_count & 0xff);
	sha256_transform($context, $context->{buffer}, 0);

	for ($i = 0; $i < 8; $i++) {
		store_be32(\$digest, $i * 4, $context->{state}->[$i]);
	}

	return $digest;
}

sub build_source_bytes {
	my $source_bytes = "\0" x $TARGET_SIZE;
	my $state = 0x12345678;
	my $i;

	for ($i = 0; $i < $TARGET_SIZE; $i++) {
		substr($source_bytes, $i, 1) = chr(random_next(\$state) >> 24);
	}

	return ($source_bytes, fnv1a_hash($source_bytes));
}

sub hash_source_bytes {
	my ($source_bytes) = @_;
	my $context = create_context();
	my $offset = 0;

	while ($offset < $TARGET_SIZE) {
		my $length = $CHUNK_SIZE;

		if ($length > $TARGET_SIZE - $offset) {
			$length = $TARGET_SIZE - $offset;
		}

		sha256_update($context, $source_bytes, $offset, $length);
		$offset += $length;
	}

	return sha256_final($context);
}

sub build_benchmark_data {
	my ($source_bytes, $source_hash_hi, $source_hash_lo) =
		build_source_bytes();

	if (
		$source_hash_hi != $REFERENCE_HASH_HI ||
		$source_hash_lo != $REFERENCE_HASH_LO
	) {
		print STDERR
			"Source hash mismatch: "
			. sprintf("0x%08x%08x", $source_hash_hi, $source_hash_lo)
			. " != "
			. sprintf("0x%08x%08x", $REFERENCE_HASH_HI, $REFERENCE_HASH_LO)
			. "\n";
		exit(1);
	}

	my $digest = hash_source_bytes($source_bytes);
	if (unpack("H*", $digest) ne unpack("H*", pack("C*", @REFERENCE_DIGEST))) {
		print STDERR
			"Source digest mismatch: "
			. unpack("H*", $digest)
			. " != "
			. "995e8c22a0da3f9e0120f69b09287a1692b9517f1a58bdcb"
			. "75eb4e1dce567f2b\n";
		exit(1);
	}

	return ($source_bytes, $source_hash_hi, $source_hash_lo, $digest);
}

sub run_benchmark {
	my ($source_bytes, $digest, $runs) = @_;
	my $i;

	for ($i = 0; $i < $runs; $i++) {
		my $current_digest = hash_source_bytes($source_bytes);

		if ($current_digest ne $digest) {
			print STDERR
				"Digest mismatch: "
				. unpack("H*", $current_digest)
				. " != "
				. unpack("H*", $digest)
				. "\n";
			exit(1);
		}
	}
}

my $runs = $#ARGV == -1 ? 1 : $ARGV[0];
my ($source_bytes, $source_hash_hi, $source_hash_lo, $digest) =
	build_benchmark_data();
my $begin = gettimeofday();
run_benchmark($source_bytes, $digest, $runs);
my $end = gettimeofday() - $begin;
printf STDERR "Perl Elapsed %0.3f\n", $end;
