package main

import (
	"bufio"
	"fmt"
	"os"
	"strconv"
	"strings"
	"time"
)

var targetSize = 1024 * 1024
var wordCount = 16
var lineLimit = 80
var fnvOffset uint64 = 14695981039346656037
var fnvPrime uint64 = 1099511628211
var referenceHash uint64 = 0xc6be9b9267a2fb8e

func randomNext ( state *uint32 ) uint32 {
	*state = *state*1664525 + 1013904223
	return *state
}


func hashBytes ( text string ) uint64 {
	hash := fnvOffset

	for i := 0; i < len(text); i++ {
		hash ^= uint64(text[i])
		hash *= fnvPrime
	}
	return hash
}


func buildSourceText ( words []string ) (string, int, uint64) {
	var text strings.Builder
	text.Grow(targetSize + 64)
	generatedWordCount := 0
	state := uint32(0x12345678)

	for {
		word := words[int(randomNext(&state)%uint32(wordCount))]
		if generatedWordCount > 0 {
			text.WriteByte(' ')
		}
		text.WriteString(word)
		generatedWordCount++
		if text.Len() > targetSize {
			break
		}
	}

	sourceText := text.String()
	return sourceText, generatedWordCount, hashBytes(sourceText)
}


func wrapWords ( words []string ) string {
	var text strings.Builder
	text.Grow(targetSize + 64)
	lineLength := 0

	for i := 0; i < len(words); i++ {
		word := words[i]
		wordLength := len(word)

		if i == 0 {
			text.WriteString(word)
			lineLength = wordLength
			continue
		}

		if lineLength+1+wordLength >= lineLimit {
			text.WriteByte('\n')
			text.WriteString(word)
			lineLength = wordLength
		} else {
			text.WriteByte(' ')
			text.WriteString(word)
			lineLength += 1 + wordLength
		}
	}

	return text.String()
}


func hashWrappedText ( text string ) uint64 {
	hash := fnvOffset
	reader := bufio.NewScanner(strings.NewReader(text))
	first := true

	for reader.Scan() {
		if !first {
			hash ^= uint64(' ')
			hash *= fnvPrime
		}
		first = false

		line := reader.Text()
		for i := 0; i < len(line); i++ {
			hash ^= uint64(line[i])
			hash *= fnvPrime
		}
	}

	return hash
}


func runBenchmark ( sourceText string, sourceHash uint64, runs int ) {
	for i := 0; i < runs; i++ {
		splitBuffer := string([]byte(sourceText))
		splitWords := strings.Split(splitBuffer, " ")
		wrappedText := wrapWords(splitWords)
		wrappedHash := hashWrappedText(wrappedText)

		if wrappedHash != sourceHash {
			fmt.Fprintf(
				os.Stderr,
				"Hash mismatch: 0x%016x != 0x%016x\n",
				wrappedHash,
				sourceHash,
			)
			os.Exit(1)
		}
	}
}


func main ( ) {
	words := []string{
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
		"counterclockwise",
	}
	runs := 1
	if len(os.Args) > 1 {
		runs, _ = strconv.Atoi(os.Args[1])
	}
	sourceText, _, sourceHash := buildSourceText(words)

	if sourceHash != referenceHash {
		fmt.Fprintf(
			os.Stderr,
			"Source hash mismatch: 0x%016x != 0x%016x\n",
			sourceHash,
			referenceHash,
		)
		os.Exit(1)
	}

	start := time.Now()
	runBenchmark(sourceText, sourceHash, runs)
	diff := time.Since(start)
	fmt.Fprintf(os.Stderr, "Go: %.3f s\n", diff.Seconds())
}
