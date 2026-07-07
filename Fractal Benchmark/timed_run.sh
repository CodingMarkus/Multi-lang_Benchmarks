#!/bin/sh

set -euh

count=20
selectedTests=

print_usage( )
{
	cat <<EOF
Usage: ./timed_run.sh [options] [iterations]

Run the timed Fractal Benchmark.

Options:
	-h, -help, --help
		Show this help and exit.
	-it, -iterations, --iterations COUNT
		Run each selected test COUNT times.
	-t, -tests, --tests LIST
		Run only the comma-separated tests from LIST.

Examples:
	./timed_run.sh
	./timed_run.sh -it 20
	./timed_run.sh -tests c,rust,nodei
	./timed_run.sh 20

Available tests:
	c        C
	rust     Rust
	swift    Swift
	go       Go
	java     Java
	cs       C#
	node     Node.js
	bun      Bun
	bunc     Bun compiled
	javai    Java interpreted
	nodei    Node.js interpreted
	qjs      QuickJS
	py       Python
	ruby     Ruby
	php      PHP
	perl     Perl
	lua      Lua
EOF
}

die_usage( )
{
	printf "%s\n\n" "$1" >&2
	print_usage >&2
	exit 1
}

validate_count( )
{
	case "$1" in
	"" | *[!0-9]*)
		die_usage "Iterations must be a positive integer."
		;;
	0)
		die_usage "Iterations must be greater than zero."
		;;
	esac
}

is_known_test( )
{
	case "$1" in
	c | rust | swift | go | java | cs | node | bun | bunc | javai | \
		nodei | qjs | py | ruby | php | perl | lua)
		return 0
		;;
	esac

	return 1
}

validate_tests( )
{
	oldIfs=$IFS
	IFS=,
	for testName in $selectedTests
	do
		if ! is_known_test "$testName"
		then
			IFS=$oldIfs
			die_usage "Unknown test: $testName"
		fi
	done
	IFS=$oldIfs
}

want_test( )
{
	if [ -z "$selectedTests" ]
	then
		return 0
	fi

	case ",$selectedTests," in
	*,"$1",*)
		return 0
		;;
	esac

	return 1
}

parse_args( )
{
	havePositionalCount=false

	while [ $# -gt 0 ]
	do
		case "$1" in
		-h | -help | --help)
			print_usage
			exit 0
			;;
		-it | -iterations | --iterations)
			[ $# -ge 2 ] || die_usage "Missing value for $1."
			validate_count "$2"
			count="$2"
			shift 2
			;;
		-t | -tests | --tests)
			[ $# -ge 2 ] || die_usage "Missing value for $1."
			[ -n "$2" ] || die_usage "Test list must not be empty."
			selectedTests="$2"
			shift 2
			;;
		--)
			shift
			break
			;;
		-*)
			die_usage "Unknown option: $1"
			;;
		*)
			if [ "$havePositionalCount" = true ]
			then
				die_usage "Only one positional iterations value is allowed."
			fi
			validate_count "$1"
			count="$1"
			havePositionalCount=true
			shift
			;;
		esac
	done

	if [ $# -gt 0 ]
	then
		die_usage "Unexpected argument: $1"
	fi

	if [ -n "$selectedTests" ]
	then
		validate_tests
	fi
}

parse_args "$@"

if [ -n "$selectedTests" ]
then
	printf "Performing %s iterations for tests: %s.\n" \
		"$count" "$selectedTests" >&2
else
	printf "Performing %s iterations for all tests.\n" "$count" >&2
fi


tmp=$( mktemp -d )
currentDir=$( pwd )
scriptDir=$( CDPATH= cd -- "$( dirname -- "$0" )" && pwd )
timeLog="$tmp/time.log"
okFile="$tmp/benchmark.ok"

cleanup( )
{
	cd "$currentDir"
	rm -rf "$tmp"
}

interrupt( )
{
	trap - EXIT HUP INT TERM
	cleanup
	exit 130
}

trap cleanup EXIT
trap interrupt HUP INT TERM

have_command( )
{
	command -v "$1" >/dev/null 2>&1
}

format_mib( )
{
	awk "BEGIN { printf \"%.3f\", $1 / 1048576 }"
}

timeMode=none
timeFlags=
timeCommand=/usr/bin/time

detect_time_mode( )
{
	if [ ! -x "$timeCommand" ]
	then
		return
	fi

	case "$( uname -s )" in
	Darwin)
		timeMode=darwin
		timeFlags=-l
		;;
	Linux)
		timeMode=gnu
		timeFlags=-v
		;;
	esac
}

extract_elapsed( )
{
	if [ "$timeMode" = darwin ]
	then
		awk '/ real / { print $1 " s"; exit }' "$timeLog"
		return
	fi

	if [ "$timeMode" = gnu ]
	then
		awk -F': ' \
			'/Elapsed \(wall clock\) time/ { print $2; exit }' \
			"$timeLog"
		return
	fi

	printf "n/a"
}

extract_max_rss( )
{
	if [ "$timeMode" = darwin ]
	then
		awk '/maximum resident set size$/ { print $1; exit }' "$timeLog"
		return
	fi

	if [ "$timeMode" = gnu ]
	then
		awk -F': ' \
			'/Maximum resident set size \(kbytes\)/ { print $2; exit }' \
			"$timeLog"
		return
	fi

	printf ""
}

print_measurement( )
{
	label=$1
	elapsed=$( extract_elapsed )
	maxRss=$( extract_max_rss )

	if [ -n "$maxRss" ]
	then
		if [ "$timeMode" = gnu ]
		then
			maxRss=$(( maxRss * 1024 ))
		fi

		printf "%s: %s, %s MiB max RSS\n" \
			"$label" "$elapsed" "$( format_mib "$maxRss" )"
	else
		printf "%s: %s\n" "$label" "$elapsed"
	fi
}

measure_run( )
{
	label=$1
	script=$2
	wrappedScript=$script'
: > "$okFile"
'
	rm -f "$okFile"

	if env count="$count" tmp="$tmp" CC="$CC" pythonCmd="$pythonCmd" \
		okFile="$okFile" "$timeCommand" "$timeFlags" \
		sh -eu -c "$wrappedScript" 2>"$timeLog"
	then
		print_measurement "$label"
	elif [ -f "$okFile" ] && [ -n "$( extract_elapsed )" ]
	then
		print_measurement "$label"
	else
		cat "$timeLog" >&2
		exit 1
	fi
}

detect_time_mode
if [ "$timeMode" = none ]
then
	printf "No supported time tool found.\n" >&2
	exit 1
fi

cp -R -- "$scriptDir"/. "$tmp/"
cd "$tmp"


# Test C
CC=${CC:-clang}
pythonCmd=
if have_command python
then
	pythonCmd=python
elif have_command python3
then
	pythonCmd=python3
fi

if want_test c
then
	if have_command "$CC"
	then
		"$CC" -O3 -o mandelbrot-c mandelbrot.c
		measure_run "C" '
			./mandelbrot-c "$count" >/dev/null
		'
	else
		printf "Skipping C benchmark because %s was not found.\n" \
			"$CC" >&2
	fi
fi

# Test Rust
if want_test rust
then
	if have_command rustc
	then
		rustc -C opt-level=3 -o mandelbrot-rust mandelbrot.rs
		measure_run "Rust" '
			./mandelbrot-rust "$count" >/dev/null
		'
	else
		printf "Skipping Rust benchmark because rustc was not found.\n" \
			>&2
	fi
fi

# Test Swift
if want_test swift
then
	if have_command swiftc
	then
		swiftc -O -o mandelbrot-swift mandelbrot.swift
		measure_run "Swift" '
			./mandelbrot-swift "$count" >/dev/null
		'
	else
		printf "Skipping Swift benchmark because swiftc was not found.\n" \
			>&2
	fi
fi

# Test Go
if want_test go
then
	if have_command go
	then
		go build -o mandelbrot-go mandelbrot.go
		measure_run "Go" '
			./mandelbrot-go "$count" >/dev/null
		'
	else
		printf "Skipping Go benchmark because go was not found.\n" >&2
	fi
fi

# Test Java
if want_test java
then
	if have_command javac && have_command java
	then
		javac -d . mandelbrot.java
		measure_run "Java" '
			java -cp . Mandelbrot "$count" >/dev/null
		'
	else
		printf "Skipping Java benchmark because javac or java was not " \
			"found.\n" >&2
	fi
fi

# Test C#
if want_test cs
then
	if have_command mcs && have_command mono
	then
		mcs -optimize+ -out:mandelbrot-mono mandelbrot.cs
		measure_run "C#" '
			mono --optimize=all mandelbrot-mono "$count" >/dev/null
		'
	else
		printf "Skipping C# benchmark because mcs or mono was not " \
			"found.\n" >&2
	fi
fi

# Test JavaScript (Node.js)
if want_test node
then
	if have_command node
	then
		measure_run "Node.js JavaScript" '
			node mandelbrot.node.js "$count" >/dev/null
		'
	else
		printf "Skipping Node.js benchmark because node was not found.\n" \
			>&2
	fi
fi

# Test JavaScript (Bun)
if want_test bun
then
	if have_command bun
	then
		measure_run "Bun JavaScript" '
			bun mandelbrot.node.js "$count" >/dev/null
		'
	else
		printf "Skipping Bun benchmark because bun was not found.\n" >&2
	fi
fi

# Test JavaScript (Bun, Compiled)
if want_test bunc
then
	if have_command bun
	then
		bun build --compile --outfile=mandelbrot-bun \
			mandelbrot.node.js >/dev/null 2>&1
		measure_run "Bun (compiled) JavaScript" '
			./mandelbrot-bun "$count" >/dev/null
		'
	else
		printf "Skipping Bun compiled benchmark because bun was not " \
			"found.\n" >&2
	fi
fi

# Test Java (Interpreted)
if want_test javai
then
	if have_command javac && have_command java
	then
		javac -d . mandelbrot.java
		measure_run "Interpreted Java" '
			java -Xint -cp . Mandelbrot "$count" >/dev/null
		'
	else
		printf "Skipping interpreted Java benchmark because javac or " \
			"java was not found.\n" >&2
	fi
fi

# Test JavaScript (Node.js, Interpreted)
if want_test nodei
then
	if have_command node
	then
		measure_run "Node.js (Interpreted) JavaScript" '
			node --jitless mandelbrot.node.js "$count" >/dev/null
		'
	else
		printf "Skipping interpreted Node.js benchmark because node " \
			"was not found.\n" >&2
	fi
fi

# Test JavaScript (QuickJS)
if want_test qjs
then
	if have_command qjs
	then
		measure_run "QuickJS JavaScript" '
			qjs --std mandelbrot.quickjs.js "$count" >/dev/null
		'
	else
		printf "Skipping QuickJS benchmark because qjs was not " \
			"found.\n" >&2
	fi
fi

# Test Python
if want_test py
then
	if [ -n "$pythonCmd" ]
	then
		measure_run "Python" '
			"$pythonCmd" mandelbrot.py "$count" >/dev/null
		'
	else
		printf "Skipping Python benchmark because python was not " \
			"found.\n" >&2
	fi
fi

# Test Ruby
if want_test ruby
then
	if have_command ruby
	then
		measure_run "Ruby" '
			ruby mandelbrot.rb "$count" >/dev/null
		'
	else
		printf "Skipping Ruby benchmark because ruby was not found.\n" \
			>&2
	fi
fi

# Test PHP
if want_test php
then
	if have_command php
	then
		measure_run "PHP" '
			php mandelbrot.php "$count" >/dev/null
		'
	else
		printf "Skipping PHP benchmark because php was not found.\n" >&2
	fi
fi

# Test Perl
if want_test perl
then
	if have_command perl
	then
		measure_run "Perl" '
			perl mandelbrot.pl "$count" >/dev/null
		'
	else
		printf "Skipping Perl benchmark because perl was not found.\n" \
			>&2
	fi
fi

# Lua
if want_test lua
then
	if have_command lua
	then
		measure_run "Lua" '
			lua mandelbrot.lua "$count" >/dev/null
		'
	else
		printf "Skipping Lua benchmark because lua was not found.\n" >&2
	fi
fi
