<?php

$TARGET_SIZE = 1024 * 1024;
$WORD_COUNT = 16;
$LINE_LIMIT = 80;
$FNV_OFFSET_HI = 0xcbf29ce4;
$FNV_OFFSET_LO = 0x84222325;
$FNV_PRIME_SMALL = 0x1b3;
$REFERENCE_HASH_HI = 0x35ce3126;
$REFERENCE_HASH_LO = 0xab961070;

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

function hash_bytes($text) {
	global $FNV_OFFSET_HI, $FNV_OFFSET_LO;

	$hashHi = $FNV_OFFSET_HI;
	$hashLo = $FNV_OFFSET_LO;
	for ($i = 0; $i < strlen($text); $i++) {
		$hashLo = ($hashLo ^ ord($text[$i])) & 0xffffffff;
		list($hashHi, $hashLo) = multiply_hash($hashHi, $hashLo);
	}
	return array($hashHi, $hashLo);
}

function build_source_text($words) {
	global $TARGET_SIZE, $WORD_COUNT;

	$parts = array();
	$length = 0;
	$wordCount = 0;
	$state = 0x12345678;

	while (true) {
		$word = $words[random_next($state) % $WORD_COUNT];
		if ($wordCount > 0) {
			$parts[] = " ";
			$length++;
		}
		$parts[] = $word;
		$length += strlen($word);
		$wordCount++;
		if ($length > $TARGET_SIZE) {
			break;
		}
	}

	$text = implode("", $parts);
	list($hashHi, $hashLo) = hash_bytes($text);
	return array($text, $wordCount, $hashHi, $hashLo);
}

function wrap_words($words) {
	global $LINE_LIMIT;

	$parts = array();
	$lineLength = 0;
	for ($i = 0; $i < count($words); $i++) {
		$word = $words[$i];
		$wordLength = strlen($word);

		if ($i == 0) {
			$parts[] = $word;
			$lineLength = $wordLength;
		} elseif ($lineLength + 1 + $wordLength >= $LINE_LIMIT) {
			$parts[] = "\n";
			$parts[] = $word;
			$lineLength = $wordLength;
		} else {
			$parts[] = " ";
			$parts[] = $word;
			$lineLength += 1 + $wordLength;
		}
	}
	return implode("", $parts);
}

function hash_wrapped_text($text) {
	global $FNV_OFFSET_HI, $FNV_OFFSET_LO;

	$lines = explode("\n", $text);
	$hashHi = $FNV_OFFSET_HI;
	$hashLo = $FNV_OFFSET_LO;
	for ($i = 0; $i < count($lines); $i++) {
		if ($i > 0) {
			$hashLo = ($hashLo ^ 32) & 0xffffffff;
			list($hashHi, $hashLo) = multiply_hash($hashHi, $hashLo);
		}

		$line = $lines[$i];
		for ($j = 0; $j < strlen($line); $j++) {
			$hashLo = ($hashLo ^ ord($line[$j])) & 0xffffffff;
			list($hashHi, $hashLo) = multiply_hash($hashHi, $hashLo);
		}
	}
	return array($hashHi, $hashLo);
}

function format_hash($hi, $lo) {
	return sprintf("0x%08x%08x", $hi, $lo);
}

function run_benchmark($sourceText, $sourceHashHi, $sourceHashLo, $runs) {
	for ($i = 0; $i < $runs; $i++) {
		$splitWords = explode(" ", $sourceText);
		$wrappedText = wrap_words($splitWords);
		list($wrappedHi, $wrappedLo) = hash_wrapped_text($wrappedText);

		if ($wrappedHi != $sourceHashHi || $wrappedLo != $sourceHashLo) {
			fwrite(
				STDERR,
				"Hash mismatch: "
				. format_hash($wrappedHi, $wrappedLo)
				. " != "
				. format_hash($sourceHashHi, $sourceHashLo)
				. "\n"
			);
			exit(1);
		}
	}
}

$words = array(
	"I",
	"we",
	"cat",
	"tree",
	"apple",
	"bridge",
	"lantern",
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
$runs = 1;
if ($argc > 1) {
	$runs = $argv[1];
}
list($sourceText, $sourceWordCount, $sourceHashHi, $sourceHashLo) =
	build_source_text($words);
if (
	$sourceHashHi != $REFERENCE_HASH_HI ||
	$sourceHashLo != $REFERENCE_HASH_LO
) {
	fwrite(
		STDERR,
		"Source hash mismatch: "
		. format_hash($sourceHashHi, $sourceHashLo)
		. " != "
		. format_hash($REFERENCE_HASH_HI, $REFERENCE_HASH_LO)
		. "\n"
	);
	exit(1);
}

$d1 = microtime(true);
run_benchmark($sourceText, $sourceHashHi, $sourceHashLo, $runs);
$diff = microtime(true) - $d1;
fprintf(STDERR, "PHP Elapsed %0.2f\n", $diff);
?>
