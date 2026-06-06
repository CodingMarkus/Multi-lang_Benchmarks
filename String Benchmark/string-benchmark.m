#import <Foundation/Foundation.h>

static const NSUInteger targetSize = 1024 * 1024;
static const NSUInteger wordCount = 16;
static const NSUInteger lineLimit = 80;
static const uint64_t fnvOffset = UINT64_C(14695981039346656037);
static const uint64_t fnvPrime = UINT64_C(1099511628211);
static const uint64_t referenceHash = UINT64_C(0xc96d7fcba133ffd5);


static uint32_t randomNext ( uint32_t * state )
{
	*state = *state * UINT32_C(1664525) + UINT32_C(1013904223);
	return *state;
}


static uint64_t hashUTF16 ( NSString * text )
{
	uint64_t hash = fnvOffset;
	NSUInteger i;

	for (i = 0; i < [text length]; i++) {
		hash ^= [text characterAtIndex:i];
		hash *= fnvPrime;
	}
	return hash;
}


static NSDictionary * buildBenchmarkData ( void )
{
	NSArray * words = @[
		@"I",
		@"we",
		@"cat",
		@"tree",
		@"café",
		@"naïve",
		@"jalapeño",
		@"mountain",
		@"blueberry",
		@"basketball",
		@"grandfather",
		@"microbiology",
		@"determination",
		@"responsibility",
		@"experimentation",
		@"counterclockwise"
	];
	NSMutableString * text = [NSMutableString stringWithCapacity:
		targetSize + 64];
	NSUInteger length = 0;
	NSUInteger generatedWordCount = 0;
	uint32_t state = UINT32_C(0x12345678);
	uint64_t sourceHash;

	while (1) {
		NSString * word = words[randomNext(&state) % wordCount];
		NSUInteger wordLength = [word length];

		if (generatedWordCount > 0) {
			[text appendString:@" "];
			length++;
		}

		[text appendString:word];
		length += wordLength;
		generatedWordCount++;

		if (length > targetSize) {
			break;
		}
	}

	sourceHash = hashUTF16(text);
	if (sourceHash != referenceHash) {
		fprintf(
			stderr,
			"Source hash mismatch: 0x%016llx != 0x%016llx\n",
			sourceHash,
			referenceHash
		);
		exit(1);
	}

	return @{
		@"sourceText": text,
		@"sourceHash": @(sourceHash)
	};
}


static NSString * wrapWords ( NSArray * words )
{
	NSMutableString * text = [NSMutableString stringWithCapacity:
		targetSize + 64];
	NSUInteger lineLength = 0;
	NSUInteger i;

	for (i = 0; i < [words count]; i++) {
		NSString * word = words[i];
		NSUInteger wordLength = [word length];

		if (i == 0) {
			[text appendString:word];
			lineLength = wordLength;
			continue;
		}

		if (lineLength + 1 + wordLength >= lineLimit) {
			[text appendString:@"\n"];
			[text appendString:word];
			lineLength = wordLength;
		} else {
			[text appendString:@" "];
			[text appendString:word];
			lineLength += 1 + wordLength;
		}
	}

	return text;
}


static uint64_t hashWrappedText ( NSString * text )
{
	__block uint64_t hash = fnvOffset;
	__block BOOL first = YES;

	[text enumerateLinesUsingBlock:
		^(NSString * line, BOOL * stop __attribute__((unused))) {
			NSUInteger i;

			if (!first) {
				hash ^= ' ';
				hash *= fnvPrime;
			}
			first = NO;

			for (i = 0; i < [line length]; i++) {
				hash ^= [line characterAtIndex:i];
				hash *= fnvPrime;
			}
		}
	];

	return hash;
}


static void runBenchmark ( NSDictionary * data, int runs )
{
	NSString * sourceText = data[@"sourceText"];
	uint64_t sourceHash = [data[@"sourceHash"] unsignedLongLongValue];
	int i;

	for (i = 0; i < runs; i++) {
		@autoreleasepool {
			NSString * splitBuffer = [[NSString alloc] initWithString:
				sourceText];
			NSArray * splitWords = [splitBuffer componentsSeparatedByString:
				@" "];
			NSString * wrappedText = wrapWords(splitWords);
			uint64_t wrappedHash = hashWrappedText(wrappedText);

			if (wrappedHash != sourceHash) {
				fprintf(
					stderr,
					"Hash mismatch: 0x%016llx != 0x%016llx\n",
					wrappedHash,
					sourceHash
				);
				exit(1);
			}
		}
	}
}


int main ( int argc, const char * argv[] )
{
	NSDictionary * data;
	double startTime;
	double timeElapsed;
	int runs = 1;

	if (argc > 1) {
		sscanf(argv[1], "%d", &runs);
	}

	@autoreleasepool {
		data = buildBenchmarkData();
		startTime = CFAbsoluteTimeGetCurrent();
		runBenchmark(data, runs);
		timeElapsed = CFAbsoluteTimeGetCurrent() - startTime;
		fprintf(stderr, "Objective-C Elapsed %.3f\n", timeElapsed);
	}

	return 0;
}
