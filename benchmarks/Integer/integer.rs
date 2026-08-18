use std::time::{SystemTime, UNIX_EPOCH};


const TARGET_SIZE: usize = 16 * 1024 * 1024;
const CHUNK_SIZE: usize = 4096;
const FNV_OFFSET: u64 = 14695981039346656037;
const FNV_PRIME: u64 = 1099511628211;
const REFERENCE_SOURCE_HASH: u64 = 0xc637e6db1fa57009;
const REFERENCE_DIGEST: [u8; 32] = [
	0x99, 0x5e, 0x8c, 0x22, 0xa0, 0xda, 0x3f, 0x9e,
	0x01, 0x20, 0xf6, 0x9b, 0x09, 0x28, 0x7a, 0x16,
	0x92, 0xb9, 0x51, 0x7f, 0x1a, 0x58, 0xbd, 0xcb,
	0x75, 0xeb, 0x4e, 0x1d, 0xce, 0x56, 0x7f, 0x2b
];


struct SHA256Context
{
	state: [u32; 8],
	bit_count: u64,
	buffer: [u8; 64],
	buffer_length: usize,
}


struct BenchmarkData
{
	source_bytes: Vec<u8>,
	source_hash: u64,
	digest: [u8; 32],
}


fn random_next ( state: &mut u32 ) -> u32
{
	*state = state.wrapping_mul(1664525).wrapping_add(1013904223);
	return *state;
}


fn fnv1a_hash ( bytes: &[u8] ) -> u64
{
	let mut hash = FNV_OFFSET;

	for byte in bytes {
		hash ^= *byte as u64;
		hash = hash.wrapping_mul(FNV_PRIME);
	}
	return hash;
}


fn rotate_right ( value: u32, amount: u32 ) -> u32
{
	return (value >> amount) | (value << (32 - amount));
}


fn load_be32 ( bytes: &[u8] ) -> u32
{
	return
		((bytes[0] as u32) << 24)
		| ((bytes[1] as u32) << 16)
		| ((bytes[2] as u32) << 8)
		| bytes[3] as u32;
}


fn store_be32 ( bytes: &mut [u8], value: u32 )
{
	bytes[0] = (value >> 24) as u8;
	bytes[1] = (value >> 16) as u8;
	bytes[2] = (value >> 8) as u8;
	bytes[3] = value as u8;
}


fn sha256_transform ( context: &mut SHA256Context, block: &[u8] )
{
	const CONSTANTS: [u32; 64] = [
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
	];
	let mut message_schedule = [0u32; 64];
	let mut a;
	let mut b;
	let mut c;
	let mut d;
	let mut e;
	let mut f;
	let mut g;
	let mut h;

	for i in 0..16 {
		message_schedule[i] = load_be32(&block[i * 4..i * 4 + 4]);
	}

	for i in 16..64 {
		let s0 =
			rotate_right(message_schedule[i - 15], 7) ^
			rotate_right(message_schedule[i - 15], 18) ^
			(message_schedule[i - 15] >> 3);
		let s1 =
			rotate_right(message_schedule[i - 2], 17) ^
			rotate_right(message_schedule[i - 2], 19) ^
			(message_schedule[i - 2] >> 10);
		message_schedule[i] =
			message_schedule[i - 16]
			.wrapping_add(s0)
			.wrapping_add(message_schedule[i - 7])
			.wrapping_add(s1);
	}

	a = context.state[0];
	b = context.state[1];
	c = context.state[2];
	d = context.state[3];
	e = context.state[4];
	f = context.state[5];
	g = context.state[6];
	h = context.state[7];

	for i in 0..64 {
		let sum1 =
			rotate_right(e, 6) ^
			rotate_right(e, 11) ^
			rotate_right(e, 25);
		let choice = (e & f) ^ ((!e) & g);
		let temp1 = h
			.wrapping_add(sum1)
			.wrapping_add(choice)
			.wrapping_add(CONSTANTS[i])
			.wrapping_add(message_schedule[i]);
		let sum0 =
			rotate_right(a, 2) ^
			rotate_right(a, 13) ^
			rotate_right(a, 22);
		let majority = (a & b) ^ (a & c) ^ (b & c);
		let temp2 = sum0.wrapping_add(majority);

		h = g;
		g = f;
		f = e;
		e = d.wrapping_add(temp1);
		d = c;
		c = b;
		b = a;
		a = temp1.wrapping_add(temp2);
	}

	context.state[0] = context.state[0].wrapping_add(a);
	context.state[1] = context.state[1].wrapping_add(b);
	context.state[2] = context.state[2].wrapping_add(c);
	context.state[3] = context.state[3].wrapping_add(d);
	context.state[4] = context.state[4].wrapping_add(e);
	context.state[5] = context.state[5].wrapping_add(f);
	context.state[6] = context.state[6].wrapping_add(g);
	context.state[7] = context.state[7].wrapping_add(h);
}


fn sha256_init ( ) -> SHA256Context
{
	return SHA256Context {
		state: [
			0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
			0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19
		],
		bit_count: 0,
		buffer: [0u8; 64],
		buffer_length: 0,
	};
}


fn sha256_update (
	context: &mut SHA256Context,
	bytes: &[u8] )
{
	let mut offset = 0usize;

	context.bit_count = context.bit_count.wrapping_add(
		(bytes.len() as u64) * 8
	);

	if context.buffer_length > 0 {
		let mut copy_length = 64 - context.buffer_length;

		if copy_length > bytes.len() {
			copy_length = bytes.len();
		}

		context.buffer[context.buffer_length..context.buffer_length
			+ copy_length]
			.copy_from_slice(&bytes[..copy_length]);
		context.buffer_length += copy_length;
		offset += copy_length;

		if context.buffer_length == 64 {
			let block = context.buffer;
			sha256_transform(context, &block);
			context.buffer_length = 0;
		}
	}

	while offset + 64 <= bytes.len() {
		sha256_transform(context, &bytes[offset..offset + 64]);
		offset += 64;
	}

	if offset < bytes.len() {
		context.buffer_length = bytes.len() - offset;
		context.buffer[..context.buffer_length]
			.copy_from_slice(&bytes[offset..]);
	}
}


fn sha256_final ( context: &mut SHA256Context ) -> [u8; 32]
{
	let mut digest = [0u8; 32];

	context.buffer[context.buffer_length] = 0x80;
	context.buffer_length += 1;

	if context.buffer_length > 56 {
		for i in context.buffer_length..64 {
			context.buffer[i] = 0;
		}
		let block = context.buffer;
		sha256_transform(context, &block);
		context.buffer_length = 0;
	}

	for i in context.buffer_length..56 {
		context.buffer[i] = 0;
	}
	context.buffer[56] = (context.bit_count >> 56) as u8;
	context.buffer[57] = (context.bit_count >> 48) as u8;
	context.buffer[58] = (context.bit_count >> 40) as u8;
	context.buffer[59] = (context.bit_count >> 32) as u8;
	context.buffer[60] = (context.bit_count >> 24) as u8;
	context.buffer[61] = (context.bit_count >> 16) as u8;
	context.buffer[62] = (context.bit_count >> 8) as u8;
	context.buffer[63] = context.bit_count as u8;
	let block = context.buffer;
	sha256_transform(context, &block);

	for i in 0..8 {
		store_be32(&mut digest[i * 4..i * 4 + 4], context.state[i]);
	}

	return digest;
}


fn format_digest ( digest: &[u8; 32] ) -> String
{
	let mut text = String::with_capacity(64);

	for byte in digest {
		text.push_str(&format!("{:02x}", byte));
	}
	return text;
}


fn build_source_bytes ( ) -> (Vec<u8>, u64)
{
	let mut bytes = vec![0u8; TARGET_SIZE];
	let mut state = 0x12345678u32;

	for i in 0..TARGET_SIZE {
		bytes[i] = (random_next(&mut state) >> 24) as u8;
	}

	let hash = fnv1a_hash(&bytes);
	return (bytes, hash);
}


fn hash_source_bytes ( bytes: &[u8] ) -> [u8; 32]
{
	let mut context = sha256_init();
	let mut offset = 0usize;

	while offset < TARGET_SIZE {
		let mut length = CHUNK_SIZE;

		if length > TARGET_SIZE - offset {
			length = TARGET_SIZE - offset;
		}

		sha256_update(&mut context, &bytes[offset..offset + length]);
		offset += length;
	}

	return sha256_final(&mut context);
}


fn build_benchmark_data ( ) -> BenchmarkData
{
	let (source_bytes, source_hash) = build_source_bytes();

	if source_hash != REFERENCE_SOURCE_HASH {
		eprintln!(
			"Source hash mismatch: 0x{:016x} != 0x{:016x}",
			source_hash,
			REFERENCE_SOURCE_HASH
		);
		std::process::exit(1);
	}

	let digest = hash_source_bytes(&source_bytes);
	if digest != REFERENCE_DIGEST {
		eprintln!(
			"Source digest mismatch: {} != \
995e8c22a0da3f9e0120f69b09287a1692b9517f1a58bdcb75eb4e1dce567f2b",
			format_digest(&digest)
		);
		std::process::exit(1);
	}

	return BenchmarkData {
		source_bytes,
		source_hash,
		digest,
	};
}


fn run_benchmark ( data: &BenchmarkData, runs: i32 )
{
	for _ in 0..runs {
		let digest = hash_source_bytes(&data.source_bytes);

		if digest != data.digest {
			eprintln!(
				"Digest mismatch: {} != {}",
				format_digest(&digest),
				format_digest(&data.digest)
			);
			std::process::exit(1);
		}
	}
}


fn main ( )
{
	let args: Vec<String> = std::env::args().collect();
	let runs = if args.len() <= 1 {
		1
	} else {
		args[1].parse::<i32>().unwrap_or(1)
	};
	let data = build_benchmark_data();

	let _ = data.source_hash;
	let start = SystemTime::now();
	run_benchmark(&data, runs);
	let end = SystemTime::now();
	let elapsed = end.duration_since(UNIX_EPOCH).unwrap().as_secs_f64()
		- start.duration_since(UNIX_EPOCH).unwrap().as_secs_f64();
	eprintln!("Rust: {:.3} s", elapsed);
}
