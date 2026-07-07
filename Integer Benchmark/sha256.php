<?php

$TARGET_SIZE = 16 * 1024 * 1024;
$CHUNK_SIZE = 4096;
$FNV_OFFSET_HI = 0xcbf29ce4;
$FNV_OFFSET_LO = 0x84222325;
$FNV_PRIME_SMALL = 0x1b3;
$REFERENCE_HASH_HI = 0xc637e6db;
$REFERENCE_HASH_LO = 0x1fa57009;
$REFERENCE_DIGEST = array(
	0x99, 0x5e, 0x8c, 0x22, 0xa0, 0xda, 0x3f, 0x9e,
	0x01, 0x20, 0xf6, 0x9b, 0x09, 0x28, 0x7a, 0x16,
	0x92, 0xb9, 0x51, 0x7f, 0x1a, 0x58, 0xbd, 0xcb,
	0x75, 0xeb, 0x4e, 0x1d, 0xce, 0x56, 0x7f, 0x2b
);
$SHA256_CONSTANTS = array(
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

function random_next(&$state) {
	$state = (($state * 1664525) + 1013904223) & 0xffffffff;
	return $state;
}

function multiply_hash($hi, $lo) {
	global $FNV_PRIME_SMALL;

	$lowProduct = $lo * $FNV_PRIME_SMALL;
	$newLo = $lowProduct % 4294967296;
	$carry = intdiv($lowProduct, 4294967296);
	$highProduct = $hi * $FNV_PRIME_SMALL + $carry + (($lo << 8) & 0xffffffff);
	$newHi = $highProduct % 4294967296;
	return array($newHi, $newLo);
}

function fnv1a_hash($sourceBytes) {
	global $FNV_OFFSET_HI, $FNV_OFFSET_LO;

	$hashHi = $FNV_OFFSET_HI;
	$hashLo = $FNV_OFFSET_LO;
	$length = strlen($sourceBytes);

	for ($i = 0; $i < $length; $i++) {
		$hashLo = ($hashLo ^ ord($sourceBytes[$i])) & 0xffffffff;
		list($hashHi, $hashLo) = multiply_hash($hashHi, $hashLo);
	}

	return array($hashHi, $hashLo);
}

function rotate_right($value, $amount) {
	$value &= 0xffffffff;
	return (($value >> $amount) | ($value << (32 - $amount))) & 0xffffffff;
}

function load_be32($sourceBytes, $offset) {
	return (
		(ord($sourceBytes[$offset]) << 24)
		| (ord($sourceBytes[$offset + 1]) << 16)
		| (ord($sourceBytes[$offset + 2]) << 8)
		| ord($sourceBytes[$offset + 3])
	) & 0xffffffff;
}

function store_be32(&$targetBytes, $offset, $value) {
	$targetBytes[$offset] = chr(($value >> 24) & 0xff);
	$targetBytes[$offset + 1] = chr(($value >> 16) & 0xff);
	$targetBytes[$offset + 2] = chr(($value >> 8) & 0xff);
	$targetBytes[$offset + 3] = chr($value & 0xff);
}

function create_context() {
	return array(
		'state' => array(
			0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
			0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19
		),
		'message_schedule' => array_fill(0, 64, 0),
		'bit_count' => 0,
		'buffer' => str_repeat("\0", 64),
		'buffer_length' => 0
	);
}

function sha256_transform(&$context, $block, $blockOffset) {
	global $SHA256_CONSTANTS;

	for ($i = 0; $i < 16; $i++) {
		$context['message_schedule'][$i] =
			load_be32($block, $blockOffset + $i * 4);
	}

	for ($i = 16; $i < 64; $i++) {
		$s0 =
			rotate_right($context['message_schedule'][$i - 15], 7) ^
			rotate_right($context['message_schedule'][$i - 15], 18) ^
			($context['message_schedule'][$i - 15] >> 3);
		$s1 =
			rotate_right($context['message_schedule'][$i - 2], 17) ^
			rotate_right($context['message_schedule'][$i - 2], 19) ^
			($context['message_schedule'][$i - 2] >> 10);
		$context['message_schedule'][$i] = (
			$context['message_schedule'][$i - 16] +
			$s0 +
			$context['message_schedule'][$i - 7] +
			$s1
		) & 0xffffffff;
	}

	list($a, $b, $c, $d, $e, $f, $g, $h) = $context['state'];

	for ($i = 0; $i < 64; $i++) {
		$sum1 =
			rotate_right($e, 6) ^
			rotate_right($e, 11) ^
			rotate_right($e, 25);
		$choice = ($e & $f) ^ ((~$e) & $g);
		$temp1 = (
			$h +
			$sum1 +
			$choice +
			$SHA256_CONSTANTS[$i] +
			$context['message_schedule'][$i]
		) & 0xffffffff;
		$sum0 =
			rotate_right($a, 2) ^
			rotate_right($a, 13) ^
			rotate_right($a, 22);
		$majority = ($a & $b) ^ ($a & $c) ^ ($b & $c);
		$temp2 = ($sum0 + $majority) & 0xffffffff;

		$h = $g;
		$g = $f;
		$f = $e;
		$e = ($d + $temp1) & 0xffffffff;
		$d = $c;
		$c = $b;
		$b = $a;
		$a = ($temp1 + $temp2) & 0xffffffff;
	}

	$context['state'][0] = ($context['state'][0] + $a) & 0xffffffff;
	$context['state'][1] = ($context['state'][1] + $b) & 0xffffffff;
	$context['state'][2] = ($context['state'][2] + $c) & 0xffffffff;
	$context['state'][3] = ($context['state'][3] + $d) & 0xffffffff;
	$context['state'][4] = ($context['state'][4] + $e) & 0xffffffff;
	$context['state'][5] = ($context['state'][5] + $f) & 0xffffffff;
	$context['state'][6] = ($context['state'][6] + $g) & 0xffffffff;
	$context['state'][7] = ($context['state'][7] + $h) & 0xffffffff;
}

function sha256_update(&$context, $sourceBytes, $start, $length) {
	$offset = $start;
	$end = $start + $length;

	$context['bit_count'] += $length * 8;

	if ($context['buffer_length'] > 0) {
		$copyLength = 64 - $context['buffer_length'];

		if ($copyLength > $end - $offset) {
			$copyLength = $end - $offset;
		}

		for ($i = 0; $i < $copyLength; $i++) {
			$context['buffer'][$context['buffer_length'] + $i] =
				$sourceBytes[$offset + $i];
		}
		$context['buffer_length'] += $copyLength;
		$offset += $copyLength;

		if ($context['buffer_length'] == 64) {
			sha256_transform($context, $context['buffer'], 0);
			$context['buffer_length'] = 0;
		}
	}

	while ($offset + 64 <= $end) {
		sha256_transform($context, $sourceBytes, $offset);
		$offset += 64;
	}

	if ($offset < $end) {
		$context['buffer_length'] = $end - $offset;
		for ($i = 0; $i < $context['buffer_length']; $i++) {
			$context['buffer'][$i] = $sourceBytes[$offset + $i];
		}
	}
}

function sha256_final(&$context) {
	$digest = str_repeat("\0", 32);

	$context['buffer'][$context['buffer_length']] = chr(0x80);
	$context['buffer_length']++;

	if ($context['buffer_length'] > 56) {
		for ($i = $context['buffer_length']; $i < 64; $i++) {
			$context['buffer'][$i] = chr(0);
		}
		sha256_transform($context, $context['buffer'], 0);
		$context['buffer_length'] = 0;
	}

	for ($i = $context['buffer_length']; $i < 56; $i++) {
		$context['buffer'][$i] = chr(0);
	}
	$bitCount = $context['bit_count'];
	$context['buffer'][56] = chr(($bitCount >> 56) & 0xff);
	$context['buffer'][57] = chr(($bitCount >> 48) & 0xff);
	$context['buffer'][58] = chr(($bitCount >> 40) & 0xff);
	$context['buffer'][59] = chr(($bitCount >> 32) & 0xff);
	$context['buffer'][60] = chr(($bitCount >> 24) & 0xff);
	$context['buffer'][61] = chr(($bitCount >> 16) & 0xff);
	$context['buffer'][62] = chr(($bitCount >> 8) & 0xff);
	$context['buffer'][63] = chr($bitCount & 0xff);
	sha256_transform($context, $context['buffer'], 0);

	for ($i = 0; $i < 8; $i++) {
		store_be32($digest, $i * 4, $context['state'][$i]);
	}

	return $digest;
}

function equal_digest($left, $right) {
	if (strlen($left) != count($right)) {
		return false;
	}

	for ($i = 0; $i < strlen($left); $i++) {
		if (ord($left[$i]) != $right[$i]) {
			return false;
		}
	}

	return true;
}

function build_source_bytes() {
	global $TARGET_SIZE;

	$sourceBytes = str_repeat("\0", $TARGET_SIZE);
	$state = 0x12345678;

	for ($i = 0; $i < $TARGET_SIZE; $i++) {
		$sourceBytes[$i] = chr(random_next($state) >> 24);
	}

	return array($sourceBytes, fnv1a_hash($sourceBytes));
}

function hash_source_bytes($sourceBytes) {
	global $TARGET_SIZE, $CHUNK_SIZE;

	$context = create_context();
	$offset = 0;

	while ($offset < $TARGET_SIZE) {
		$length = $CHUNK_SIZE;

		if ($length > $TARGET_SIZE - $offset) {
			$length = $TARGET_SIZE - $offset;
		}

		sha256_update($context, $sourceBytes, $offset, $length);
		$offset += $length;
	}

	return sha256_final($context);
}

function build_benchmark_data() {
	global $REFERENCE_HASH_HI, $REFERENCE_HASH_LO, $REFERENCE_DIGEST;

	list($sourceBytes, $sourceHash) = build_source_bytes();

	if (
		$sourceHash[0] != $REFERENCE_HASH_HI ||
		$sourceHash[1] != $REFERENCE_HASH_LO
	) {
		fwrite(
			STDERR,
			"Source hash mismatch: "
			. sprintf("0x%08x%08x", $sourceHash[0], $sourceHash[1])
			. " != "
			. sprintf("0x%08x%08x", $REFERENCE_HASH_HI, $REFERENCE_HASH_LO)
			. "\n"
		);
		exit(1);
	}

	$digest = hash_source_bytes($sourceBytes);
	if (!equal_digest($digest, $REFERENCE_DIGEST)) {
		fwrite(
			STDERR,
			"Source digest mismatch: "
			. bin2hex($digest)
			. " != "
			. "995e8c22a0da3f9e0120f69b09287a1692b9517f1a58bdcb"
			. "75eb4e1dce567f2b\n"
		);
		exit(1);
	}

	return array($sourceBytes, $sourceHash, $digest);
}

function run_benchmark($sourceBytes, $digest, $runs) {
	for ($i = 0; $i < $runs; $i++) {
		$currentDigest = hash_source_bytes($sourceBytes);

		if ($currentDigest !== $digest) {
			fwrite(
				STDERR,
				"Digest mismatch: "
				. bin2hex($currentDigest)
				. " != "
				. bin2hex($digest)
				. "\n"
			);
			exit(1);
		}
	}
}

$runs = 1;
if ($argc > 1) {
	$runs = (int) $argv[1];
}

list($sourceBytes, $sourceHash, $digest) = build_benchmark_data();
$d1 = microtime(true);
run_benchmark($sourceBytes, $digest, $runs);
$diff = microtime(true) - $d1;
fprintf(STDERR, "PHP Elapsed %0.3f\n", $diff);
?>
