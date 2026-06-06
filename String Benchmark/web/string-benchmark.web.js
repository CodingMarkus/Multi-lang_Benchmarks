const TARGET_SIZE = 1024 * 1024;
const WORD_COUNT = 16;
const LINE_LIMIT = 80;
const FNV_OFFSET = 0xcbf29ce484222325n;
const FNV_PRIME = 0x100000001b3n;
const MASK = 0xffffffffffffffffn;
const REFERENCE_HASH = 0xc96d7fcba133ffd5n;

function randomNext(state)
{
	state.value = (
		(Math.imul(state.value, 1664525) >>> 0) + 1013904223
	) >>> 0;
	return state.value;
}

function hashBytes(text)
{
	var hash = FNV_OFFSET;

	for (var i = 0; i < text.length; i++) {
		hash ^= BigInt(text.charCodeAt(i));
		hash = (hash * FNV_PRIME) & MASK;
	}
	return hash;
}

function buildSourceText(words)
{
	var parts = [];
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
	return {
		text: text,
		hash: hashBytes(text)
	};
}

function wrapWords(words)
{
	var parts = [];
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

function hashWrappedText(text)
{
	var lines = text.split("\n");
	var hash = FNV_OFFSET;

	for (var i = 0; i < lines.length; i++) {
		if (i > 0) {
			hash ^= 32n;
			hash = (hash * FNV_PRIME) & MASK;
		}

		for (var j = 0; j < lines[i].length; j++) {
			hash ^= BigInt(lines[i].charCodeAt(j));
			hash = (hash * FNV_PRIME) & MASK;
		}
	}

	return hash;
}

function runBenchmark(sourceText, sourceHash, runs)
{
	for (var i = 0; i < runs; i++) {
		var splitWords = sourceText.split(" ");
		var wrappedText = wrapWords(splitWords);
		var wrappedHash = hashWrappedText(wrappedText);

		if (wrappedHash != sourceHash) {
			document.write(
				"Hash mismatch: 0x" + wrappedHash.toString(16)
				+ " != 0x" + sourceHash.toString(16)
			);
			return;
		}
	}
}

function getRuns()
{
	var params = new URLSearchParams(window.location.search);
	var runs = parseInt(params.get("runs"), 10);

	if (!Number.isFinite(runs) || runs < 1) {
		return 1;
	}
	return runs;
}

var words = [
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
var data = buildSourceText(words);
if (data.hash != REFERENCE_HASH) {
	document.write(
		"Source hash mismatch: 0x" + data.hash.toString(16)
		+ " != 0x" + REFERENCE_HASH.toString(16)
	);
} else {
	var runs = getRuns();
	var date = new Date();
	runBenchmark(data.text, data.hash, runs);
	var date2 = new Date();
	document.write(
		"\nJavaScript Elapsed "
		+ (date2.getTime() - date.getTime()) / 1000
	);
}
