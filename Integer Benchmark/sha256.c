#include <inttypes.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/time.h>

// Size of the shared source buffer hashed by every timed iteration.
static const size_t targetSize = 16 * 1024 * 1024;

// Streaming chunk size used to model file-style incremental hashing.
static const size_t chunkSize = 4096;

// FNV-1a 64-bit offset basis used to validate the generated source data.
static const uint64_t fnvOffset = UINT64_C(14695981039346656037);

// FNV-1a 64-bit prime used to validate the generated source data.
static const uint64_t fnvPrime = UINT64_C(1099511628211);

// Expected FNV-1a hash for the generated source buffer.
static const uint64_t referenceSourceHash =
	UINT64_C(0xc637e6db1fa57009);

// Expected SHA-256 digest for the generated source buffer.
static const uint8_t referenceDigest[32] = {
	0x99, 0x5e, 0x8c, 0x22, 0xa0, 0xda, 0x3f, 0x9e,
	0x01, 0x20, 0xf6, 0x9b, 0x09, 0x28, 0x7a, 0x16,
	0x92, 0xb9, 0x51, 0x7f, 0x1a, 0x58, 0xbd, 0xcb,
	0x75, 0xeb, 0x4e, 0x1d, 0xce, 0x56, 0x7f, 0x2b
};


struct SHA256Context {
	uint32_t state[8];
	uint64_t bit_count;
	uint8_t buffer[64];
	size_t buffer_length;
};


struct BenchmarkData {
	uint8_t *source_bytes;
	uint64_t source_hash;
	uint8_t digest[32];
};


static uint32_t random_next( uint32_t * state )
{
	*state = *state * UINT32_C(1664525) + UINT32_C(1013904223);
	return *state;
}


static uint64_t fnv1a_hash( const uint8_t * bytes, size_t length )
{
	uint64_t hash = fnvOffset;
	size_t i;

	for (i = 0; i < length; i++) {
		hash ^= bytes[i];
		hash *= fnvPrime;
	}
	return hash;
}


static uint32_t rotate_right( uint32_t value, uint32_t amount )
{
	return (value >> amount) | (value << (32 - amount));
}


static uint32_t load_be32( const uint8_t * bytes )
{
	return
		((uint32_t) bytes[0] << 24)
		| ((uint32_t) bytes[1] << 16)
		| ((uint32_t) bytes[2] << 8)
		| (uint32_t) bytes[3];
}


static void store_be32( uint8_t * bytes, uint32_t value )
{
	bytes[0] = (uint8_t) (value >> 24);
	bytes[1] = (uint8_t) (value >> 16);
	bytes[2] = (uint8_t) (value >> 8);
	bytes[3] = (uint8_t) value;
}


static void sha256_transform(
	struct SHA256Context *context,
	const uint8_t *block )
{
	static const uint32_t constants[64] = {
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
	};
	uint32_t message_schedule[64];
	uint32_t a;
	uint32_t b;
	uint32_t c;
	uint32_t d;
	uint32_t e;
	uint32_t f;
	uint32_t g;
	uint32_t h;
	size_t i;

	for (i = 0; i < 16; i++) {
		message_schedule[i] = load_be32(block + i * 4);
	}

	for (i = 16; i < 64; i++) {
		uint32_t s0 =
			rotate_right(message_schedule[i - 15], 7) ^
			rotate_right(message_schedule[i - 15], 18) ^
			(message_schedule[i - 15] >> 3);
		uint32_t s1 =
			rotate_right(message_schedule[i - 2], 17) ^
			rotate_right(message_schedule[i - 2], 19) ^
			(message_schedule[i - 2] >> 10);
		message_schedule[i] =
			message_schedule[i - 16]
			+ s0
			+ message_schedule[i - 7]
			+ s1;
	}

	a = context->state[0];
	b = context->state[1];
	c = context->state[2];
	d = context->state[3];
	e = context->state[4];
	f = context->state[5];
	g = context->state[6];
	h = context->state[7];

	for (i = 0; i < 64; i++) {
		uint32_t sum1 =
			rotate_right(e, 6) ^
			rotate_right(e, 11) ^
			rotate_right(e, 25);
		uint32_t choice = (e & f) ^ ((~e) & g);
		uint32_t temp1 =
			h
			+ sum1
			+ choice
			+ constants[i]
			+ message_schedule[i];
		uint32_t sum0 =
			rotate_right(a, 2) ^
			rotate_right(a, 13) ^
			rotate_right(a, 22);
		uint32_t majority = (a & b) ^ (a & c) ^ (b & c);
		uint32_t temp2 = sum0 + majority;

		h = g;
		g = f;
		f = e;
		e = d + temp1;
		d = c;
		c = b;
		b = a;
		a = temp1 + temp2;
	}

	context->state[0] += a;
	context->state[1] += b;
	context->state[2] += c;
	context->state[3] += d;
	context->state[4] += e;
	context->state[5] += f;
	context->state[6] += g;
	context->state[7] += h;
}


static void sha256_init( struct SHA256Context * context )
{
	context->state[0] = 0x6a09e667;
	context->state[1] = 0xbb67ae85;
	context->state[2] = 0x3c6ef372;
	context->state[3] = 0xa54ff53a;
	context->state[4] = 0x510e527f;
	context->state[5] = 0x9b05688c;
	context->state[6] = 0x1f83d9ab;
	context->state[7] = 0x5be0cd19;
	context->bit_count = 0;
	context->buffer_length = 0;
}


static void sha256_update(
	struct SHA256Context *context,
	const uint8_t *bytes,
	size_t length )
{
	size_t offset = 0;

	context->bit_count += (uint64_t) length * 8;

	if (context->buffer_length > 0) {
		size_t copy_length = 64 - context->buffer_length;

		if (copy_length > length) {
			copy_length = length;
		}

		memcpy(
			context->buffer + context->buffer_length,
			bytes,
			copy_length
		);
		context->buffer_length += copy_length;
		offset += copy_length;

		if (context->buffer_length == 64) {
			sha256_transform(context, context->buffer);
			context->buffer_length = 0;
		}
	}

	while (offset + 64 <= length) {
		sha256_transform(context, bytes + offset);
		offset += 64;
	}

	if (offset < length) {
		context->buffer_length = length - offset;
		memcpy(
			context->buffer,
			bytes + offset,
			context->buffer_length
		);
	}
}


static void sha256_final(
	struct SHA256Context *context,
	uint8_t digest[32] )
{
	size_t i;

	context->buffer[context->buffer_length] = 0x80;
	context->buffer_length++;

	if (context->buffer_length > 56) {
		memset(
			context->buffer + context->buffer_length,
			0,
			64 - context->buffer_length
		);
		sha256_transform(context, context->buffer);
		context->buffer_length = 0;
	}

	memset(
		context->buffer + context->buffer_length,
		0,
		56 - context->buffer_length
	);
	context->buffer[56] = (uint8_t) (context->bit_count >> 56);
	context->buffer[57] = (uint8_t) (context->bit_count >> 48);
	context->buffer[58] = (uint8_t) (context->bit_count >> 40);
	context->buffer[59] = (uint8_t) (context->bit_count >> 32);
	context->buffer[60] = (uint8_t) (context->bit_count >> 24);
	context->buffer[61] = (uint8_t) (context->bit_count >> 16);
	context->buffer[62] = (uint8_t) (context->bit_count >> 8);
	context->buffer[63] = (uint8_t) context->bit_count;
	sha256_transform(context, context->buffer);

	for (i = 0; i < 8; i++) {
		store_be32(digest + i * 4, context->state[i]);
	}
}


static void format_digest(
	const uint8_t digest[32],
	char buffer[65] )
{
	static const char hex_digits[] = "0123456789abcdef";
	size_t i;

	for (i = 0; i < 32; i++) {
		buffer[i * 2] = hex_digits[digest[i] >> 4];
		buffer[i * 2 + 1] = hex_digits[digest[i] & 0x0f];
	}
	buffer[64] = '\0';
}


static uint8_t * build_source_bytes( uint64_t * out_hash )
{
	uint8_t *bytes = malloc(targetSize);
	uint32_t state = UINT32_C(0x12345678);
	size_t i;

	if (bytes == NULL) {
		fprintf(stderr, "Failed to allocate source buffer.\n");
		exit(1);
	}

	for (i = 0; i < targetSize; i++) {
		bytes[i] = (uint8_t) (random_next(&state) >> 24);
	}

	*out_hash = fnv1a_hash(bytes, targetSize);
	return bytes;
}


static void hash_source_bytes(
	const uint8_t *bytes,
	uint8_t digest[32] )
{
	struct SHA256Context context;
	size_t offset = 0;

	sha256_init(&context);
	while (offset < targetSize) {
		size_t length = chunkSize;

		if (length > targetSize - offset) {
			length = targetSize - offset;
		}

		sha256_update(&context, bytes + offset, length);
		offset += length;
	}
	sha256_final(&context, digest);
}


static struct BenchmarkData build_benchmark_data( void )
{
	struct BenchmarkData data;
	char digest_buffer[65];

	data.source_bytes = build_source_bytes(&data.source_hash);
	if (data.source_hash != referenceSourceHash) {
		fprintf(
			stderr,
			"Source hash mismatch: 0x%016" PRIx64
			" != 0x%016" PRIx64 "\n",
			data.source_hash,
			referenceSourceHash
		);
		free(data.source_bytes);
		exit(1);
	}

	hash_source_bytes(data.source_bytes, data.digest);
	if (memcmp(data.digest, referenceDigest, sizeof(data.digest)) != 0) {
		format_digest(data.digest, digest_buffer);
		fprintf(
			stderr,
			"Source digest mismatch: %s != "
			"995e8c22a0da3f9e0120f69b09287a1692b9517f1a58bdcb"
			"75eb4e1dce567f2b\n",
			digest_buffer
		);
		free(data.source_bytes);
		exit(1);
	}

	return data;
}


static void free_benchmark_data( struct BenchmarkData * data )
{
	free(data->source_bytes);
}


static void run_benchmark(
	const struct BenchmarkData *data,
	int runs )
{
	int i;

	for (i = 0; i < runs; i++) {
		uint8_t digest[32];

		hash_source_bytes(data->source_bytes, digest);
		if (memcmp(digest, data->digest, sizeof(digest)) != 0) {
			char digest_buffer[65];
			char reference_buffer[65];

			format_digest(digest, digest_buffer);
			format_digest(data->digest, reference_buffer);
			fprintf(
				stderr,
				"Digest mismatch: %s != %s\n",
				digest_buffer,
				reference_buffer
			);
			exit(1);
		}
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
	fprintf(stderr, "C Elapsed %0.3f\n", query_time);
	return 0;
}
