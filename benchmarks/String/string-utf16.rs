use std::time::{SystemTime, UNIX_EPOCH};


const TARGET_SIZE: usize = 1024 * 1024;
const WORD_COUNT: usize = 16;
const LINE_LIMIT: usize = 80;
const FNV_OFFSET: u64 = 14695981039346656037;
const FNV_PRIME: u64 = 1099511628211;
const REFERENCE_HASH: u64 = 0xc96d7fcba133ffd5;


struct BenchmarkData
{
	source_text: Vec<u16>,
	source_length: usize,
	source_word_count: usize,
	source_hash: u64
}


fn random_next ( state: &mut u32 ) -> u32
{
	*state = state.wrapping_mul(1664525).wrapping_add(1013904223);
	return *state;
}


fn hash_utf16 ( text: &[u16] ) -> u64
{
	let mut hash = FNV_OFFSET;

	for code_unit in text {
		hash ^= *code_unit as u64;
		hash = hash.wrapping_mul(FNV_PRIME);
	}
	return hash;
}


fn build_benchmark_data ( ) -> BenchmarkData
{
	let words = [
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
	let mut text = Vec::with_capacity(TARGET_SIZE + 64);
	let mut generated_word_count = 0;
	let mut state = 0x12345678u32;

	loop {
		let index = random_next(&mut state) as usize % WORD_COUNT;
		let word = words[index];

		if generated_word_count > 0 {
			text.push(b' ' as u16);
		}

		for code_unit in word.encode_utf16() {
			text.push(code_unit);
		}

		generated_word_count += 1;
		if text.len() > TARGET_SIZE {
			break;
		}
	}

	let data = BenchmarkData {
		source_hash: hash_utf16(&text),
		source_length: text.len(),
		source_text: text,
		source_word_count: generated_word_count
	};

	if data.source_hash != REFERENCE_HASH {
		eprintln!(
			"Source hash mismatch: 0x{:016x} != 0x{:016x}",
			data.source_hash,
			REFERENCE_HASH
		);
		std::process::exit(1);
	}

	return data;
}


fn split_words ( text: &mut [u16], words: &mut Vec<(usize, usize)> )
{
	let mut index = 0;

	words.clear();

	while index < text.len() {
		let start = index;

		while index < text.len() && text[index] != b' ' as u16 {
			index += 1;
		}

		words.push((start, index - start));

		if index == text.len() {
			break;
		}

		text[index] = 0;
		index += 1;
	}
}


fn wrap_words ( text: &[u16], words: &[(usize, usize)] ) -> Vec<u16>
{
	let mut wrapped = Vec::with_capacity(TARGET_SIZE + 64);
	let mut line_length = 0;

	for i in 0..words.len() {
		let (start, word_length) = words[i];

		if i == 0 {
			wrapped.extend_from_slice(
				&text[start .. start + word_length]
			);
			line_length = word_length;
			continue;
		}

		if line_length + 1 + word_length >= LINE_LIMIT {
			wrapped.push(b'\n' as u16);
			wrapped.extend_from_slice(
				&text[start .. start + word_length]
			);
			line_length = word_length;
		} else {
			wrapped.push(b' ' as u16);
			wrapped.extend_from_slice(
				&text[start .. start + word_length]
			);
			line_length += 1 + word_length;
		}
	}

	return wrapped;
}


fn hash_wrapped_text ( text: &[u16] ) -> u64
{
	let mut hash = FNV_OFFSET;

	for code_unit in text {
		if *code_unit == b'\n' as u16 {
			hash ^= b' ' as u64;
		} else {
			hash ^= *code_unit as u64;
		}
		hash = hash.wrapping_mul(FNV_PRIME);
	}

	return hash;
}


fn run_benchmark ( data: &BenchmarkData, runs: i32 )
{
	let mut split_words_buffer = Vec::with_capacity(data.source_word_count);

	for _ in 0..runs {
		let mut split_buffer = data.source_text.clone();
		let wrapped_text;
		let wrapped_hash;

		split_words(&mut split_buffer, &mut split_words_buffer);
		wrapped_text = wrap_words(&split_buffer, &split_words_buffer);
		wrapped_hash = hash_wrapped_text(&wrapped_text);

		if wrapped_hash != data.source_hash {
			eprintln!(
				"Hash mismatch: 0x{:016x} != 0x{:016x}",
				wrapped_hash,
				data.source_hash
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
	let start = SystemTime::now();

	if data.source_length != data.source_text.len() {
		eprintln!("Source length mismatch.");
		std::process::exit(1);
	}

	run_benchmark(&data, runs);

	let end = SystemTime::now();
	let elapsed = end.duration_since(UNIX_EPOCH).unwrap().as_secs_f64()
		- start.duration_since(UNIX_EPOCH).unwrap().as_secs_f64();
	eprintln!("Rust UTF-16: {:.3} s", elapsed);
}
