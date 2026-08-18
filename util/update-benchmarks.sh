#!/bin/sh

# Copyright 2026 CodingMarkus
#
# SPDX-License-Identifier: Unlicense

set -eu

projectDirectory=$(CDPATH='' cd "$(dirname "$0")/.." \
	&& pwd)
selectedBenchmarks=


usage( )
{
	printf '%s\n' \
		'Usage: ./util/update-benchmarks.sh [-b, -bench, --bench LIST]'
}


while [ "$#" -gt 0 ]
do
	case "$1" in
	-h | -help | --help)
		usage
		exit 0
		;;
	-b | -bench | --bench)
		if [ "$#" -lt 2 ]
		then
			exit 1
		fi
		selectedBenchmarks=$2
		shift 2
		;;
	*)
		printf 'Unknown option: %s\n' "$1" >&2
		usage >&2
		exit 1
		;;
	esac
done

if [ -z "$selectedBenchmarks" ]
then
	selectedBenchmarks=string,integer,fpu
fi
temporaryDirectory=$(mktemp -d "${TMPDIR:-/tmp}/multi-lang-benchmarks.XXXXXX")
trap 'rm -rf "$temporaryDirectory"' EXIT HUP INT TERM

update_benchmark( )
{
	benchmark=$1
	directory=$2
	output=$temporaryDirectory/$benchmark.txt
	outputPipe=$temporaryDirectory/$benchmark.pipe
	readme=$projectDirectory/benchmarks/$directory/README.md
	assets=$projectDirectory/benchmarks/$directory/assets

	printf '\nUpdating %s benchmark...\n' "$directory"
	mkfifo "$outputPipe"
	tee "$output" < "$outputPipe" &
	teeProcess=$!
	if "$projectDirectory/run" -bench "$benchmark" > "$outputPipe"
	then
		wait "$teeProcess"
	else
		runStatus=$?
		wait "$teeProcess" || true
		return "$runStatus"
	fi
	awk '
		/^!\[Start time\]/ { skipBlankLine = 1; next }
		skipBlankLine && /^$/ { skipBlankLine = 0; next }
		/^\| Language \|/ { replacing = 1; next }
		replacing && /^\|/ { next }
		replacing {
			print "| Language | Total (s) | Benchmark (s) | Binary (KiB) |" \
				" Memory (MiB) |"
			print "| --- | ---: | ---: | ---: | ---: |"
			while ((getline line < output) > 0) {
				if (line ~ /^[^|]+ \|[[:space:]]*[0-9.]+/) {
					split(line, values, "|")
					for (field = 1; field <= 5; field++) {
						gsub(/^[[:space:]]+|[[:space:]]+$/, "", \
							values[field])
					}
					name = values[1]
					total = values[2]
					benchmark = values[3]
					binary = values[4]
					memory = values[5]
					sub(/ MiB$/, "", memory)
					printf "| %s | %.3f | %.3f | %s | %s |\n", \
						name, total, benchmark, binary, memory
				}
			}
			close(output)
			replacing = 0
		}
		{ print }
	' output="$output" "$readme" > "$temporaryDirectory/README.md"
	mv "$temporaryDirectory/README.md" "$readme"
	"$projectDirectory/util/generate-benchmark-chart.sh" "$readme" \
		"$assets/results-time.svg" "$directory (Benchmark Time in Seconds)" \
		benchmark
	"$projectDirectory/util/generate-benchmark-chart.sh" "$readme" \
		"$assets/results-memory.svg" "$directory (Peak RSS in MiB)" memory
	"$projectDirectory/util/generate-benchmark-chart.sh" "$readme" \
		"$assets/results-binary-size.svg" "$directory (Binary Size in KiB)" \
		binary
	printf 'Updated %s benchmark.\n\n' "$directory"
}

oldIfs=$IFS
IFS=,
for benchmark in $selectedBenchmarks
do
	case "$benchmark" in
		string) update_benchmark string String ;;
		integer) update_benchmark integer Integer ;;
		fpu) update_benchmark fpu FPU ;;
		*)
			IFS=$oldIfs
			printf 'Unknown benchmark: %s\n' "$benchmark" >&2
			exit 1
			;;
	esac
done
IFS=$oldIfs
