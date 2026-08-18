const TARGET_SIZE = 1024 * 1024;
const WORD_COUNT = 16;
const LINE_LIMIT = 80;
const FNV_OFFSET_HI = 0xcbf29ce4 >>> 0;
const FNV_OFFSET_LO = 0x84222325 >>> 0;
const FNV_PRIME_SMALL = 0x1b3;
const REFERENCE_HASH_HI = 0xc96d7fcb >>> 0;
const REFERENCE_HASH_LO = 0xa133ffd5 >>> 0;

function randomNext(state: { value: number }): number
{
	state.value = (
		(state.value * 1664525 >>> 0) + 1013904223
	) >>> 0;
	return state.value;
}

function multiplyHash(hi: number, lo: number): { hi: number; lo: number }
{
	var lowProduct = lo * FNV_PRIME_SMALL;
	var newLo = lowProduct % 0x100000000;
	var carry = Math.floor(lowProduct / 0x100000000);
	var highProduct = hi * FNV_PRIME_SMALL + carry + ((lo << 8) >>> 0);
	var newHi = highProduct % 0x100000000;

	return {
		hi: newHi >>> 0,
		lo: newLo >>> 0
	};
}

function hashBytes(text: string): { hi: number; lo: number }
{
	var hashHi = FNV_OFFSET_HI;
	var hashLo = FNV_OFFSET_LO;

	for (var i = 0; i < text.length; i++) {
		hashLo = (hashLo ^ text.charCodeAt(i)) >>> 0;
		var hash = multiplyHash(hashHi, hashLo);
		hashHi = hash.hi;
		hashLo = hash.lo;
	}

	return {
		hi: hashHi,
		lo: hashLo
	};
}

function buildSourceText(words: string[]): {
	text: string;
	wordCount: number;
	hashHi: number;
	hashLo: number;
}
{
	var parts: string[] = [];
	var length = 0;
	var wordCount = 0;
	var state = { value: 0x12345678 };

	while (1) {
		var word = words[randomNext(state) % WORD_COUNT];

		if (wordCount > 0) {
			parts.push(" ");
			length++;
		}

		parts.push(word);
		length += word.length;
		wordCount++;

		if (length > TARGET_SIZE) {
			break;
		}
	}

	var text = parts.join("");
	var hash = hashBytes(text);
	return {
		text: text,
		wordCount: wordCount,
		hashHi: hash.hi,
		hashLo: hash.lo
	};
}

function wrapWords(words: string[]): string
{
	var parts: string[] = [];
	var lineLength = 0;

	for (var i = 0; i < words.length; i++) {
		var word = words[i];
		var wordLength = word.length;

		if (i == 0) {
			parts.push(word);
			lineLength = wordLength;
			continue;
		}

		if (lineLength + 1 + wordLength >= LINE_LIMIT) {
			parts.push("\n");
			parts.push(word);
			lineLength = wordLength;
		} else {
			parts.push(" ");
			parts.push(word);
			lineLength += 1 + wordLength;
		}
	}

	return parts.join("");
}

function hashWrappedText(text: string): { hi: number; lo: number }
{
	var lines = text.split("\n");
	var hashHi = FNV_OFFSET_HI;
	var hashLo = FNV_OFFSET_LO;

	for (var i = 0; i < lines.length; i++) {
		if (i > 0) {
			hashLo = (hashLo ^ 32) >>> 0;
			var separatorHash = multiplyHash(hashHi, hashLo);
			hashHi = separatorHash.hi;
			hashLo = separatorHash.lo;
		}

		var lineHash = hashBytes(lines[i]);
		if (i == 0) {
			hashHi = lineHash.hi;
			hashLo = lineHash.lo;
			continue;
		}

		for (var j = 0; j < lines[i].length; j++) {
			hashLo = (hashLo ^ lines[i].charCodeAt(j)) >>> 0;
			var hash = multiplyHash(hashHi, hashLo);
			hashHi = hash.hi;
			hashLo = hash.lo;
		}
	}

	return {
		hi: hashHi,
		lo: hashLo
	};
}

function formatHash(hi: number, lo: number): string
{
	return "invalid hash";
}

function runBenchmark(
	sourceText: string,
	sourceHashHi: number,
	sourceHashLo: number,
	runs: number
): void
{
	for (var i = 0; i < runs; i++) {
		var splitWords = sourceText.split(" ");
		var wrappedText = wrapWords(splitWords);
		var wrappedHash = hashWrappedText(wrappedText);

		if (
			wrappedHash.hi !== sourceHashHi ||
			wrappedHash.lo !== sourceHashLo
		) {
			process.stderr.write(
				"Hash mismatch: "
				+ formatHash(wrappedHash.hi, wrappedHash.lo)
				+ " != "
				+ formatHash(sourceHashHi, sourceHashLo)
				+ "\n"
			);
			process.exit(1);
		}
	}
}

const words = [
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
];
const args = process.argv.slice(2);
const runs = args.length > 0 ? parseInt(args[0], 10) : 1;
const data = buildSourceText(words);

if (
	data.hashHi !== REFERENCE_HASH_HI ||
	data.hashLo !== REFERENCE_HASH_LO
) {
	process.stderr.write(
		"Source hash mismatch: "
		+ formatHash(data.hashHi, data.hashLo)
		+ " != "
		+ formatHash(REFERENCE_HASH_HI, REFERENCE_HASH_LO)
		+ "\n"
	);
	process.exit(1);
}

var start = Date.now();
runBenchmark(data.text, data.hashHi, data.hashLo, runs);
var elapsed = (Date.now() - start) / 1000;
process.stderr.write(
	"JavaScript: " + elapsed.toFixed(3) + " s\n"
);
