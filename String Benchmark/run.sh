#!/bin/sh

set -euh

count=40
selectedTests=

print_usage( )
{
	cat <<EOF
Usage: ./run.sh [options] [iterations]

Run the String Benchmark.

Options:
	-h, -help, --help
		Show this help and exit.
	-it, -iterations, --iterations COUNT
		Run each selected test COUNT times.
	-t, -tests, --tests LIST
		Run only the comma-separated tests from LIST.

Examples:
	./run.sh
	./run.sh -it 20
	./run.sh -tests c,rust,nodei
	./run.sh 20

Available tests:
	c        C
	c16      C UTF-16
	rust     Rust
	rust16   Rust UTF-16
	swift    Swift
	objc     Objective-C
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
	c | c16 | rust | rust16 | swift | objc | go | java | cs | node | \
		bun | bunc | javai | nodei | qjs | py | ruby | php | perl | \
		lua)
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

cp -R -- "$scriptDir"/. "$tmp/"
cd "$tmp"


# Test C
CC=${CC:-clang}
if want_test c
then
	if have_command "$CC"
	then
		"$CC" -O3 -o string-benchmark-c string-benchmark.c
		sleep 1
		./string-benchmark-c "$count" >/dev/null
		sleep 1
	else
		printf "Skipping C benchmark because %s was not found.\n" \
			"$CC" >&2
	fi
fi

# Test C (UTF-16)
if want_test c16
then
	if have_command "$CC"
	then
		"$CC" -O3 -o string-benchmark-c-wchar string-benchmark-wchar.c
		sleep 1
		./string-benchmark-c-wchar "$count" >/dev/null
		sleep 1
	else
		printf "Skipping C UTF-16 benchmark because %s was not found.\n" \
			"$CC" >&2
	fi
fi

# Test Rust
if want_test rust
then
	if have_command rustc
	then
		rustc -C opt-level=3 -o string-benchmark-rust \
			string-benchmark.rs
		sleep 1
		./string-benchmark-rust "$count" >/dev/null
		sleep 1
	else
		printf "Skipping Rust benchmark because rustc was not found.\n" \
			>&2
	fi
fi

# Test Rust (UTF-16)
if want_test rust16
then
	if have_command rustc
	then
		rustc -C opt-level=3 -o string-benchmark-rust-unicode \
			string-benchmark-unicode.rs
		sleep 1
		./string-benchmark-rust-unicode "$count" >/dev/null
		sleep 1
	else
		printf "Skipping Rust UTF-16 benchmark because rustc was not " \
			"found.\n" >&2
	fi
fi

# Test Swift
if want_test swift
then
	if have_command swift
	then
		CLANG_MODULE_CACHE_PATH="$tmp" \
			swift -module-cache-path "$tmp" -O \
			string-benchmark.swift "$count" >/dev/null
		sleep 1
	else
		printf "Skipping Swift benchmark because swift was not found.\n" \
			>&2
	fi
fi

# Test Objective-C
if want_test objc
then
	if have_command "$CC"
	then
		"$CC" -O3 -fobjc-arc -framework Foundation \
			-o string-benchmark-objc string-benchmark.m
		sleep 1
		./string-benchmark-objc "$count" >/dev/null
		sleep 1
	else
		printf "Skipping Objective-C benchmark because %s was not " \
			"found.\n" "$CC" >&2
	fi
fi

# Test Go
if want_test go
then
	if have_command go
	then
		go build -o string-benchmark-go string-benchmark.go
		sleep 1
		./string-benchmark-go "$count" >/dev/null
		sleep 1
	else
		printf "Skipping Go benchmark because go was not found.\n" >&2
	fi
fi

# Test Java
if want_test java
then
	if have_command javac && have_command java
	then
		javac -d . string-benchmark.java
		java -cp . StringBenchmark "$count" >/dev/null
		sleep 1
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
		mcs -optimize+ -out:string-benchmark-mono string-benchmark.cs
		sleep 1
		mono --optimize=all string-benchmark-mono "$count" >/dev/null
		sleep 1
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
		printf "Node.js " >&2
		node string-benchmark.node.js "$count" >/dev/null
		sleep 1
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
		printf "Bun " >&2
		bun string-benchmark.node.js "$count" >/dev/null
		sleep 1
	else
		printf "Skipping Bun benchmark because bun was not found.\n" >&2
	fi
fi

# Test JavaScript (Bun, Compiled)
if want_test bunc
then
	if have_command bun
	then
		bun build --compile --outfile=string-benchmark-bun \
			string-benchmark.node.js >/dev/null 2>&1
		sleep 1
		printf "Bun (compiled) " >&2
		./string-benchmark-bun "$count" >/dev/null
		sleep 1
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
		printf "Interpreted " >&2
		javac -d . string-benchmark.java
		java -Xint -cp . StringBenchmark "$count" >/dev/null
		sleep 1
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
		printf "Node.js (Interpreted) " >&2
		node --jitless string-benchmark.node.js "$count" >/dev/null
		sleep 1
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
		qjs --std string-benchmark.quickjs.js "$count" >/dev/null
		sleep 1
	else
		printf "Skipping QuickJS benchmark because qjs was not " \
			"found.\n" >&2
	fi
fi

# Test Python
pythonCmd=
if have_command python
then
	pythonCmd=python
elif have_command python3
then
	pythonCmd=python3
fi
if want_test py
then
	if [ -n "$pythonCmd" ]
	then
		"$pythonCmd" string-benchmark.py "$count" >/dev/null
		sleep 1
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
		ruby string-benchmark.rb "$count" >/dev/null
		sleep 1
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
		php string-benchmark.php "$count" >/dev/null
		sleep 1
	else
		printf "Skipping PHP benchmark because php was not found.\n" >&2
	fi
fi

# Test Perl
if want_test perl
then
	if have_command perl
	then
		perl string-benchmark.pl "$count" >/dev/null
		sleep 1
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
		lua string-benchmark.lua "$count" >/dev/null
		sleep 1
	else
		printf "Skipping Lua benchmark because lua was not found.\n" >&2
	fi
fi
