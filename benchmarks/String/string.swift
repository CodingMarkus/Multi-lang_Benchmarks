import Foundation

let targetSize = 1024 * 1024
let wordCount = 16
let lineLimit = 80
let fnvOffset: UInt64 = 14695981039346656037
let fnvPrime: UInt64 = 1099511628211
let referenceHash: UInt64 = 0xc6be9b9267a2fb8e

private
func randomNext(_ state: inout UInt32) -> UInt32
{
	state = state &* 1664525 &+ 1013904223
	return state
}


private
func hashBytes(_ text: String.UTF8View) -> UInt64
{
	var hash: UInt64 = fnvOffset

	for byte in text {
		hash ^= UInt64(byte)
		hash = hash &* fnvPrime
	}
	return hash
}


private
func buildSourceText(_ words: [String]) -> (String, Int, UInt64)
{
	var text = String()
	text.reserveCapacity(targetSize + 64)
	var length = 0
	var generatedWordCount = 0
	var state: UInt32 = 0x12345678

	while true {
		let index = Int(randomNext(&state) % UInt32(wordCount))
		let word = words[index]
		let wordLength = word.utf8.count

		if generatedWordCount > 0 {
			text.append(" ")
			length += 1
		}

		text.append(word)
		length += wordLength
		generatedWordCount += 1

		if length > targetSize {
			break
		}
	}

	return (text, generatedWordCount, hashBytes(text.utf8))
}


private
func wrapWords(_ words: [Substring]) -> String
{
	var text = String()
	text.reserveCapacity(targetSize + 64)
	var lineLength = 0

	for i in 0 ..< words.count {
		let word = words[i]
		let wordLength = word.count

		if i == 0 {
			text.append(contentsOf: word)
			lineLength = wordLength
			continue
		}

		if lineLength + 1 + wordLength >= lineLimit {
			text.append("\n")
			text.append(contentsOf: word)
			lineLength = wordLength
		} else {
			text.append(" ")
			text.append(contentsOf: word)
			lineLength += 1 + wordLength
		}
	}

	return text
}


private
func hashWrappedText(_ text: String) -> UInt64
{
	var hash: UInt64 = fnvOffset
	var first = true

	text.enumerateLines { line, _ in
		if !first {
			hash ^= 32
			hash = hash &* fnvPrime
		}
		first = false

		for byte in line.utf8 {
			hash ^= UInt64(byte)
			hash = hash &* fnvPrime
		}
	}

	return hash
}


public struct StderrOutputStream: TextOutputStream {
	public static let stream = StderrOutputStream ( )
	public func write(_ string: String) { fputs(string, stderr) }
}
var errStream = StderrOutputStream()


private
func runBenchmark(_ sourceText: String, _ sourceHash: UInt64, _ runs: Int)
{
	for _ in 0 ..< runs {
		let splitBuffer = String(
			decoding: Array(sourceText.utf8),
			as: UTF8.self
		)
		let splitWords = splitBuffer.split(separator: " ")
		let wrappedText = wrapWords(splitWords)
		let wrappedHash = hashWrappedText(wrappedText)

		if wrappedHash != sourceHash {
			print(
				String(
					format: "Hash mismatch: 0x%016llx != 0x%016llx",
					wrappedHash,
					sourceHash
				),
				to: &errStream
			)
			exit(1)
		}
	}
}


private func main ( )
{
	let words = [
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
	]
	let runs = if CommandLine.arguments.count <= 1
		|| CommandLine.arguments[1] == ""
	{
		1
	} else {
		Int(CommandLine.arguments[1]) ?? 1
	}
	let (sourceText, _, sourceHash) = buildSourceText(words)

	if sourceHash != referenceHash {
		print(
			String(
				format: "Source hash mismatch: 0x%016llx != 0x%016llx",
				sourceHash,
				referenceHash
			),
			to: &errStream
		)
		exit(1)
	}

	let startTime = CFAbsoluteTimeGetCurrent()
	runBenchmark(sourceText, sourceHash, runs)
	let benchmarkTime = CFAbsoluteTimeGetCurrent() - startTime
	let timeString = String(format: "%.3f", benchmarkTime)
	print("Swift: \(timeString) s", to: &errStream)
}

main()
