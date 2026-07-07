import Foundation

let targetSize = 16 * 1024 * 1024
let chunkSize = 4096
let fnvOffset: UInt64 = 14695981039346656037
let fnvPrime: UInt64 = 1099511628211
let referenceSourceHash: UInt64 = 0xc637e6db1fa57009
let referenceDigest: [UInt8] = [
	0x99, 0x5e, 0x8c, 0x22, 0xa0, 0xda, 0x3f, 0x9e,
	0x01, 0x20, 0xf6, 0x9b, 0x09, 0x28, 0x7a, 0x16,
	0x92, 0xb9, 0x51, 0x7f, 0x1a, 0x58, 0xbd, 0xcb,
	0x75, 0xeb, 0x4e, 0x1d, 0xce, 0x56, 0x7f, 0x2b
]
let sha256Constants: [UInt32] = [
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
]


private struct SHA256Context {
	var state: [UInt32] = [
		0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
		0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19
	]
	var messageSchedule = [UInt32](repeating: 0, count: 64)
	var bitCount: UInt64 = 0
	var buffer = [UInt8](repeating: 0, count: 64)
	var bufferLength = 0
}


private struct BenchmarkData {
	let sourceBytes: [UInt8]
	let sourceHash: UInt64
	let digest: [UInt8]
}


private
func randomNext(_ state: inout UInt32) -> UInt32
{
	state = state &* 1664525 &+ 1013904223
	return state
}


private
func fnv1aHash(_ bytes: [UInt8]) -> UInt64
{
	var hash = fnvOffset

	for byte in bytes {
		hash ^= UInt64(byte)
		hash = hash &* fnvPrime
	}
	return hash
}


private
func rotateRight(_ value: UInt32, _ amount: UInt32) -> UInt32
{
	return (value >> amount) | (value << (32 - amount))
}


private
func loadBE32(_ bytes: [UInt8], _ offset: Int) -> UInt32
{
	return
		(UInt32(bytes[offset]) << 24)
		| (UInt32(bytes[offset + 1]) << 16)
		| (UInt32(bytes[offset + 2]) << 8)
		| UInt32(bytes[offset + 3])
}


private
func storeBE32(_ bytes: inout [UInt8], _ offset: Int, _ value: UInt32)
{
	bytes[offset] = UInt8(truncatingIfNeeded: value >> 24)
	bytes[offset + 1] = UInt8(truncatingIfNeeded: value >> 16)
	bytes[offset + 2] = UInt8(truncatingIfNeeded: value >> 8)
	bytes[offset + 3] = UInt8(truncatingIfNeeded: value)
}


private
func sha256Transform(
	_ context: inout SHA256Context,
	_ block: [UInt8],
	_ blockOffset: Int
)
{
	var a: UInt32
	var b: UInt32
	var c: UInt32
	var d: UInt32
	var e: UInt32
	var f: UInt32
	var g: UInt32
	var h: UInt32

	for i in 0 ..< 16 {
		context.messageSchedule[i] = loadBE32(block, blockOffset + i * 4)
	}

	for i in 16 ..< 64 {
		let s0 =
			rotateRight(context.messageSchedule[i - 15], 7) ^
			rotateRight(context.messageSchedule[i - 15], 18) ^
			(context.messageSchedule[i - 15] >> 3)
		let s1 =
			rotateRight(context.messageSchedule[i - 2], 17) ^
			rotateRight(context.messageSchedule[i - 2], 19) ^
			(context.messageSchedule[i - 2] >> 10)
		context.messageSchedule[i] =
			context.messageSchedule[i - 16]
			&+ s0
			&+ context.messageSchedule[i - 7]
			&+ s1
	}

	a = context.state[0]
	b = context.state[1]
	c = context.state[2]
	d = context.state[3]
	e = context.state[4]
	f = context.state[5]
	g = context.state[6]
	h = context.state[7]

	for i in 0 ..< 64 {
		let sum1 =
			rotateRight(e, 6) ^
			rotateRight(e, 11) ^
			rotateRight(e, 25)
		let choice = (e & f) ^ ((~e) & g)
		let temp1 =
			h
			&+ sum1
			&+ choice
			&+ sha256Constants[i]
			&+ context.messageSchedule[i]
		let sum0 =
			rotateRight(a, 2) ^
			rotateRight(a, 13) ^
			rotateRight(a, 22)
		let majority = (a & b) ^ (a & c) ^ (b & c)
		let temp2 = sum0 &+ majority

		h = g
		g = f
		f = e
		e = d &+ temp1
		d = c
		c = b
		b = a
		a = temp1 &+ temp2
	}

	context.state[0] &+= a
	context.state[1] &+= b
	context.state[2] &+= c
	context.state[3] &+= d
	context.state[4] &+= e
	context.state[5] &+= f
	context.state[6] &+= g
	context.state[7] &+= h
}


private
func sha256Update(
	_ context: inout SHA256Context,
	_ bytes: [UInt8],
	_ start: Int,
	_ length: Int
)
{
	var offset = start
	let end = start + length

	context.bitCount &+= UInt64(length) * 8

	if context.bufferLength > 0 {
		var copyLength = 64 - context.bufferLength

		if copyLength > end - offset {
			copyLength = end - offset
		}

		for i in 0 ..< copyLength {
			context.buffer[context.bufferLength + i] = bytes[offset + i]
		}
		context.bufferLength += copyLength
		offset += copyLength

		if context.bufferLength == 64 {
			sha256Transform(&context, context.buffer, 0)
			context.bufferLength = 0
		}
	}

	while offset + 64 <= end {
		sha256Transform(&context, bytes, offset)
		offset += 64
	}

	if offset < end {
		context.bufferLength = end - offset
		for i in 0 ..< context.bufferLength {
			context.buffer[i] = bytes[offset + i]
		}
	}
}


private
func sha256Final(_ context: inout SHA256Context) -> [UInt8]
{
	var digest = [UInt8](repeating: 0, count: 32)

	context.buffer[context.bufferLength] = 0x80
	context.bufferLength += 1

	if context.bufferLength > 56 {
		for i in context.bufferLength ..< 64 {
			context.buffer[i] = 0
		}
		sha256Transform(&context, context.buffer, 0)
		context.bufferLength = 0
	}

	for i in context.bufferLength ..< 56 {
		context.buffer[i] = 0
	}
	context.buffer[56] = UInt8(truncatingIfNeeded: context.bitCount >> 56)
	context.buffer[57] = UInt8(truncatingIfNeeded: context.bitCount >> 48)
	context.buffer[58] = UInt8(truncatingIfNeeded: context.bitCount >> 40)
	context.buffer[59] = UInt8(truncatingIfNeeded: context.bitCount >> 32)
	context.buffer[60] = UInt8(truncatingIfNeeded: context.bitCount >> 24)
	context.buffer[61] = UInt8(truncatingIfNeeded: context.bitCount >> 16)
	context.buffer[62] = UInt8(truncatingIfNeeded: context.bitCount >> 8)
	context.buffer[63] = UInt8(truncatingIfNeeded: context.bitCount)
	sha256Transform(&context, context.buffer, 0)

	for i in 0 ..< 8 {
		storeBE32(&digest, i * 4, context.state[i])
	}

	return digest
}


private
func formatDigest(_ digest: [UInt8]) -> String
{
	return digest.map { String(format: "%02x", $0) }.joined()
}


private
func buildSourceBytes() -> ([UInt8], UInt64)
{
	var bytes = [UInt8](repeating: 0, count: targetSize)
	var state: UInt32 = 0x12345678

	for i in 0 ..< targetSize {
		bytes[i] = UInt8(truncatingIfNeeded: randomNext(&state) >> 24)
	}

	return (bytes, fnv1aHash(bytes))
}


private
func hashSourceBytes(_ bytes: [UInt8]) -> [UInt8]
{
	var context = SHA256Context()
	var offset = 0

	while offset < targetSize {
		var length = chunkSize

		if length > targetSize - offset {
			length = targetSize - offset
		}

		sha256Update(&context, bytes, offset, length)
		offset += length
	}

	return sha256Final(&context)
}


private
func buildBenchmarkData() -> BenchmarkData
{
	let (sourceBytes, sourceHash) = buildSourceBytes()

	if sourceHash != referenceSourceHash {
		fputs(
			String(
				format: "Source hash mismatch: 0x%016llx != 0x%016llx\n",
				sourceHash,
				referenceSourceHash
			),
			stderr
		)
		exit(1)
	}

	let digest = hashSourceBytes(sourceBytes)
	if digest != referenceDigest {
		fputs(
			"Source digest mismatch: \(formatDigest(digest)) != "
				+ "995e8c22a0da3f9e0120f69b09287a1692b9517f1a58bdcb"
				+ "75eb4e1dce567f2b\n",
			stderr
		)
		exit(1)
	}

	return BenchmarkData(
		sourceBytes: sourceBytes,
		sourceHash: sourceHash,
		digest: digest
	)
}


private
func runBenchmark(_ data: BenchmarkData, _ runs: Int)
{
	for _ in 0 ..< runs {
		let digest = hashSourceBytes(data.sourceBytes)

		if digest != data.digest {
			fputs(
				"Digest mismatch: \(formatDigest(digest)) != "
					+ "\(formatDigest(data.digest))\n",
				stderr
			)
			exit(1)
		}
	}
}


private func main ( )
{
	let runs = if CommandLine.arguments.count <= 1
		|| CommandLine.arguments[1] == ""
	{
		1
	} else {
		Int(CommandLine.arguments[1]) ?? 1
	}
	let data = buildBenchmarkData()
	let _ = data.sourceHash
	let startTime = CFAbsoluteTimeGetCurrent()
	runBenchmark(data, runs)
	let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
	let timeString = String(format: "%.3f", timeElapsed)
	fputs("Swift Elapsed \(timeString)\n", stderr)
}

main()
