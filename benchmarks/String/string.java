import java.io.BufferedReader;
import java.io.StringReader;
import java.text.DecimalFormat;
import java.text.DecimalFormatSymbols;
import java.util.Locale;

class String
{
	static int TARGET_SIZE = 1024 * 1024;
	static int WORD_COUNT = 16;
	static int LINE_LIMIT = 80;
	static long FNV_OFFSET = 0xcbf29ce484222325L;
	static long FNV_PRIME = 1099511628211L;
	static long REFERENCE_HASH = 0xc96d7fcba133ffd5L;

	static class BenchmarkData
	{
		java.lang.String sourceText;
		int sourceLength;
		int sourceWordCount;
		long sourceHash;
	}

	private static int randomNext(int state[])
	{
		state[0] = state[0] * 1664525 + 1013904223;
		return state[0];
	}

	private static long hashBytes(java.lang.String text)
	{
		long hash = FNV_OFFSET;
		int i;

		for (i = 0; i < text.length(); i++) {
			hash ^= text.charAt(i);
			hash *= FNV_PRIME;
		}
		return hash;
	}

	private static BenchmarkData buildBenchmarkData()
	{
		java.lang.String words[] = {
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
		StringBuilder text = new StringBuilder(TARGET_SIZE + 64);
		int generatedWordCount = 0;
		int state[] = { 0x12345678 };

		while (true) {
			java.lang.String word = words[
				Integer.remainderUnsigned(randomNext(state), WORD_COUNT)
			];
			if (generatedWordCount > 0)
				text.append(' ');
			text.append(word);
			generatedWordCount++;
			if (text.length() > TARGET_SIZE)
				break;
		}

		BenchmarkData data = new BenchmarkData();
		data.sourceText = text.toString();
		data.sourceLength = data.sourceText.length();
		data.sourceWordCount = generatedWordCount;
		data.sourceHash = hashBytes(data.sourceText);
		if (data.sourceHash != REFERENCE_HASH) {
			System.err.println(
				java.lang.String.format(
					Locale.US,
					"Source hash mismatch: 0x%016x != 0x%016x",
					data.sourceHash,
					REFERENCE_HASH
				)
			);
			System.exit(1);
		}
		return data;
	}

	private static java.lang.String wrapWords(java.lang.String words[])
	{
		StringBuilder text = new StringBuilder(TARGET_SIZE + 64);
		int lineLength = 0;
		int i;

		for (i = 0; i < words.length; i++) {
			java.lang.String word = words[i];
			int wordLength = word.length();

			if (i == 0) {
				text.append(word);
				lineLength = wordLength;
				continue;
			}

			if (lineLength + 1 + wordLength >= LINE_LIMIT) {
				text.append('\n');
				text.append(word);
				lineLength = wordLength;
			} else {
				text.append(' ');
				text.append(word);
				lineLength += 1 + wordLength;
			}
		}

		return text.toString();
	}

	private static long hashWrappedText(java.lang.String text) throws Exception
	{
		long hash = FNV_OFFSET;
		BufferedReader reader = new BufferedReader(new StringReader(text));
		boolean first = true;
		java.lang.String line;

		while ((line = reader.readLine()) != null) {
			if (!first) {
				hash ^= ' ';
				hash *= FNV_PRIME;
			}
			first = false;

			for (int i = 0; i < line.length(); i++) {
				hash ^= line.charAt(i);
				hash *= FNV_PRIME;
			}
		}

		return hash;
	}

	private static void runBenchmark(BenchmarkData data, int runs)
		throws Exception
	{
		int i;

		for (i = 0; i < runs; i++) {
			java.lang.String splitBuffer = new java.lang.String(
				data.sourceText.toCharArray());
			java.lang.String splitWords[] = splitBuffer.split(" ");
			java.lang.String wrappedText = wrapWords(splitWords);
			long wrappedHash = hashWrappedText(wrappedText);

			if (wrappedHash != data.sourceHash) {
				System.err.println(
					java.lang.String.format(
						Locale.US,
						"Hash mismatch: 0x%016x != 0x%016x",
						wrappedHash,
						data.sourceHash
					)
				);
				System.exit(1);
			}
		}
	}

	public static void main(java.lang.String args[]) throws Exception
	{
		long diff;
		long start;
		int runs = 1;

		if (args.length > 0) {
			runs = Integer.parseInt(args[0]);
		}
		BenchmarkData data = buildBenchmarkData();
		start = System.currentTimeMillis();
		runBenchmark(data, runs);
		diff = System.currentTimeMillis() - start;
		DecimalFormat df = new DecimalFormat(
			"0.000", new DecimalFormatSymbols(Locale.US));

		System.err.println("Java: " + df.format(diff / 1000.0f) + " s");
	}
}
