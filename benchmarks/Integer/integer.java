import java.text.DecimalFormat;
import java.text.DecimalFormatSymbols;
import java.util.Locale;

class Integer
{
	static int TARGET_SIZE = 16 * 1024 * 1024;
	static int CHUNK_SIZE = 4096;
	static long FNV_OFFSET = 0xcbf29ce484222325L;
	static long FNV_PRIME = 1099511628211L;
	static long REFERENCE_SOURCE_HASH = 0xc637e6db1fa57009L;
	static byte REFERENCE_DIGEST[] = {
		(byte) 0x99, 0x5e, (byte) 0x8c, 0x22,
		(byte) 0xa0, (byte) 0xda, 0x3f, (byte) 0x9e,
		0x01, 0x20, (byte) 0xf6, (byte) 0x9b,
		0x09, 0x28, 0x7a, 0x16,
		(byte) 0x92, (byte) 0xb9, 0x51, 0x7f,
		0x1a, 0x58, (byte) 0xbd, (byte) 0xcb,
		0x75, (byte) 0xeb, 0x4e, 0x1d,
		(byte) 0xce, 0x56, 0x7f, 0x2b
	};

	static class SHA256Context
	{
		int state[] = {
			0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
			0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19
		};
		long bitCount;
		byte buffer[] = new byte[64];
		int bufferLength;
	}

	static class BenchmarkData
	{
		byte sourceBytes[];
		long sourceHash;
		byte digest[];
	}

	private static int randomNext(int state[])
	{
		state[0] = state[0] * 1664525 + 1013904223;
		return state[0];
	}

	private static long fnv1aHash(byte bytes[])
	{
		long hash = FNV_OFFSET;
		int i;

		for (i = 0; i < bytes.length; i++) {
			hash ^= Byte.toUnsignedLong(bytes[i]);
			hash *= FNV_PRIME;
		}
		return hash;
	}

	private static int rotateRight(int value, int amount)
	{
		return (value >>> amount) | (value << (32 - amount));
	}

	private static int loadBE32(byte bytes[], int offset)
	{
		return
			(Byte.toUnsignedInt(bytes[offset]) << 24)
			| (Byte.toUnsignedInt(bytes[offset + 1]) << 16)
			| (Byte.toUnsignedInt(bytes[offset + 2]) << 8)
			| Byte.toUnsignedInt(bytes[offset + 3]);
	}

	private static void storeBE32(byte bytes[], int offset, int value)
	{
		bytes[offset] = (byte) (value >>> 24);
		bytes[offset + 1] = (byte) (value >>> 16);
		bytes[offset + 2] = (byte) (value >>> 8);
		bytes[offset + 3] = (byte) value;
	}

	private static void sha256Transform(
		SHA256Context context,
		byte block[] )
	{
		int constants[] = {
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
		int messageSchedule[] = new int[64];
		int a;
		int b;
		int c;
		int d;
		int e;
		int f;
		int g;
		int h;
		int i;

		for (i = 0; i < 16; i++) {
			messageSchedule[i] = loadBE32(block, i * 4);
		}

		for (i = 16; i < 64; i++) {
			int s0 =
				rotateRight(messageSchedule[i - 15], 7) ^
				rotateRight(messageSchedule[i - 15], 18) ^
				(messageSchedule[i - 15] >>> 3);
			int s1 =
				rotateRight(messageSchedule[i - 2], 17) ^
				rotateRight(messageSchedule[i - 2], 19) ^
				(messageSchedule[i - 2] >>> 10);
			messageSchedule[i] =
				messageSchedule[i - 16]
				+ s0
				+ messageSchedule[i - 7]
				+ s1;
		}

		a = context.state[0];
		b = context.state[1];
		c = context.state[2];
		d = context.state[3];
		e = context.state[4];
		f = context.state[5];
		g = context.state[6];
		h = context.state[7];

		for (i = 0; i < 64; i++) {
			int sum1 =
				rotateRight(e, 6) ^
				rotateRight(e, 11) ^
				rotateRight(e, 25);
			int choice = (e & f) ^ ((~e) & g);
			int temp1 =
				h
				+ sum1
				+ choice
				+ constants[i]
				+ messageSchedule[i];
			int sum0 =
				rotateRight(a, 2) ^
				rotateRight(a, 13) ^
				rotateRight(a, 22);
			int majority = (a & b) ^ (a & c) ^ (b & c);
			int temp2 = sum0 + majority;

			h = g;
			g = f;
			f = e;
			e = d + temp1;
			d = c;
			c = b;
			b = a;
			a = temp1 + temp2;
		}

		context.state[0] += a;
		context.state[1] += b;
		context.state[2] += c;
		context.state[3] += d;
		context.state[4] += e;
		context.state[5] += f;
		context.state[6] += g;
		context.state[7] += h;
	}

	private static void sha256Update(
		SHA256Context context,
		byte bytes[] )
	{
		int offset = 0;

		context.bitCount += (long) bytes.length * 8;

		if (context.bufferLength > 0) {
			int copyLength = 64 - context.bufferLength;

			if (copyLength > bytes.length)
				copyLength = bytes.length;

			System.arraycopy(
				bytes,
				0,
				context.buffer,
				context.bufferLength,
				copyLength
			);
			context.bufferLength += copyLength;
			offset += copyLength;

			if (context.bufferLength == 64) {
				sha256Transform(context, context.buffer);
				context.bufferLength = 0;
			}
		}

		while (offset + 64 <= bytes.length) {
			byte block[] = new byte[64];

			System.arraycopy(bytes, offset, block, 0, 64);
			sha256Transform(context, block);
			offset += 64;
		}

		if (offset < bytes.length) {
			context.bufferLength = bytes.length - offset;
			System.arraycopy(
				bytes,
				offset,
				context.buffer,
				0,
				context.bufferLength
			);
		}
	}

	private static byte[] sha256Final(SHA256Context context)
	{
		byte digest[] = new byte[32];
		int i;

		context.buffer[context.bufferLength] = (byte) 0x80;
		context.bufferLength++;

		if (context.bufferLength > 56) {
			for (i = context.bufferLength; i < 64; i++)
				context.buffer[i] = 0;
			sha256Transform(context, context.buffer);
			context.bufferLength = 0;
		}

		for (i = context.bufferLength; i < 56; i++)
			context.buffer[i] = 0;
		context.buffer[56] = (byte) (context.bitCount >>> 56);
		context.buffer[57] = (byte) (context.bitCount >>> 48);
		context.buffer[58] = (byte) (context.bitCount >>> 40);
		context.buffer[59] = (byte) (context.bitCount >>> 32);
		context.buffer[60] = (byte) (context.bitCount >>> 24);
		context.buffer[61] = (byte) (context.bitCount >>> 16);
		context.buffer[62] = (byte) (context.bitCount >>> 8);
		context.buffer[63] = (byte) context.bitCount;
		sha256Transform(context, context.buffer);

		for (i = 0; i < 8; i++) {
			storeBE32(digest, i * 4, context.state[i]);
		}

		return digest;
	}

	private static String formatDigest(byte digest[])
	{
		StringBuilder text = new StringBuilder(64);
		int i;

		for (i = 0; i < digest.length; i++) {
			text.append(
				String.format(
					Locale.US,
					"%02x",
					Byte.toUnsignedInt(digest[i])
				)
			);
		}
		return text.toString();
	}

	private static BenchmarkData buildBenchmarkData()
	{
		BenchmarkData data = new BenchmarkData();
		int state[] = { 0x12345678 };
		int i;

		data.sourceBytes = new byte[TARGET_SIZE];
		for (i = 0; i < TARGET_SIZE; i++) {
			data.sourceBytes[i] = (byte) (randomNext(state) >>> 24);
		}

		data.sourceHash = fnv1aHash(data.sourceBytes);
		if (data.sourceHash != REFERENCE_SOURCE_HASH) {
			System.err.println(
				String.format(
					Locale.US,
					"Source hash mismatch: 0x%016x != 0x%016x",
					data.sourceHash,
					REFERENCE_SOURCE_HASH
				)
			);
			System.exit(1);
		}

		data.digest = hashSourceBytes(data.sourceBytes);
		if (!java.util.Arrays.equals(data.digest, REFERENCE_DIGEST)) {
			System.err.println(
				"Source digest mismatch: " + formatDigest(data.digest)
				+ " != "
				+ "995e8c22a0da3f9e0120f69b09287a1692b9517f1a58bdcb"
				+ "75eb4e1dce567f2b"
			);
			System.exit(1);
		}

		return data;
	}

	private static byte[] hashSourceBytes(byte bytes[])
	{
		SHA256Context context = new SHA256Context();
		int offset = 0;

		while (offset < TARGET_SIZE) {
			int length = CHUNK_SIZE;
			byte chunk[];

			if (length > TARGET_SIZE - offset)
				length = TARGET_SIZE - offset;

			chunk = new byte[length];
			System.arraycopy(bytes, offset, chunk, 0, length);
			sha256Update(context, chunk);
			offset += length;
		}

		return sha256Final(context);
	}

	private static void runBenchmark(BenchmarkData data, int runs)
	{
		int i;

		for (i = 0; i < runs; i++) {
			byte digest[] = hashSourceBytes(data.sourceBytes);

			if (!java.util.Arrays.equals(digest, data.digest)) {
				System.err.println(
					"Digest mismatch: " + formatDigest(digest)
					+ " != " + formatDigest(data.digest)
				);
				System.exit(1);
			}
		}
	}

	public static void main(String args[])
	{
		long diff;
		long start;
		int runs = 1;

		if (args.length > 0) {
			runs = java.lang.Integer.parseInt(args[0]);
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
