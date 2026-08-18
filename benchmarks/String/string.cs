using System;
using System.Diagnostics;
using System.IO;
using System.Text;

public class String
{
	private const int TARGET_SIZE = 1024 * 1024;
	private const int WORD_COUNT = 16;
	private const int LINE_LIMIT = 80;
	private const ulong FNV_OFFSET = 14695981039346656037UL;
	private const ulong FNV_PRIME = 1099511628211UL;
	private const ulong REFERENCE_HASH = 0xc96d7fcba133ffd5UL;

	private sealed class BenchmarkData
	{
		public string SourceText;
		public int SourceLength;
		public int SourceWordCount;
		public ulong SourceHash;
	}

	private static uint RandomNext ( ref uint state )
	{
		state = state * 1664525 + 1013904223;
		return state;
	}


	private static ulong HashBytes ( string text )
	{
		ulong hash = FNV_OFFSET;

		for (int i = 0; i < text.Length; i++)
		{
			hash ^= text[i];
			hash *= FNV_PRIME;
		}
		return hash;
	}


	private static BenchmarkData BuildBenchmarkData ( )
	{
		string[] words = {
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
		uint state = 0x12345678;

		while (true)
		{
			string word = words[RandomNext(ref state) % WORD_COUNT];
			if (generatedWordCount > 0)
				text.Append(' ');
			text.Append(word);
			generatedWordCount++;
			if (text.Length > TARGET_SIZE)
				break;
		}

		BenchmarkData data = new BenchmarkData();
		data.SourceText = text.ToString();
		data.SourceLength = data.SourceText.Length;
		data.SourceWordCount = generatedWordCount;
		data.SourceHash = HashBytes(data.SourceText);

		if (data.SourceHash != REFERENCE_HASH)
		{
			Console.Error.WriteLine(
				$"Source hash mismatch: 0x{data.SourceHash:x16}"
				+ $" != 0x{REFERENCE_HASH:x16}"
			);
			Environment.Exit(1);
		}

		return data;
	}


	private static string WrapWords ( string[] words )
	{
		StringBuilder text = new StringBuilder(TARGET_SIZE + 64);
		int lineLength = 0;

		for (int i = 0; i < words.Length; i++)
		{
			string word = words[i];
			int wordLength = word.Length;

			if (i == 0)
			{
				text.Append(word);
				lineLength = wordLength;
				continue;
			}

			if (lineLength + 1 + wordLength >= LINE_LIMIT)
			{
				text.Append('\n');
				text.Append(word);
				lineLength = wordLength;
			}
			else
			{
				text.Append(' ');
				text.Append(word);
				lineLength += 1 + wordLength;
			}
		}

		return text.ToString();
	}


	private static ulong HashWrappedText ( string text )
	{
		ulong hash = FNV_OFFSET;
		StringReader reader = new StringReader(text);
		bool first = true;
		string line;

		while ((line = reader.ReadLine()) != null)
		{
			if (!first)
			{
				hash ^= ' ';
				hash *= FNV_PRIME;
			}
			first = false;

			for (int i = 0; i < line.Length; i++)
			{
				hash ^= line[i];
				hash *= FNV_PRIME;
			}
		}

		return hash;
	}


	private static void RunBenchmark ( BenchmarkData data, int runs )
	{
		for (int run = 0; run < runs; run++)
		{
			string splitBuffer = new string(data.SourceText.ToCharArray());
			string[] splitWords = splitBuffer.Split(' ');
			string wrappedText = WrapWords(splitWords);
			ulong wrappedHash = HashWrappedText(wrappedText);

			if (wrappedHash != data.SourceHash)
			{
				Console.Error.WriteLine(
					$"Hash mismatch: 0x{wrappedHash:x16}"
					+ $" != 0x{data.SourceHash:x16}"
				);
				Environment.Exit(1);
			}
		}
	}


	public static void Main ( string[] args )
	{
		int runs = 1;
		if (args.Length > 0) {
			if (int.TryParse(args[0], out int parsedRuns)) {
				runs = parsedRuns;
			}
		}

		BenchmarkData data = BuildBenchmarkData();
		long startTimestamp = Stopwatch.GetTimestamp();
		RunBenchmark(data, runs);
		double queryTime = (Stopwatch.GetTimestamp() - startTimestamp)
			/ (double) Stopwatch.Frequency;
		Console.Error.WriteLine($"C#: {queryTime:F3} s");
	}
}
