using System;
using System.Diagnostics;
using System.Text;

public class Integer
{
	private const int TARGET_SIZE = 16 * 1024 * 1024;
	private const int CHUNK_SIZE = 4096;
	private const ulong FNV_OFFSET = 14695981039346656037UL;
	private const ulong FNV_PRIME = 1099511628211UL;
	private const ulong REFERENCE_SOURCE_HASH = 0xc637e6db1fa57009UL;
	private static readonly byte[] REFERENCE_DIGEST = {
		0x99, 0x5e, 0x8c, 0x22, 0xa0, 0xda, 0x3f, 0x9e,
		0x01, 0x20, 0xf6, 0x9b, 0x09, 0x28, 0x7a, 0x16,
		0x92, 0xb9, 0x51, 0x7f, 0x1a, 0x58, 0xbd, 0xcb,
		0x75, 0xeb, 0x4e, 0x1d, 0xce, 0x56, 0x7f, 0x2b
	};

	private sealed class SHA256Context
	{
		public uint[] State = {
			0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
			0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19
		};
		public ulong BitCount;
		public byte[] Buffer = new byte[64];
		public int BufferLength;
	}

	private sealed class BenchmarkData
	{
		public byte[] SourceBytes;
		public ulong SourceHash;
		public byte[] Digest;
	}

	private static uint RandomNext ( ref uint state )
	{
		state = state * 1664525 + 1013904223;
		return state;
	}


	private static ulong FNV1aHash ( byte[] bytes )
	{
		ulong hash = FNV_OFFSET;

		for (int i = 0; i < bytes.Length; i++)
		{
			hash ^= bytes[i];
			hash *= FNV_PRIME;
		}
		return hash;
	}


	private static uint RotateRight ( uint value, int amount )
	{
		return (value >> amount) | (value << (32 - amount));
	}


	private static uint LoadBE32 ( byte[] bytes, int offset )
	{
		return
			((uint) bytes[offset] << 24)
			| ((uint) bytes[offset + 1] << 16)
			| ((uint) bytes[offset + 2] << 8)
			| bytes[offset + 3];
	}


	private static void StoreBE32 ( byte[] bytes, int offset, uint value )
	{
		bytes[offset] = (byte) (value >> 24);
		bytes[offset + 1] = (byte) (value >> 16);
		bytes[offset + 2] = (byte) (value >> 8);
		bytes[offset + 3] = (byte) value;
	}


	private static void SHA256Transform (
		SHA256Context context,
		byte[] block )
	{
		uint[] constants = {
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
		uint[] messageSchedule = new uint[64];
		uint a;
		uint b;
		uint c;
		uint d;
		uint e;
		uint f;
		uint g;
		uint h;

		for (int i = 0; i < 16; i++)
		{
			messageSchedule[i] = LoadBE32(block, i * 4);
		}

		for (int i = 16; i < 64; i++)
		{
			uint s0 =
				RotateRight(messageSchedule[i - 15], 7) ^
				RotateRight(messageSchedule[i - 15], 18) ^
				(messageSchedule[i - 15] >> 3);
			uint s1 =
				RotateRight(messageSchedule[i - 2], 17) ^
				RotateRight(messageSchedule[i - 2], 19) ^
				(messageSchedule[i - 2] >> 10);
			messageSchedule[i] =
				messageSchedule[i - 16]
				+ s0
				+ messageSchedule[i - 7]
				+ s1;
		}

		a = context.State[0];
		b = context.State[1];
		c = context.State[2];
		d = context.State[3];
		e = context.State[4];
		f = context.State[5];
		g = context.State[6];
		h = context.State[7];

		for (int i = 0; i < 64; i++)
		{
			uint sum1 =
				RotateRight(e, 6) ^
				RotateRight(e, 11) ^
				RotateRight(e, 25);
			uint choice = (e & f) ^ ((~e) & g);
			uint temp1 =
				h
				+ sum1
				+ choice
				+ constants[i]
				+ messageSchedule[i];
			uint sum0 =
				RotateRight(a, 2) ^
				RotateRight(a, 13) ^
				RotateRight(a, 22);
			uint majority = (a & b) ^ (a & c) ^ (b & c);
			uint temp2 = sum0 + majority;

			h = g;
			g = f;
			f = e;
			e = d + temp1;
			d = c;
			c = b;
			b = a;
			a = temp1 + temp2;
		}

		context.State[0] += a;
		context.State[1] += b;
		context.State[2] += c;
		context.State[3] += d;
		context.State[4] += e;
		context.State[5] += f;
		context.State[6] += g;
		context.State[7] += h;
	}


	private static void SHA256Update (
		SHA256Context context,
		byte[] bytes )
	{
		int offset = 0;

		context.BitCount += (ulong) bytes.Length * 8;

		if (context.BufferLength > 0)
		{
			int copyLength = 64 - context.BufferLength;

			if (copyLength > bytes.Length)
				copyLength = bytes.Length;

			Array.Copy(
				bytes,
				0,
				context.Buffer,
				context.BufferLength,
				copyLength
			);
			context.BufferLength += copyLength;
			offset += copyLength;

			if (context.BufferLength == 64)
			{
				SHA256Transform(context, context.Buffer);
				context.BufferLength = 0;
			}
		}

		while (offset + 64 <= bytes.Length)
		{
			byte[] block = new byte[64];

			Array.Copy(bytes, offset, block, 0, 64);
			SHA256Transform(context, block);
			offset += 64;
		}

		if (offset < bytes.Length)
		{
			context.BufferLength = bytes.Length - offset;
			Array.Copy(bytes, offset, context.Buffer, 0, context.BufferLength);
		}
	}


	private static byte[] SHA256Final ( SHA256Context context )
	{
		byte[] digest = new byte[32];

		context.Buffer[context.BufferLength] = 0x80;
		context.BufferLength++;

		if (context.BufferLength > 56)
		{
			for (int i = context.BufferLength; i < 64; i++)
			{
				context.Buffer[i] = 0;
			}
			SHA256Transform(context, context.Buffer);
			context.BufferLength = 0;
		}

		for (int i = context.BufferLength; i < 56; i++)
		{
			context.Buffer[i] = 0;
		}
		context.Buffer[56] = (byte) (context.BitCount >> 56);
		context.Buffer[57] = (byte) (context.BitCount >> 48);
		context.Buffer[58] = (byte) (context.BitCount >> 40);
		context.Buffer[59] = (byte) (context.BitCount >> 32);
		context.Buffer[60] = (byte) (context.BitCount >> 24);
		context.Buffer[61] = (byte) (context.BitCount >> 16);
		context.Buffer[62] = (byte) (context.BitCount >> 8);
		context.Buffer[63] = (byte) context.BitCount;
		SHA256Transform(context, context.Buffer);

		for (int i = 0; i < 8; i++)
		{
			StoreBE32(digest, i * 4, context.State[i]);
		}

		return digest;
	}


	private static string FormatDigest ( byte[] digest )
	{
		StringBuilder text = new StringBuilder(64);

		for (int i = 0; i < digest.Length; i++)
		{
			text.AppendFormat("{0:x2}", digest[i]);
		}
		return text.ToString();
	}


	private static BenchmarkData BuildBenchmarkData ( )
	{
		BenchmarkData data = new BenchmarkData();
		uint state = 0x12345678;

		data.SourceBytes = new byte[TARGET_SIZE];
		for (int i = 0; i < TARGET_SIZE; i++)
		{
			data.SourceBytes[i] = (byte) (RandomNext(ref state) >> 24);
		}

		data.SourceHash = FNV1aHash(data.SourceBytes);
		if (data.SourceHash != REFERENCE_SOURCE_HASH)
		{
			Console.Error.WriteLine(
				$"Source hash mismatch: 0x{data.SourceHash:x16}"
				+ $" != 0x{REFERENCE_SOURCE_HASH:x16}"
			);
			Environment.Exit(1);
		}

		data.Digest = HashSourceBytes(data.SourceBytes);
		if (!EqualDigests(data.Digest, REFERENCE_DIGEST))
		{
			Console.Error.WriteLine(
				"Source digest mismatch: " + FormatDigest(data.Digest)
				+ " != "
				+ "995e8c22a0da3f9e0120f69b09287a1692b9517f1a58bdcb"
				+ "75eb4e1dce567f2b"
			);
			Environment.Exit(1);
		}

		return data;
	}


	private static byte[] HashSourceBytes ( byte[] bytes )
	{
		SHA256Context context = new SHA256Context();
		int offset = 0;

		while (offset < TARGET_SIZE)
		{
			int length = CHUNK_SIZE;
			byte[] chunk;

			if (length > TARGET_SIZE - offset)
				length = TARGET_SIZE - offset;

			chunk = new byte[length];
			Array.Copy(bytes, offset, chunk, 0, length);
			SHA256Update(context, chunk);
			offset += length;
		}

		return SHA256Final(context);
	}


	private static bool EqualDigests ( byte[] left, byte[] right )
	{
		if (left.Length != right.Length)
		{
			return false;
		}

		for (int i = 0; i < left.Length; i++)
		{
			if (left[i] != right[i])
			{
				return false;
			}
		}

		return true;
	}


	private static void RunBenchmark ( BenchmarkData data, int runs )
	{
		for (int run = 0; run < runs; run++)
		{
			byte[] digest = HashSourceBytes(data.SourceBytes);

			if (!EqualDigests(digest, data.Digest))
			{
				Console.Error.WriteLine(
					"Digest mismatch: " + FormatDigest(digest)
					+ " != " + FormatDigest(data.Digest)
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
