#!/usr/bin/python

import sys, time

MASK = (1 << 64) - 1
TARGET_SIZE = 1024 * 1024
WORD_COUNT = 16
LINE_LIMIT = 80
FNV_OFFSET = 14695981039346656037
FNV_PRIME = 1099511628211
REFERENCE_HASH = 0x35ce3126ab961070


def random_next(state):
	state[0] = (state[0] * 1664525 + 1013904223) & 0xffffffff
	return state[0]


def hash_bytes(text):
	hash_value = FNV_OFFSET

	for byte in text.encode("ascii"):
		hash_value ^= byte
		hash_value = (hash_value * FNV_PRIME) & MASK
	return hash_value


def build_source_text(words):
	parts = []
	length = 0
	word_count = 0
	state = [0x12345678]

	while True:
		word = words[random_next(state) % WORD_COUNT]

		if word_count > 0:
			parts.append(" ")
			length += 1

		parts.append(word)
		length += len(word)
		word_count += 1

		if length > TARGET_SIZE:
			break

	text = "".join(parts)
	return text, word_count, hash_bytes(text)


def wrap_words(words):
	parts = []
	line_length = 0

	for i in range(len(words)):
		word = words[i]
		word_length = len(word)

		if i == 0:
			parts.append(word)
			line_length = word_length
			continue

		if line_length + 1 + word_length >= LINE_LIMIT:
			parts.append("\n")
			parts.append(word)
			line_length = word_length
		else:
			parts.append(" ")
			parts.append(word)
			line_length += 1 + word_length

	return "".join(parts)


def hash_wrapped_text(text):
	hash_value = FNV_OFFSET

	for i, line in enumerate(text.split("\n")):
		if i > 0:
			hash_value ^= 32
			hash_value = (hash_value * FNV_PRIME) & MASK

		for byte in line.encode("ascii"):
			hash_value ^= byte
			hash_value = (hash_value * FNV_PRIME) & MASK

	return hash_value


def run_benchmark(source_text, source_hash, runs):
	for _ in range(runs):
		split_words = source_text.split(" ")
		wrapped_text = wrap_words(split_words)
		wrapped_hash = hash_wrapped_text(wrapped_text)

		if wrapped_hash != source_hash:
			print(
				"Hash mismatch: 0x%016x != 0x%016x"
				% (wrapped_hash, source_hash),
				file = sys.stderr
			)
			sys.exit(1)


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
runs = 1
if len(sys.argv) > 1:
	runs = int(sys.argv[1])

source_text, source_word_count, source_hash = build_source_text(words)
if source_hash != REFERENCE_HASH:
	print(
		"Source hash mismatch: 0x%016x != 0x%016x"
		% (source_hash, REFERENCE_HASH),
		file = sys.stderr
	)
	sys.exit(1)

t = time.time()
run_benchmark(source_text, source_hash, runs)
print('Python Elapsed %.02f' % (time.time() - t), file = sys.stderr)
