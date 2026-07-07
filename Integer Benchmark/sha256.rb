#!/usr/bin/ruby

TARGET_SIZE = 16 * 1024 * 1024
CHUNK_SIZE = 4096
FNV_OFFSET = 14695981039346656037
FNV_PRIME = 1099511628211
MASK_64 = (1 << 64) - 1
MASK_32 = (1 << 32) - 1
REFERENCE_SOURCE_HASH = 0xc637e6db1fa57009
REFERENCE_DIGEST = [
	0x99, 0x5e, 0x8c, 0x22, 0xa0, 0xda, 0x3f, 0x9e,
	0x01, 0x20, 0xf6, 0x9b, 0x09, 0x28, 0x7a, 0x16,
	0x92, 0xb9, 0x51, 0x7f, 0x1a, 0x58, 0xbd, 0xcb,
	0x75, 0xeb, 0x4e, 0x1d, 0xce, 0x56, 0x7f, 0x2b
]
SHA256_CONSTANTS = [
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

def random_next(state)
	state[0] = (state[0] * 1664525 + 1013904223) & MASK_32
	return state[0]
end

def fnv1a_hash(source_bytes)
	hash = FNV_OFFSET

	source_bytes.each_byte do |byte|
		hash ^= byte
		hash = (hash * FNV_PRIME) & MASK_64
	end
	return hash
end

def rotate_right(value, amount)
	return ((value >> amount) | (value << (32 - amount))) & MASK_32
end

def load_be32(source_bytes, offset)
	return (
		(source_bytes.getbyte(offset) << 24) |
		(source_bytes.getbyte(offset + 1) << 16) |
		(source_bytes.getbyte(offset + 2) << 8) |
		source_bytes.getbyte(offset + 3)
	)
end

def store_be32(target_bytes, offset, value)
	target_bytes.setbyte(offset, (value >> 24) & 0xff)
	target_bytes.setbyte(offset + 1, (value >> 16) & 0xff)
	target_bytes.setbyte(offset + 2, (value >> 8) & 0xff)
	target_bytes.setbyte(offset + 3, value & 0xff)
end

def create_context
	return {
		state: [
			0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
			0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19
		],
		message_schedule: Array.new(64, 0),
		bit_count: 0,
		buffer: "\x00" * 64,
		buffer_length: 0
	}
end

def sha256_transform(context, block, block_offset)
	message_schedule = context[:message_schedule]

	for i in 0...16 do
		message_schedule[i] = load_be32(block, block_offset + i * 4)
	end

	for i in 16...64 do
		s0 =
			rotate_right(message_schedule[i - 15], 7) ^
			rotate_right(message_schedule[i - 15], 18) ^
			(message_schedule[i - 15] >> 3)
		s1 =
			rotate_right(message_schedule[i - 2], 17) ^
			rotate_right(message_schedule[i - 2], 19) ^
			(message_schedule[i - 2] >> 10)
		message_schedule[i] = (
			message_schedule[i - 16] +
			s0 +
			message_schedule[i - 7] +
			s1
		) & MASK_32
	end

	a, b, c, d, e, f, g, h = context[:state]

	for i in 0...64 do
		sum1 =
			rotate_right(e, 6) ^
			rotate_right(e, 11) ^
			rotate_right(e, 25)
		choice = (e & f) ^ ((~e) & g)
		temp1 = (
			h +
			sum1 +
			choice +
			SHA256_CONSTANTS[i] +
			message_schedule[i]
		) & MASK_32
		sum0 =
			rotate_right(a, 2) ^
			rotate_right(a, 13) ^
			rotate_right(a, 22)
		majority = (a & b) ^ (a & c) ^ (b & c)
		temp2 = (sum0 + majority) & MASK_32

		h = g
		g = f
		f = e
		e = (d + temp1) & MASK_32
		d = c
		c = b
		b = a
		a = (temp1 + temp2) & MASK_32
	end

	context[:state][0] = (context[:state][0] + a) & MASK_32
	context[:state][1] = (context[:state][1] + b) & MASK_32
	context[:state][2] = (context[:state][2] + c) & MASK_32
	context[:state][3] = (context[:state][3] + d) & MASK_32
	context[:state][4] = (context[:state][4] + e) & MASK_32
	context[:state][5] = (context[:state][5] + f) & MASK_32
	context[:state][6] = (context[:state][6] + g) & MASK_32
	context[:state][7] = (context[:state][7] + h) & MASK_32
end

def sha256_update(context, source_bytes, start, length)
	offset = start
	finish = start + length

	context[:bit_count] += length * 8

	if context[:buffer_length] > 0
		copy_length = 64 - context[:buffer_length]

		if copy_length > finish - offset
			copy_length = finish - offset
		end

		for i in 0...copy_length do
			context[:buffer].setbyte(
				context[:buffer_length] + i,
				source_bytes.getbyte(offset + i)
			)
		end
		context[:buffer_length] += copy_length
		offset += copy_length

		if context[:buffer_length] == 64
			sha256_transform(context, context[:buffer], 0)
			context[:buffer_length] = 0
		end
	end

	while offset + 64 <= finish
		sha256_transform(context, source_bytes, offset)
		offset += 64
	end

	if offset < finish
		context[:buffer_length] = finish - offset
		for i in 0...context[:buffer_length] do
			context[:buffer].setbyte(i, source_bytes.getbyte(offset + i))
		end
	end
end

def sha256_final(context)
	digest = "\x00" * 32
	context[:buffer].setbyte(context[:buffer_length], 0x80)
	context[:buffer_length] += 1

	if context[:buffer_length] > 56
		for i in context[:buffer_length]...64 do
			context[:buffer].setbyte(i, 0)
		end
		sha256_transform(context, context[:buffer], 0)
		context[:buffer_length] = 0
	end

	for i in context[:buffer_length]...56 do
		context[:buffer].setbyte(i, 0)
	end

	bit_count = context[:bit_count]
	context[:buffer].setbyte(56, (bit_count >> 56) & 0xff)
	context[:buffer].setbyte(57, (bit_count >> 48) & 0xff)
	context[:buffer].setbyte(58, (bit_count >> 40) & 0xff)
	context[:buffer].setbyte(59, (bit_count >> 32) & 0xff)
	context[:buffer].setbyte(60, (bit_count >> 24) & 0xff)
	context[:buffer].setbyte(61, (bit_count >> 16) & 0xff)
	context[:buffer].setbyte(62, (bit_count >> 8) & 0xff)
	context[:buffer].setbyte(63, bit_count & 0xff)
	sha256_transform(context, context[:buffer], 0)

	for i in 0...8 do
		store_be32(digest, i * 4, context[:state][i])
	end

	return digest
end

def build_source_bytes
	source_bytes = "\x00" * TARGET_SIZE
	state = [0x12345678]

	for i in 0...TARGET_SIZE do
		source_bytes.setbyte(i, random_next(state) >> 24)
	end

	return source_bytes, fnv1a_hash(source_bytes)
end

def hash_source_bytes(source_bytes)
	context = create_context
	offset = 0

	while offset < TARGET_SIZE
		length = CHUNK_SIZE

		if length > TARGET_SIZE - offset
			length = TARGET_SIZE - offset
		end

		sha256_update(context, source_bytes, offset, length)
		offset += length
	end

	return sha256_final(context)
end

def build_benchmark_data
	source_bytes, source_hash = build_source_bytes

	if source_hash != REFERENCE_SOURCE_HASH
		$stderr.puts(
			"Source hash mismatch: 0x%016x != 0x%016x" %
			[source_hash, REFERENCE_SOURCE_HASH]
		)
		exit(1)
	end

	digest = hash_source_bytes(source_bytes)
	if digest.bytes != REFERENCE_DIGEST
		$stderr.puts(
			"Source digest mismatch: #{digest.unpack1('H*')} != " +
			"995e8c22a0da3f9e0120f69b09287a1692b9517f1a58bdcb" +
			"75eb4e1dce567f2b"
		)
		exit(1)
	end

	return source_bytes, source_hash, digest
end

def run_benchmark(source_bytes, digest, runs)
	for _i in 0...runs do
		current_digest = hash_source_bytes(source_bytes)

		if current_digest != digest
			$stderr.puts(
				"Digest mismatch: #{current_digest.unpack1('H*')} != " +
				digest.unpack1('H*')
			)
			exit(1)
		end
	end
end

runs = ARGV.length == 0 ? 1 : Integer(ARGV[0])
source_bytes, source_hash, digest = build_benchmark_data
time = Time.now
run_benchmark(source_bytes, digest, runs)
diff = Time.now - time
$stderr.printf "Ruby Elapsed %.3f\n" % diff
