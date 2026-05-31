#!/usr/bin/ruby

TARGET_SIZE = 1024 * 1024
WORD_COUNT = 16
LINE_LIMIT = 80
FNV_OFFSET = 14695981039346656037
FNV_PRIME = 1099511628211
REFERENCE_HASH = 0x35ce3126ab961070
MASK = (1 << 64) - 1

def random_next(state)
	state[0] = (state[0] * 1664525 + 1013904223) & 0xffffffff
	return state[0]
end

def hash_bytes(text)
	hash = FNV_OFFSET

	text.each_byte do |byte|
		hash ^= byte
		hash = (hash * FNV_PRIME) & MASK
	end
	return hash
end

def build_source_text(words)
	parts = []
	length = 0
	word_count = 0
	state = [0x12345678]

	while (1)
		word = words[random_next(state) % WORD_COUNT]
		if word_count > 0
			parts << " "
			length += 1
		end
		parts << word
		length += word.length
		word_count += 1
		break if (length > TARGET_SIZE)
	end

	text = parts.join
	return text, word_count, hash_bytes(text)
end

def wrap_words(words)
	parts = []
	line_length = 0

	for i in 0...words.length do
		word = words[i]
		word_length = word.length

		if i == 0
			parts << word
			line_length = word_length
			next
		end

		if line_length + 1 + word_length >= LINE_LIMIT
			parts << "\n"
			parts << word
			line_length = word_length
		else
			parts << " "
			parts << word
			line_length += 1 + word_length
		end
	end

	return parts.join
end

def hash_wrapped_text(text)
	hash = FNV_OFFSET
	lines = text.split("\n", -1)

	for i in 0...lines.length do
		if i > 0
			hash ^= 32
			hash = (hash * FNV_PRIME) & MASK
		end

		lines[i].each_byte do |byte|
			hash ^= byte
			hash = (hash * FNV_PRIME) & MASK
		end
	end

	return hash
end

def run_benchmark(source_text, source_hash, runs)
	for i in 0...runs do
		split_words = source_text.split(" ")
		wrapped_text = wrap_words(split_words)
		wrapped_hash = hash_wrapped_text(wrapped_text)

		if wrapped_hash != source_hash
			$stderr.puts(
				"Hash mismatch: 0x%016x != 0x%016x" %
				[wrapped_hash, source_hash]
			)
			exit(1)
		end
	end
end

words = [
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
]

if (ARGV.length == 0)
	runs = 1
else
	runs = Integer(ARGV[0])
end

source_text, source_word_count, source_hash = build_source_text(words)
if source_hash != REFERENCE_HASH
	$stderr.puts(
		"Source hash mismatch: 0x%016x != 0x%016x" %
		[source_hash, REFERENCE_HASH]
	)
	exit(1)
end

time = Time.now
run_benchmark(source_text, source_hash, runs)
diff = Time.now - time
$stderr.printf "Ruby Elapsed %.2f\n" % diff
