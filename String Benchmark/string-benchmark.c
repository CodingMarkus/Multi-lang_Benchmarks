#include <inttypes.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/time.h>

// Target size for the generated source text before timed runs begin.
static const size_t targetSize = 1024 * 1024;

// Number of words in the shared benchmark dictionary.
static const size_t wordCount = 16;

// Maximum allowed line width for the wrapped output text.
static const size_t lineLimit = 80;

// FNV-1a 64-bit offset basis used for all benchmark hashes.
static const uint64_t fnvOffset = UINT64_C(14695981039346656037);

// FNV-1a 64-bit prime used for all benchmark hashes.
static const uint64_t fnvPrime = UINT64_C(1099511628211);

// Expected hash for the generated 1 MiB source text.
static const uint64_t referenceHash = UINT64_C(0xc6be9b9267a2fb8e);


/**
	Advances the shared pseudo-random generator so every language can
	reproduce the same word sequence from the same seed.
*/
static uint32_t random_next( uint32_t * state )
{
	*state = *state * UINT32_C(1664525) + UINT32_C(1013904223);
	return *state;
}


/**
	Hashes a flat byte sequence with FNV-1a to produce the reference value
	for the original single-line source text.
*/
static uint64_t hash_bytes( const char * text, size_t length )
{
	uint64_t hash = fnvOffset;
	size_t i;

	// Hash the generated source text exactly as stored in memory.
	for (i = 0; i < length; i++) {
		hash ^= (unsigned char) text[i];
		hash *= fnvPrime;
	}
	return hash;
}


/**
	Holds the generated benchmark input that is shared across all timed
	iterations.
*/
struct BenchmarkData {
	char * source_text;
	size_t source_length;
	size_t source_word_count;
	uint64_t source_hash;
};


/**
	Builds the shared source text once by repeatedly choosing words from
	the fixed dictionary until the text grows beyond 1 MiB.
*/
static char * build_source_text(
	const char *const *words,
	size_t * out_length,
	size_t * out_word_count,
	uint64_t * out_hash )
{
	size_t capacity = targetSize + 64;
	char *text = malloc(capacity);
	size_t length = 0;
	size_t word_count = 0;
	uint32_t state = UINT32_C(0x12345678);

	if (text == NULL) {
		fprintf(stderr, "Failed to allocate source text.\n");
		exit(1);
	}

	while (1) {
		const char *word = words[random_next(&state) % wordCount];
		size_t word_length = strlen(word);

		// The source text is a single space-separated line of words.
		if (word_count > 0) {
			text[length] = ' ';
			length++;
		}

		memcpy(text + length, word, word_length);
		length += word_length;
		word_count++;

		if (length > targetSize) {
			break;
		}
	}

	text[length] = '\0';
	*out_length = length;
	*out_word_count = word_count;
	*out_hash = hash_bytes(text, length);
	return text;
}


/**
	Splits the original source text into words in-place by replacing spaces
	with terminators and storing pointers to each word.
*/
static size_t split_words( char *text, char **words )
{
	size_t count = 0;
	char * cursor = text;

	// This is the first timed transformation of the benchmark.
	while (*cursor != '\0') {
		words[count] = cursor;
		count++;

		while (*cursor != '\0' && *cursor != ' ') {
			cursor++;
		}

		if (*cursor == '\0') {
			break;
		}

		*cursor = '\0';
		cursor++;
	}

	return count;
}


/**
	Rebuilds the word sequence as wrapped text where adding another word
	would force the line length to reach or exceed 80 characters.
*/
static size_t wrap_words(
	char *const * words,
	size_t word_count,
	char *output )
{
	size_t length = 0;
	size_t line_length = 0;
	size_t i;

	// This models the join-and-wrap step of each timed iteration.
	for (i = 0; i < word_count; i++) {
		size_t word_length = strlen(words[i]);

		if (i == 0) {
			memcpy(output + length, words[i], word_length);
			length += word_length;
			line_length = word_length;
			continue;
		}

		// Start a new line instead of letting this line hit 80 chars.
		if (line_length + 1 + word_length >= lineLimit) {
			output[length] = '\n';
			length++;
			memcpy(output + length, words[i], word_length);
			length += word_length;
			line_length = word_length;
		} else {
			output[length] = ' ';
			length++;
			memcpy(output + length, words[i], word_length);
			length += word_length;
			line_length += 1 + word_length;
		}
	}

	output[length] = '\0';
	return length;
}


/**
	Reads the wrapped text line-by-line and hashes each line while feeding
	a space into the hash wherever the wrapped representation had a newline.
*/
static uint64_t hash_wrapped_text( char *text )
{
	uint64_t hash = fnvOffset;
	char *line = text;

	// This models line-based reading instead of a flat byte scan.
	while (1) {
		char *cursor = line;

		// Consume one logical line before moving to the next one.
		while (*cursor != '\0' && *cursor != '\n') {
			hash ^= (unsigned char) *cursor;
			hash *= fnvPrime;
			cursor++;
		}

		if (*cursor == '\0') {
			break;
		}

		// Newlines do not count; they are normalized back to spaces.
		hash ^= (unsigned char) ' ';
		hash *= fnvPrime;
		*cursor = '\0';
		line = cursor + 1;
	}

	return hash;
}


/**
	Allocates and prepares all data needed by the benchmark. This happens
	before timing starts so setup cost is excluded from the measurement.
*/
static struct BenchmarkData build_benchmark_data( void )
{
	static const char *const words[] = {
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
	};
	struct BenchmarkData data;

	// Generate the shared source text once and remember its hash.
	data.source_text = build_source_text(
		words,
		&data.source_length,
		&data.source_word_count,
		&data.source_hash
	);
	// Refuse to benchmark if the generated source text is not identical.
	if (data.source_hash != referenceHash) {
		fprintf(
			stderr,
			"Source hash mismatch: 0x%016" PRIx64
			" != 0x%016" PRIx64 "\n",
			data.source_hash,
			referenceHash
		);
		free(data.source_text);
		exit(1);
	}

	return data;
}


/**
	Releases all buffers that were allocated for the benchmark run setup.
*/
static void free_benchmark_data( struct BenchmarkData * data )
{
	free(data->source_text);
}


/**
	Runs the timed benchmark loop: split the source text into words, wrap it
	into short lines, then hash it again by consuming the wrapped text
	line-by-line. The final hash must match the original source hash.
*/
static void run_benchmark(
	const struct BenchmarkData *data,
	int runs )
{
	int i;

	for (i = 0; i < runs; i++) {
		char * split_buffer;
		char ** split_words_buffer;
		char * wrapped_text;
		size_t split_count;
		size_t wrapped_length;
		uint64_t wrapped_hash;

		// Each timed run allocates its own working memory up front.
		split_buffer = malloc(data->source_length + 1);
		split_words_buffer = malloc(
			data->source_word_count * sizeof(*split_words_buffer)
		);
		wrapped_text = malloc(data->source_length + 1);
		if (
			split_buffer == NULL ||
			split_words_buffer == NULL ||
			wrapped_text == NULL
		) {
			fprintf(stderr, "Failed to allocate benchmark buffers.\n");
			free(split_buffer);
			free(split_words_buffer);
			free(wrapped_text);
			exit(1);
		}

		// Start each iteration from the same original 1 MiB source text.
		memcpy(
			split_buffer,
			data->source_text,
			data->source_length + 1
		);
		// Benchmark the split from one large string into many words.
		split_count = split_words(
			split_buffer,
			split_words_buffer
		);
		// Benchmark joining those words back into wrapped lines.
		wrapped_length = wrap_words(
			split_words_buffer,
			split_count,
			wrapped_text
		);
		(void) wrapped_length;
		// Benchmark reading the wrapped result line-by-line again.
		wrapped_hash = hash_wrapped_text(wrapped_text);

		// Every implementation must reproduce the same logical text.
		if (wrapped_hash != data->source_hash) {
			fprintf(
				stderr,
				"Hash mismatch: 0x%016" PRIx64
				" != 0x%016" PRIx64 "\n",
				wrapped_hash,
				data->source_hash
			);
			free(split_buffer);
			free(split_words_buffer);
			free(wrapped_text);
			exit(1);
		}

		// Each timed run also frees its working memory before the next run.
		free(split_buffer);
		free(split_words_buffer);
		free(wrapped_text);
	}
}


/**
	Parses the iteration count, prepares benchmark data, times only the
	repeated benchmark loop, and reports the elapsed wall-clock time.
*/
int main( int argc, const char * argv[] )
{
	struct BenchmarkData data;
	double start;
	double query_time;
	struct timeval aTv;
	int runs = 1;

	if (argc > 1) {
		sscanf(argv[1], "%d", &runs);
	}

	// Setup is intentionally outside the timed benchmark section.
	data = build_benchmark_data();
	gettimeofday(&aTv, NULL);
	start = aTv.tv_sec * 1000000.0 + aTv.tv_usec;
	// Only the repeated split, wrap and re-hash loop is measured.
	run_benchmark(&data, runs);
	gettimeofday(&aTv, NULL);
	free_benchmark_data(&data);
	query_time = (double) aTv.tv_sec * 1000000.0 + aTv.tv_usec;
	query_time -= start;
	query_time /= 1000000.0;
	fprintf(stderr, "C Elapsed %0.3f\n", query_time);
	return 0;
}
