package main

import (
	"fmt"
	"os"
	"strconv"
	"time"
)

var targetSize = 16 * 1024 * 1024
var chunkSize = 4096
var fnvOffset uint64 = 14695981039346656037
var fnvPrime uint64 = 1099511628211
var referenceSourceHash uint64 = 0xc637e6db1fa57009
var referenceDigest = [32]byte{
	0x99, 0x5e, 0x8c, 0x22, 0xa0, 0xda, 0x3f, 0x9e,
	0x01, 0x20, 0xf6, 0x9b, 0x09, 0x28, 0x7a, 0x16,
	0x92, 0xb9, 0x51, 0x7f, 0x1a, 0x58, 0xbd, 0xcb,
	0x75, 0xeb, 0x4e, 0x1d, 0xce, 0x56, 0x7f, 0x2b,
}

type SHA256Context struct {
	state        [8]uint32
	bitCount     uint64
	buffer       [64]byte
	bufferLength int
}

type BenchmarkData struct {
	sourceBytes []byte
	sourceHash  uint64
	digest      [32]byte
}

func randomNext(state *uint32) uint32 {
	*state = *state*1664525 + 1013904223
	return *state
}

func fnv1aHash(bytes []byte) uint64 {
	hash := fnvOffset

	for i := 0; i < len(bytes); i++ {
		hash ^= uint64(bytes[i])
		hash *= fnvPrime
	}
	return hash
}

func rotateRight(value uint32, amount uint32) uint32 {
	return (value >> amount) | (value << (32 - amount))
}

func loadBE32(bytes []byte) uint32 {
	return (uint32(bytes[0]) << 24) |
		(uint32(bytes[1]) << 16) |
		(uint32(bytes[2]) << 8) |
		uint32(bytes[3])
}

func storeBE32(bytes []byte, offset int, value uint32) {
	bytes[offset] = byte(value >> 24)
	bytes[offset+1] = byte(value >> 16)
	bytes[offset+2] = byte(value >> 8)
	bytes[offset+3] = byte(value)
}

func sha256Transform(context *SHA256Context, block []byte) {
	constants := [64]uint32{
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
		0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
	}
	var messageSchedule [64]uint32
	var a uint32
	var b uint32
	var c uint32
	var d uint32
	var e uint32
	var f uint32
	var g uint32
	var h uint32

	for i := 0; i < 16; i++ {
		messageSchedule[i] = loadBE32(block[i*4 : i*4+4])
	}

	for i := 16; i < 64; i++ {
		s0 :=
			rotateRight(messageSchedule[i-15], 7) ^
				rotateRight(messageSchedule[i-15], 18) ^
				(messageSchedule[i-15] >> 3)
		s1 :=
			rotateRight(messageSchedule[i-2], 17) ^
				rotateRight(messageSchedule[i-2], 19) ^
				(messageSchedule[i-2] >> 10)
		messageSchedule[i] =
			messageSchedule[i-16] +
				s0 +
				messageSchedule[i-7] +
				s1
	}

	a = context.state[0]
	b = context.state[1]
	c = context.state[2]
	d = context.state[3]
	e = context.state[4]
	f = context.state[5]
	g = context.state[6]
	h = context.state[7]

	for i := 0; i < 64; i++ {
		sum1 :=
			rotateRight(e, 6) ^
				rotateRight(e, 11) ^
				rotateRight(e, 25)
		choice := (e & f) ^ ((^e) & g)
		temp1 :=
			h +
				sum1 +
				choice +
				constants[i] +
				messageSchedule[i]
		sum0 :=
			rotateRight(a, 2) ^
				rotateRight(a, 13) ^
				rotateRight(a, 22)
		majority := (a & b) ^ (a & c) ^ (b & c)
		temp2 := sum0 + majority

		h = g
		g = f
		f = e
		e = d + temp1
		d = c
		c = b
		b = a
		a = temp1 + temp2
	}

	context.state[0] += a
	context.state[1] += b
	context.state[2] += c
	context.state[3] += d
	context.state[4] += e
	context.state[5] += f
	context.state[6] += g
	context.state[7] += h
}

func sha256Init() SHA256Context {
	return SHA256Context{
		state: [8]uint32{
			0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
			0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19,
		},
		bitCount:     0,
		bufferLength: 0,
	}
}

func sha256Update(context *SHA256Context, bytes []byte) {
	offset := 0

	context.bitCount += uint64(len(bytes)) * 8

	if context.bufferLength > 0 {
		copyLength := 64 - context.bufferLength
		if copyLength > len(bytes) {
			copyLength = len(bytes)
		}

		copy(context.buffer[context.bufferLength:], bytes[:copyLength])
		context.bufferLength += copyLength
		offset += copyLength

		if context.bufferLength == 64 {
			sha256Transform(context, context.buffer[:])
			context.bufferLength = 0
		}
	}

	for offset+64 <= len(bytes) {
		sha256Transform(context, bytes[offset:offset+64])
		offset += 64
	}

	if offset < len(bytes) {
		context.bufferLength = len(bytes) - offset
		copy(context.buffer[:], bytes[offset:])
	}
}

func sha256Final(context *SHA256Context) [32]byte {
	var digest [32]byte

	context.buffer[context.bufferLength] = 0x80
	context.bufferLength++

	if context.bufferLength > 56 {
		for i := context.bufferLength; i < 64; i++ {
			context.buffer[i] = 0
		}
		sha256Transform(context, context.buffer[:])
		context.bufferLength = 0
	}

	for i := context.bufferLength; i < 56; i++ {
		context.buffer[i] = 0
	}
	context.buffer[56] = byte(context.bitCount >> 56)
	context.buffer[57] = byte(context.bitCount >> 48)
	context.buffer[58] = byte(context.bitCount >> 40)
	context.buffer[59] = byte(context.bitCount >> 32)
	context.buffer[60] = byte(context.bitCount >> 24)
	context.buffer[61] = byte(context.bitCount >> 16)
	context.buffer[62] = byte(context.bitCount >> 8)
	context.buffer[63] = byte(context.bitCount)
	sha256Transform(context, context.buffer[:])

	for i := 0; i < 8; i++ {
		storeBE32(digest[:], i*4, context.state[i])
	}

	return digest
}

func formatDigest(digest [32]byte) string {
	return fmt.Sprintf("%x", digest)
}

func buildSourceBytes() ([]byte, uint64) {
	bytes := make([]byte, targetSize)
	state := uint32(0x12345678)

	for i := 0; i < targetSize; i++ {
		bytes[i] = byte(randomNext(&state) >> 24)
	}

	return bytes, fnv1aHash(bytes)
}

func hashSourceBytes(bytes []byte) [32]byte {
	context := sha256Init()
	offset := 0

	for offset < targetSize {
		length := chunkSize
		if length > targetSize-offset {
			length = targetSize - offset
		}

		sha256Update(&context, bytes[offset:offset+length])
		offset += length
	}

	return sha256Final(&context)
}

func buildBenchmarkData() BenchmarkData {
	sourceBytes, sourceHash := buildSourceBytes()

	if sourceHash != referenceSourceHash {
		fmt.Fprintf(
			os.Stderr,
			"Source hash mismatch: 0x%016x != 0x%016x\n",
			sourceHash,
			referenceSourceHash,
		)
		os.Exit(1)
	}

	digest := hashSourceBytes(sourceBytes)
	if digest != referenceDigest {
		fmt.Fprintf(
			os.Stderr,
			"Source digest mismatch: %s != "+
				"995e8c22a0da3f9e0120f69b09287a1692b9517f1a58bdcb"+
				"75eb4e1dce567f2b\n",
			formatDigest(digest),
		)
		os.Exit(1)
	}

	return BenchmarkData{
		sourceBytes: sourceBytes,
		sourceHash:  sourceHash,
		digest:      digest,
	}
}

func runBenchmark(data BenchmarkData, runs int) {
	for i := 0; i < runs; i++ {
		digest := hashSourceBytes(data.sourceBytes)

		if digest != data.digest {
			fmt.Fprintf(
				os.Stderr,
				"Digest mismatch: %s != %s\n",
				formatDigest(digest),
				formatDigest(data.digest),
			)
			os.Exit(1)
		}
	}
}

func main() {
	runs := 1
	if len(os.Args) > 1 {
		runs, _ = strconv.Atoi(os.Args[1])
	}
	data := buildBenchmarkData()
	_ = data.sourceHash

	start := time.Now()
	runBenchmark(data, runs)
	diff := time.Since(start)
	fmt.Fprintf(os.Stderr, "Go: %.3f s\n", diff.Seconds())
}
