local TARGET_SIZE = 16 * 1024 * 1024
local CHUNK_SIZE = 4096
local FNV_OFFSET_HI = 0xcbf29ce4
local FNV_OFFSET_LO = 0x84222325
local FNV_PRIME_SMALL = 0x1b3
local REFERENCE_HASH_HI = 0xc637e6db
local REFERENCE_HASH_LO = 0x1fa57009
local REFERENCE_DIGEST = {
	0x99, 0x5e, 0x8c, 0x22, 0xa0, 0xda, 0x3f, 0x9e,
	0x01, 0x20, 0xf6, 0x9b, 0x09, 0x28, 0x7a, 0x16,
	0x92, 0xb9, 0x51, 0x7f, 0x1a, 0x58, 0xbd, 0xcb,
	0x75, 0xeb, 0x4e, 0x1d, 0xce, 0x56, 0x7f, 0x2b
}
local SHA256_CONSTANTS = {
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
}

function random_next(state)
	state.value = (state.value * 1664525 + 1013904223) % 4294967296
	return state.value
end

function multiply_hash(hi, lo)
	local low_product = lo * FNV_PRIME_SMALL
	local new_lo = low_product % 4294967296
	local carry = math.floor(low_product / 4294967296)
	local high_product =
		hi * FNV_PRIME_SMALL + carry + ((lo * 256) % 4294967296)
	local new_hi = high_product % 4294967296
	return new_hi, new_lo
end

function fnv1a_hash(source_bytes)
	local hash_hi = FNV_OFFSET_HI
	local hash_lo = FNV_OFFSET_LO

	for i = 1, #source_bytes do
		hash_lo = (hash_lo ~ string.byte(source_bytes, i)) % 4294967296
		hash_hi, hash_lo = multiply_hash(hash_hi, hash_lo)
	end

	return hash_hi, hash_lo
end

function rotate_right(value, amount)
	return ((value >> amount) | (value << (32 - amount))) & 0xffffffff
end

function load_be32(source_bytes, offset)
	local index = offset + 1
	return (
		(string.byte(source_bytes, index) << 24)
		| (string.byte(source_bytes, index + 1) << 16)
		| (string.byte(source_bytes, index + 2) << 8)
		| string.byte(source_bytes, index + 3)
	) & 0xffffffff
end

function store_be32(parts, offset, value)
	local index = offset + 1
	parts[index] = string.char((value >> 24) & 0xff)
	parts[index + 1] = string.char((value >> 16) & 0xff)
	parts[index + 2] = string.char((value >> 8) & 0xff)
	parts[index + 3] = string.char(value & 0xff)
end

function create_context()
	local state = {
		0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
		0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19
	}
	local message_schedule = {}
	local buffer = {}

	for i = 1, 64 do
		message_schedule[i] = 0
		buffer[i] = string.char(0)
	end

	return {
		state = state,
		message_schedule = message_schedule,
		bit_count = 0,
		buffer = buffer,
		buffer_length = 0
	}
end

function context_buffer_string(context)
	return table.concat(context.buffer)
end

function sha256_transform(context, block, block_offset)
	for i = 1, 16 do
		context.message_schedule[i] = load_be32(
			block,
			block_offset + (i - 1) * 4
		)
	end

	for i = 17, 64 do
		local s0 =
			rotate_right(context.message_schedule[i - 15], 7) ~
			rotate_right(context.message_schedule[i - 15], 18) ~
			(context.message_schedule[i - 15] >> 3)
		local s1 =
			rotate_right(context.message_schedule[i - 2], 17) ~
			rotate_right(context.message_schedule[i - 2], 19) ~
			(context.message_schedule[i - 2] >> 10)
		context.message_schedule[i] = (
			context.message_schedule[i - 16] +
			s0 +
			context.message_schedule[i - 7] +
			s1
		) & 0xffffffff
	end

	local a = context.state[1]
	local b = context.state[2]
	local c = context.state[3]
	local d = context.state[4]
	local e = context.state[5]
	local f = context.state[6]
	local g = context.state[7]
	local h = context.state[8]

	for i = 1, 64 do
		local sum1 =
			rotate_right(e, 6) ~
			rotate_right(e, 11) ~
			rotate_right(e, 25)
		local choice = (e & f) ~ ((~e) & g)
		local temp1 = (
			h +
			sum1 +
			choice +
			SHA256_CONSTANTS[i] +
			context.message_schedule[i]
		) & 0xffffffff
		local sum0 =
			rotate_right(a, 2) ~
			rotate_right(a, 13) ~
			rotate_right(a, 22)
		local majority = (a & b) ~ (a & c) ~ (b & c)
		local temp2 = (sum0 + majority) & 0xffffffff

		h = g
		g = f
		f = e
		e = (d + temp1) & 0xffffffff
		d = c
		c = b
		b = a
		a = (temp1 + temp2) & 0xffffffff
	end

	context.state[1] = (context.state[1] + a) & 0xffffffff
	context.state[2] = (context.state[2] + b) & 0xffffffff
	context.state[3] = (context.state[3] + c) & 0xffffffff
	context.state[4] = (context.state[4] + d) & 0xffffffff
	context.state[5] = (context.state[5] + e) & 0xffffffff
	context.state[6] = (context.state[6] + f) & 0xffffffff
	context.state[7] = (context.state[7] + g) & 0xffffffff
	context.state[8] = (context.state[8] + h) & 0xffffffff
end

function sha256_update(context, source_bytes, start, length)
	local offset = start
	local finish = start + length

	context.bit_count = context.bit_count + length * 8

	if context.buffer_length > 0 then
		local copy_length = 64 - context.buffer_length

		if copy_length > finish - offset then
			copy_length = finish - offset
		end

		for i = 0, copy_length - 1 do
			context.buffer[context.buffer_length + i + 1] =
				string.sub(source_bytes, offset + i + 1, offset + i + 1)
		end
		context.buffer_length = context.buffer_length + copy_length
		offset = offset + copy_length

		if context.buffer_length == 64 then
			sha256_transform(context, context_buffer_string(context), 0)
			context.buffer_length = 0
		end
	end

	while offset + 64 <= finish do
		sha256_transform(context, source_bytes, offset)
		offset = offset + 64
	end

	if offset < finish then
		context.buffer_length = finish - offset
		for i = 0, context.buffer_length - 1 do
			context.buffer[i + 1] =
				string.sub(source_bytes, offset + i + 1, offset + i + 1)
		end
	end
end

function sha256_final(context)
	local digest_parts = {}

	context.buffer[context.buffer_length + 1] = string.char(0x80)
	context.buffer_length = context.buffer_length + 1

	if context.buffer_length > 56 then
		for i = context.buffer_length + 1, 64 do
			context.buffer[i] = string.char(0)
		end
		sha256_transform(context, context_buffer_string(context), 0)
		context.buffer_length = 0
	end

	for i = context.buffer_length + 1, 56 do
		context.buffer[i] = string.char(0)
	end

	local bit_count = context.bit_count
	context.buffer[57] = string.char((bit_count >> 56) & 0xff)
	context.buffer[58] = string.char((bit_count >> 48) & 0xff)
	context.buffer[59] = string.char((bit_count >> 40) & 0xff)
	context.buffer[60] = string.char((bit_count >> 32) & 0xff)
	context.buffer[61] = string.char((bit_count >> 24) & 0xff)
	context.buffer[62] = string.char((bit_count >> 16) & 0xff)
	context.buffer[63] = string.char((bit_count >> 8) & 0xff)
	context.buffer[64] = string.char(bit_count & 0xff)
	sha256_transform(context, context_buffer_string(context), 0)

	for i = 1, 32 do
		digest_parts[i] = string.char(0)
	end

	for i = 1, 8 do
		store_be32(digest_parts, (i - 1) * 4, context.state[i])
	end

	return table.concat(digest_parts)
end

function equal_digest(digest, reference_digest)
	if #digest ~= #reference_digest then
		return false
	end

	for i = 1, #digest do
		if string.byte(digest, i) ~= reference_digest[i] then
			return false
		end
	end

	return true
end

function digest_hex(digest)
	local parts = {}

	for i = 1, #digest do
		parts[i] = string.format("%02x", string.byte(digest, i))
	end
	return table.concat(parts)
end

function build_source_bytes()
	local parts = {}
	local state = { value = 0x12345678 }

	for i = 1, TARGET_SIZE do
		parts[i] = string.char(random_next(state) >> 24)
	end

	local source_bytes = table.concat(parts)
	local hash_hi, hash_lo = fnv1a_hash(source_bytes)
	return source_bytes, hash_hi, hash_lo
end

function hash_source_bytes(source_bytes)
	local context = create_context()
	local offset = 0

	while offset < TARGET_SIZE do
		local length = CHUNK_SIZE

		if length > TARGET_SIZE - offset then
			length = TARGET_SIZE - offset
		end

		sha256_update(context, source_bytes, offset, length)
		offset = offset + length
	end

	return sha256_final(context)
end

function build_benchmark_data()
	local source_bytes, source_hash_hi, source_hash_lo = build_source_bytes()

	if (
		source_hash_hi ~= REFERENCE_HASH_HI or
		source_hash_lo ~= REFERENCE_HASH_LO
	) then
		io.stderr:write(
			"Source hash mismatch: "
			.. string.format("0x%08x%08x", source_hash_hi, source_hash_lo)
			.. " != "
			.. string.format("0x%08x%08x", REFERENCE_HASH_HI, REFERENCE_HASH_LO)
			.. "\n"
		)
		os.exit(1)
	end

	local digest = hash_source_bytes(source_bytes)
	if not equal_digest(digest, REFERENCE_DIGEST) then
		io.stderr:write(
			"Source digest mismatch: "
			.. digest_hex(digest)
			.. " != "
			.. "995e8c22a0da3f9e0120f69b09287a1692b9517f1a58bdcb"
			.. "75eb4e1dce567f2b\n"
		)
		os.exit(1)
	end

	return source_bytes, source_hash_hi, source_hash_lo, digest
end

function run_benchmark(source_bytes, digest, runs)
	for _i = 1, runs do
		local current_digest = hash_source_bytes(source_bytes)

		if current_digest ~= digest then
			io.stderr:write(
				"Digest mismatch: "
				.. digest_hex(current_digest)
				.. " != "
				.. digest_hex(digest)
				.. "\n"
			)
			os.exit(1)
		end
	end
end

local runs = 1
if arg[1] ~= nil then
	runs = tonumber(arg[1]) or 1
end

local source_bytes, source_hash_hi, source_hash_lo, digest =
	build_benchmark_data()
local t = os.clock()
run_benchmark(source_bytes, digest, runs)
local diff = os.clock() - t
io.stderr:write(string.format("Lua: %.3f s\n", diff))
