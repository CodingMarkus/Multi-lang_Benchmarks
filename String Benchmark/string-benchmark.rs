use std::io::{BufRead, BufReader};
use std::time::{SystemTime, UNIX_EPOCH};


const TARGET_SIZE: usize = 1024 * 1024;
const WORD_COUNT: usize = 16;
const LINE_LIMIT: usize = 80;
const FNV_OFFSET: u64 = 14695981039346656037;
const FNV_PRIME: u64 = 1099511628211;
const REFERENCE_HASH: u64 = 0x35ce3126ab961070;


fn random_next ( state: &mut u32 ) -> u32
{
	*state = state.wrapping_mul(1664525).wrapping_add(1013904223);
	return *state;
}


fn hash_bytes ( text: &[u8] ) -> u64
{
	let mut hash = FNV_OFFSET;

	for byte in text {
		hash ^= *byte as u64;
		hash = hash.wrapping_mul(FNV_PRIME);
	}
	return hash;
}


fn build_source_text ( words: &[&str] ) -> (String, usize, u64)
{
	let mut text = String::with_capacity(TARGET_SIZE + 64);
	let mut word_count = 0;
	let mut state = 0x12345678u32;

	loop {
		let index = random_next(&mut state) as usize % WORD_COUNT;
		let word = words[index];

		if word_count > 0 {
			text.push(' ');
		}

		text.push_str(word);
		word_count += 1;

		if text.len() > TARGET_SIZE {
			break;
		}
	}

	let hash = hash_bytes(text.as_bytes());
	return (text, word_count, hash);
}


fn wrap_words ( words: &Vec<&str> ) -> String
{
	let mut text = String::with_capacity(TARGET_SIZE + 64);
	let mut line_length = 0;

	for i in 0..words.len() {
		let word = words[i];
		let word_length = word.len();

		if i == 0 {
			text.push_str(word);
			line_length = word_length;
			continue;
		}

		if line_length + 1 + word_length >= LINE_LIMIT {
			text.push('\n');
			text.push_str(word);
			line_length = word_length;
		} else {
			text.push(' ');
			text.push_str(word);
			line_length += 1 + word_length;
		}
	}

	return text;
}


fn hash_wrapped_text ( text: &str ) -> u64
{
	let mut hash = FNV_OFFSET;
	let reader = BufReader::new(text.as_bytes());
	let mut first = true;

	for line in reader.lines() {
		if !first {
			hash ^= b' ' as u64;
			hash = hash.wrapping_mul(FNV_PRIME);
		}
		first = false;

		for byte in line.unwrap().as_bytes() {
			hash ^= *byte as u64;
			hash = hash.wrapping_mul(FNV_PRIME);
		}
	}

	return hash;
}


fn run_benchmark ( source_text: &String, source_hash: u64, runs: i32 )
{
	for _ in 0..runs {
		let split_buffer = source_text.clone();
		let split_words: Vec<&str> = split_buffer.split(' ').collect();
		let wrapped_text = wrap_words(&split_words);
		let wrapped_hash = hash_wrapped_text(&wrapped_text);

		if wrapped_hash != source_hash {
			eprintln!(
				"Hash mismatch: 0x{:016x} != 0x{:016x}",
				wrapped_hash,
				source_hash
			);
			std::process::exit(1);
		}
	}
}


fn main ( )
{
	let words = [
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
	];
	let args: Vec<String> = std::env::args().collect();
	let runs = if args.len() <= 1 {
		1
	} else {
		args[1].parse::<i32>().unwrap_or(1)
	};
	let (source_text, _, source_hash) = build_source_text(&words);

	if source_hash != REFERENCE_HASH {
		eprintln!(
			"Source hash mismatch: 0x{:016x} != 0x{:016x}",
			source_hash,
			REFERENCE_HASH
		);
		std::process::exit(1);
	}

	let start = SystemTime::now();
	run_benchmark(&source_text, source_hash, runs);
	let end = SystemTime::now();
	let elapsed = end.duration_since(UNIX_EPOCH).unwrap().as_secs_f64()
		- start.duration_since(UNIX_EPOCH).unwrap().as_secs_f64();
	eprintln!("Rust Elapsed {:.2}", elapsed);
}
