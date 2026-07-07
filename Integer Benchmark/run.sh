#!/bin/sh

set -euh

count=4
selectedTests=

print_usage( )
{
	cat <<EOF
Usage: ./run.sh [options] [iterations]

Run the Integer Benchmark.

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
		"$CC" -O3 -o sha256-c sha256.c
		sleep 1
		./sha256-c "$count" >/dev/null
		sleep 1
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
		rustc -C opt-level=3 -o sha256-rust sha256.rs
		sleep 1
		./sha256-rust "$count" >/dev/null
		sleep 1
	else
		printf "Skipping Rust benchmark because rustc was not found.\n" \
			>&2
	fi
fi

# Test Swift
if want_test swift
then
	if have_command swift
	then
		CLANG_MODULE_CACHE_PATH="$tmp" \
			swift -module-cache-path "$tmp" -O \
			sha256.swift "$count" >/dev/null
		sleep 1
	else
		printf "Skipping Swift benchmark because swift was not found.\n" \
			>&2
	fi
fi

# Test Go
if want_test go
then
	if have_command go
	then
		go build -o sha256-go sha256.go
		sleep 1
		./sha256-go "$count" >/dev/null
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
		javac -d . sha256.java
		java -cp . SHA256Benchmark "$count" >/dev/null
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
		mcs -optimize+ -out:sha256-mono sha256.cs
		sleep 1
		mono --optimize=all sha256-mono "$count" >/dev/null
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
		node sha256.node.js "$count" >/dev/null
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
		bun sha256.node.js "$count" >/dev/null
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
		bun build --compile --outfile=sha256-bun \
			sha256.node.js >/dev/null 2>&1
		sleep 1
		printf "Bun (compiled) " >&2
		./sha256-bun "$count" >/dev/null
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
		javac -d . sha256.java
		java -Xint -cp . SHA256Benchmark "$count" >/dev/null
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
		node --jitless sha256.node.js "$count" >/dev/null
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
		qjs --std sha256.quickjs.js "$count" >/dev/null
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
		"$pythonCmd" sha256.py "$count" >/dev/null
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
		ruby sha256.rb "$count" >/dev/null
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
		php sha256.php "$count" >/dev/null
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
		perl sha256.pl "$count" >/dev/null
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
		lua sha256.lua "$count" >/dev/null
		sleep 1
	else
		printf "Skipping Lua benchmark because lua was not found.\n" >&2
	fi
fi
