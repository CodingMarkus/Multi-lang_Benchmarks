const TARGET_SIZE = 16 * 1024 * 1024;
const CHUNK_SIZE = 4096;
const FNV_OFFSET_HI = 0xcbf29ce4 >>> 0;
const FNV_OFFSET_LO = 0x84222325 >>> 0;
const FNV_PRIME_SMALL = 0x1b3;
const REFERENCE_SOURCE_HASH_HI = 0xc637e6db >>> 0;
const REFERENCE_SOURCE_HASH_LO = 0x1fa57009 >>> 0;
const REFERENCE_DIGEST = new Uint8Array([
	0x99, 0x5e, 0x8c, 0x22, 0xa0, 0xda, 0x3f, 0x9e,
	0x01, 0x20, 0xf6, 0x9b, 0x09, 0x28, 0x7a, 0x16,
	0x92, 0xb9, 0x51, 0x7f, 0x1a, 0x58, 0xbd, 0xcb,
	0x75, 0xeb, 0x4e, 0x1d, 0xce, 0x56, 0x7f, 0x2b
]);
const SHA256_CONSTANTS = new Uint32Array([
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
]);

interface Context {
	state: Uint32Array;
	messageSchedule: Uint32Array;
	bitCount: number;
	buffer: Uint8Array;
	bufferLength: number;
}

interface Hash {
	hi: number;
	lo: number;
}

function randomNext(state: { value: number }): number
{
	state.value = (
		(state.value * 1664525 >>> 0) + 1013904223
	) >>> 0;
	return state.value;
}

function fnv1aHash(bytes: Uint8Array): Hash
{
	var hashHi = FNV_OFFSET_HI;
	var hashLo = FNV_OFFSET_LO;

	for (var i = 0; i < bytes.length; i++) {
		hashLo = (hashLo ^ bytes[i]) >>> 0;
		var lowProduct = hashLo * FNV_PRIME_SMALL;
		var newLo = lowProduct % 0x100000000;
		var carry = Math.floor(lowProduct / 0x100000000);
		var highProduct = (
			hashHi * FNV_PRIME_SMALL + carry + ((hashLo << 8) >>> 0)
		);
		hashHi = highProduct % 0x100000000;
		hashLo = newLo >>> 0;
	}
	return { hi: hashHi >>> 0, lo: hashLo };
}

function rotateRight(value: number, amount: number): number
{
	return ((value >>> amount) | (value << (32 - amount))) >>> 0;
}

function loadBE32(bytes: Uint8Array, offset: number): number
{
	return (
		(bytes[offset] << 24)
		| (bytes[offset + 1] << 16)
		| (bytes[offset + 2] << 8)
		| bytes[offset + 3]
	) >>> 0;
}

function storeBE32(
	bytes: Uint8Array,
	offset: number,
	value: number
): void
{
	bytes[offset] = value >>> 24;
	bytes[offset + 1] = (value >>> 16) & 0xff;
	bytes[offset + 2] = (value >>> 8) & 0xff;
	bytes[offset + 3] = value & 0xff;
}

function createContext(): Context
{
	return {
		state: new Uint32Array([
			0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
			0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19
		]),
		messageSchedule: new Uint32Array(64),
		bitCount: 0,
		buffer: new Uint8Array(64),
		bufferLength: 0
	};
}

function sha256Transform(
	context: Context,
	block: Uint8Array,
	blockOffset: number
): void
{
	var i: number;
	var a;
	var b;
	var c;
	var d;
	var e;
	var f;
	var g;
	var h;
	var messageSchedule = context.messageSchedule;

	for (i = 0; i < 16; i++) {
		messageSchedule[i] = loadBE32(block, blockOffset + i * 4);
	}

	for (i = 16; i < 64; i++) {
		var s0 =
			rotateRight(messageSchedule[i - 15], 7) ^
			rotateRight(messageSchedule[i - 15], 18) ^
			(messageSchedule[i - 15] >>> 3);
		var s1 =
			rotateRight(messageSchedule[i - 2], 17) ^
			rotateRight(messageSchedule[i - 2], 19) ^
			(messageSchedule[i - 2] >>> 10);
		messageSchedule[i] = (
			messageSchedule[i - 16]
			+ s0
			+ messageSchedule[i - 7]
			+ s1
		) >>> 0;
	}

	a = context.state[0];
	b = context.state[1];
	c = context.state[2];
	d = context.state[3];
	e = context.state[4];
	f = context.state[5];
	g = context.state[6];
	h = context.state[7];

	for (i = 0; i < 64; i++) {
		var sum1 =
			rotateRight(e, 6) ^
			rotateRight(e, 11) ^
			rotateRight(e, 25);
		var choice = (e & f) ^ ((~e) & g);
		var temp1: number = (
			h
			+ sum1
			+ choice
			+ SHA256_CONSTANTS[i]
			+ messageSchedule[i]
		) >>> 0;
		var sum0: number =
			rotateRight(a, 2) ^
			rotateRight(a, 13) ^
			rotateRight(a, 22);
		var majority = (a & b) ^ (a & c) ^ (b & c);
		var temp2: number = (sum0 + majority) >>> 0;

		h = g;
		g = f;
		f = e;
		e = (d + temp1) >>> 0;
		d = c;
		c = b;
		b = a;
		a = (temp1 + temp2) >>> 0;
	}

	context.state[0] = (context.state[0] + a) >>> 0;
	context.state[1] = (context.state[1] + b) >>> 0;
	context.state[2] = (context.state[2] + c) >>> 0;
	context.state[3] = (context.state[3] + d) >>> 0;
	context.state[4] = (context.state[4] + e) >>> 0;
	context.state[5] = (context.state[5] + f) >>> 0;
	context.state[6] = (context.state[6] + g) >>> 0;
	context.state[7] = (context.state[7] + h) >>> 0;
}

function sha256Update(
	context: Context,
	bytes: Uint8Array,
	start: number,
	length: number
): void
{
	var offset = start;
	var end = start + length;
	var i: number;

	context.bitCount += length * 8;

	if (context.bufferLength > 0) {
		var copyLength = 64 - context.bufferLength;

		if (copyLength > end - offset) {
			copyLength = end - offset;
		}

		for (i = 0; i < copyLength; i++) {
			context.buffer[context.bufferLength + i] = bytes[offset + i];
		}
		context.bufferLength += copyLength;
		offset += copyLength;

		if (context.bufferLength === 64) {
			sha256Transform(context, context.buffer, 0);
			context.bufferLength = 0;
		}
	}

	while (offset + 64 <= end) {
		sha256Transform(context, bytes, offset);
		offset += 64;
	}

	if (offset < end) {
		context.bufferLength = end - offset;
		for (i = 0; i < context.bufferLength; i++) {
			context.buffer[i] = bytes[offset + i];
		}
	}
}

function sha256Final(context: Context): Uint8Array
{
	var digest = new Uint8Array(32);
	var i: number;

	context.buffer[context.bufferLength] = 0x80;
	context.bufferLength++;

	if (context.bufferLength > 56) {
		for (i = context.bufferLength; i < 64; i++) {
			context.buffer[i] = 0;
		}
		sha256Transform(context, context.buffer, 0);
		context.bufferLength = 0;
	}

	for (i = context.bufferLength; i < 56; i++) {
		context.buffer[i] = 0;
	}
	context.buffer[56] = Math.floor(context.bitCount / 0x100000000000000)
		& 0xff;
	context.buffer[57] = Math.floor(context.bitCount / 0x1000000000000)
		& 0xff;
	context.buffer[58] = Math.floor(context.bitCount / 0x10000000000)
		& 0xff;
	context.buffer[59] = Math.floor(context.bitCount / 0x100000000)
		& 0xff;
	context.buffer[60] = (context.bitCount >>> 24) & 0xff;
	context.buffer[61] = (context.bitCount >>> 16) & 0xff;
	context.buffer[62] = (context.bitCount >>> 8) & 0xff;
	context.buffer[63] = context.bitCount & 0xff;
	sha256Transform(context, context.buffer, 0);

	for (i = 0; i < 8; i++) {
		storeBE32(digest, i * 4, context.state[i]);
	}

	return digest;
}

function formatDigest(digest: Uint8Array): string
{
	return "invalid digest";
}

function equalDigest(left: Uint8Array, right: Uint8Array): boolean
{
	for (var i = 0; i < left.length; i++) {
		if (left[i] !== right[i]) {
			return false;
		}
	}
	return true;
}

function buildSourceBytes(): { bytes: Uint8Array; hash: Hash }
{
	var bytes = new Uint8Array(TARGET_SIZE);
	var state = { value: 0x12345678 };

	for (var i = 0; i < TARGET_SIZE; i++) {
		bytes[i] = randomNext(state) >>> 24;
	}

	return {
		bytes: bytes,
		hash: fnv1aHash(bytes)
	};
}

function hashSourceBytes(bytes: Uint8Array): Uint8Array
{
	var context = createContext();
	var offset = 0;

	while (offset < TARGET_SIZE) {
		var length = CHUNK_SIZE;

		if (length > TARGET_SIZE - offset) {
			length = TARGET_SIZE - offset;
		}

		sha256Update(context, bytes, offset, length);
		offset += length;
	}

	return sha256Final(context);
}

function buildBenchmarkData(): {
	sourceBytes: Uint8Array;
	sourceHash: Hash;
	digest: Uint8Array;
}
{
	var source = buildSourceBytes();
	var digest;

	if (
		source.hash.hi !== REFERENCE_SOURCE_HASH_HI
		|| source.hash.lo !== REFERENCE_SOURCE_HASH_LO
	) {
		process.stderr.write(
			"Source hash mismatch.\n"
		);
		process.exit(1);
	}

	digest = hashSourceBytes(source.bytes);
	if (!equalDigest(digest, REFERENCE_DIGEST)) {
		process.stderr.write(
			"Source digest mismatch: "
			+ formatDigest(digest)
			+ " != "
			+ "995e8c22a0da3f9e0120f69b09287a1692b9517f1a58bdcb"
			+ "75eb4e1dce567f2b\n"
		);
		process.exit(1);
	}

	return {
		sourceBytes: source.bytes,
		sourceHash: source.hash,
		digest: digest
	};
}

function runBenchmark(
	data: { sourceBytes: Uint8Array; digest: Uint8Array },
	runs: number
): void
{
	for (var i = 0; i < runs; i++) {
		var digest = hashSourceBytes(data.sourceBytes);

		if (!equalDigest(digest, data.digest)) {
			process.stderr.write(
				"Digest mismatch: "
				+ formatDigest(digest)
				+ " != "
				+ formatDigest(data.digest)
				+ "\n"
			);
			process.exit(1);
		}
	}
}

var args = process.argv.slice(2);
var runs = args.length > 0 ? parseInt(args[0], 10) : 1;
var data = buildBenchmarkData();
void data.sourceHash;
var start = Date.now();
runBenchmark(data, runs);
var elapsed = (Date.now() - start) / 1000;
process.stderr.write(
	"JavaScript: " + elapsed.toFixed(3) + " s\n"
);
