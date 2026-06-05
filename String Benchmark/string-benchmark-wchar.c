#include <inttypes.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/time.h>
#include <wchar.h>

static const size_t targetSize = 1024 * 1024;
static const size_t wordCount = 16;
static const size_t lineLimit = 80;
static const uint64_t fnvOffset = UINT64_C(14695981039346656037);
static const uint64_t fnvPrime = UINT64_C(1099511628211);
static const uint64_t referenceHash = UINT64_C(0x35ce3126ab961070);


static uint32_t random_next( uint32_t * state )
{
	*state = *state * UINT32_C(1664525) + UINT32_C(1013904223);
	return *state;
}


static uint64_t hash_wchars( const wchar_t * text, size_t length )
{
	uint64_t hash = fnvOffset;
	size_t i;

	for (i = 0; i < length; i++) {
		hash ^= (uint64_t) text[i];
		hash *= fnvPrime;
	}
	return hash;
}


struct BenchmarkData {
	wchar_t * source_text;
	size_t source_length;
	size_t source_word_count;
	uint64_t source_hash;
};


static wchar_t * build_source_text(
	const wchar_t *const *words,
	size_t * out_length,
	size_t * out_word_count,
	uint64_t * out_hash )
{
	size_t capacity = targetSize + 64;
	wchar_t *text = malloc((capacity + 1) * sizeof(*text));
	size_t length = 0;
	size_t generated_word_count = 0;
	uint32_t state = UINT32_C(0x12345678);

	if (text == NULL) {
		fprintf(stderr, "Failed to allocate source text.\n");
		exit(1);
	}

	while (1) {
		const wchar_t *word = words[random_next(&state) % wordCount];
		size_t word_length = wcslen(word);

		if (generated_word_count > 0) {
			text[length] = L' ';
			length++;
		}

		wmemcpy(text + length, word, word_length);
		length += word_length;
		generated_word_count++;

		if (length > targetSize) {
			break;
		}
	}

	text[length] = L'\0';
	*out_length = length;
	*out_word_count = generated_word_count;
	*out_hash = hash_wchars(text, length);
	return text;
}


static size_t split_words( wchar_t *text, wchar_t **words )
{
	size_t count = 0;
	wchar_t * cursor = text;

	while (*cursor != L'\0') {
		words[count] = cursor;
		count++;

		while (*cursor != L'\0' && *cursor != L' ') {
			cursor++;
		}

		if (*cursor == L'\0') {
			break;
		}

		*cursor = L'\0';
		cursor++;
	}

	return count;
}


static size_t wrap_words(
	wchar_t *const * words,
	size_t word_count,
	wchar_t *output )
{
	size_t length = 0;
	size_t line_length = 0;
	size_t i;

	for (i = 0; i < word_count; i++) {
		size_t word_length = wcslen(words[i]);

		if (i == 0) {
			wmemcpy(output + length, words[i], word_length);
			length += word_length;
			line_length = word_length;
			continue;
		}

		if (line_length + 1 + word_length >= lineLimit) {
			output[length] = L'\n';
			length++;
			wmemcpy(output + length, words[i], word_length);
			length += word_length;
			line_length = word_length;
		} else {
			output[length] = L' ';
			length++;
			wmemcpy(output + length, words[i], word_length);
			length += word_length;
			line_length += 1 + word_length;
		}
	}

	output[length] = L'\0';
	return length;
}


static uint64_t hash_wrapped_text( wchar_t *text )
{
	uint64_t hash = fnvOffset;
	wchar_t *line = text;

	while (1) {
		wchar_t *cursor = line;

		while (*cursor != L'\0' && *cursor != L'\n') {
			hash ^= (uint64_t) *cursor;
			hash *= fnvPrime;
			cursor++;
		}

		if (*cursor == L'\0') {
			break;
		}

		hash ^= (uint64_t) L' ';
		hash *= fnvPrime;
		*cursor = L'\0';
		line = cursor + 1;
	}

	return hash;
}


static struct BenchmarkData build_benchmark_data( void )
{
	static const wchar_t *const words[] = {
		L"I",
		L"we",
		L"cat",
		L"tree",
		L"apple",
		L"bridge",
		L"lantern",
		L"mountain",
		L"blueberry",
		L"basketball",
		L"grandfather",
		L"microbiology",
		L"determination",
		L"responsibility",
		L"experimentation",
		L"counterclockwise"
	};
	struct BenchmarkData data;

	data.source_text = build_source_text(
		words,
		&data.source_length,
		&data.source_word_count,
		&data.source_hash
	);
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


static void free_benchmark_data( struct BenchmarkData * data )
{
	free(data->source_text);
}


static void run_benchmark(
	const struct BenchmarkData *data,
	int runs )
{
	int i;

	for (i = 0; i < runs; i++) {
		wchar_t * split_buffer;
		wchar_t ** split_words_buffer;
		wchar_t * wrapped_text;
		size_t split_count;
		size_t wrapped_length;
		uint64_t wrapped_hash;

		split_buffer = malloc(
			(data->source_length + 1) * sizeof(*split_buffer)
		);
		split_words_buffer = malloc(
			data->source_word_count * sizeof(*split_words_buffer)
		);
		wrapped_text = malloc(
			(data->source_length + 1) * sizeof(*wrapped_text)
		);
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

		wmemcpy(
			split_buffer,
			data->source_text,
			data->source_length + 1
		);
		split_count = split_words(
			split_buffer,
			split_words_buffer
		);
		wrapped_length = wrap_words(
			split_words_buffer,
			split_count,
			wrapped_text
		);
		(void) wrapped_length;
		wrapped_hash = hash_wrapped_text(wrapped_text);

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

		free(split_buffer);
		free(split_words_buffer);
		free(wrapped_text);
	}
}


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

	data = build_benchmark_data();
	gettimeofday(&aTv, NULL);
	start = aTv.tv_sec * 1000000.0 + aTv.tv_usec;
	run_benchmark(&data, runs);
	gettimeofday(&aTv, NULL);
	free_benchmark_data(&data);
	query_time = (double) aTv.tv_sec * 1000000.0 + aTv.tv_usec;
	query_time -= start;
	query_time /= 1000000.0;
	fprintf(stderr, "C wchar Elapsed %0.3f\n", query_time);
	return 0;
}
