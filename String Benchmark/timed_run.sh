#!/bin/sh

set -euh

count=40
if [ $# -gt 0 ]
then
	count="$1"
	echo "Performing $count iterations." >&2
else
	echo "No number of iterations given, using default of $count." >&2
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

if have_command "$CC"
then
	"$CC" -O3 -o string-benchmark-c string-benchmark.c
	measure_run "C" '
		./string-benchmark-c "$count" >/dev/null
	'
else
	printf "Skipping C benchmark because %s was not found.\n" "$CC" >&2
fi

# Test C (UTF-16)
if have_command "$CC"
then
	"$CC" -O3 -o string-benchmark-c-wchar string-benchmark-wchar.c
	measure_run "C UTF-16" '
		./string-benchmark-c-wchar "$count" >/dev/null
	'
else
	printf "Skipping C UTF-16 benchmark because %s was not found.\n" \
		"$CC" >&2
fi

# Test Rust
if have_command rustc
then
	rustc -C opt-level=3 -o string-benchmark-rust string-benchmark.rs
	measure_run "Rust" '
		./string-benchmark-rust "$count" >/dev/null
	'
else
	printf "Skipping Rust benchmark because rustc was not found.\n" >&2
fi

# Test Rust (UTF-16)
if have_command rustc
then
	rustc -C opt-level=3 -o string-benchmark-rust-unicode \
		string-benchmark-unicode.rs
	measure_run "Rust UTF-16" '
		./string-benchmark-rust-unicode "$count" >/dev/null
	'
else
	printf "Skipping Rust UTF-16 benchmark because rustc was not found.\n" \
		>&2
fi

# Test Swift
if have_command swiftc
then
	swiftc -O -o string-benchmark-swift string-benchmark.swift
	measure_run "Swift" '
		./string-benchmark-swift "$count" >/dev/null
	'
else
	printf "Skipping Swift benchmark because swiftc was not found.\n" >&2
fi

# Test Objective-C
if have_command "$CC"
then
	"$CC" -O3 -fobjc-arc -framework Foundation \
		-o string-benchmark-objc string-benchmark.m
	measure_run "Objective-C" '
		./string-benchmark-objc "$count" >/dev/null
	'
else
	printf "Skipping Objective-C benchmark because %s was not found.\n" \
		"$CC" >&2
fi

# Test Go
if have_command go
then
	go build -o string-benchmark-go string-benchmark.go
	measure_run "Go" '
		./string-benchmark-go "$count" >/dev/null
	'
else
	printf "Skipping Go benchmark because go was not found.\n" >&2
fi

# Test Java
if have_command javac && have_command java
then
	javac -d . string-benchmark.java
	measure_run "Java" '
		java -cp . StringBenchmark "$count" >/dev/null
	'
else
	printf "Skipping Java benchmark because javac or java was not found.\n" \
		>&2
fi

# Test C#
if have_command mcs && have_command mono
then
	mcs -optimize+ -out:string-benchmark-mono string-benchmark.cs
	measure_run "C#" '
		mono --optimize=all string-benchmark-mono "$count" >/dev/null
	'
else
	printf "Skipping C# benchmark because mcs or mono was not found.\n" >&2
fi

# Test JavaScript (Node.js)
if have_command node
then
	measure_run "Node.js JavaScript" '
		node string-benchmark.node.js "$count" >/dev/null
	'
else
	printf "Skipping Node.js benchmark because node was not found.\n" >&2
fi

# Test JavaScript (Bun)
if have_command bun
then
	measure_run "Bun JavaScript" '
		bun string-benchmark.node.js "$count" >/dev/null
	'
else
	printf "Skipping Bun benchmark because bun was not found.\n" >&2
fi

# Test JavaScript (Bun, Compiled)
if have_command bun
then
	bun build --compile --outfile=string-benchmark-bun string-benchmark.node.js >/dev/null 2>&1
	measure_run "Bun (compiled) JavaScript" '
		./string-benchmark-bun "$count" >/dev/null
	'
else
	printf "Skipping Bun compiled benchmark because bun was not found.\n" >&2
fi

# Test Java (Interpreted)
if have_command javac && have_command java
then
	javac -d . string-benchmark.java
	measure_run "Interpreted Java" '
		java -Xint -cp . StringBenchmark "$count" >/dev/null
	'
else
	printf "Skipping interpreted Java benchmark because " \
		"javac or java was not found.\n" >&2
fi

# Test JavaScript (Node.js, Interpreted)
if have_command node
then
	measure_run "Node.js (Interpreted) JavaScript" '
		node --jitless string-benchmark.node.js "$count" >/dev/null
	'
else
	printf "Skipping interpreted Node.js benchmark because " \
		"node was not found.\n" >&2
fi

# Test JavaScript (QuickJS)
if have_command qjs
then
	measure_run "QuickJS JavaScript" '
		qjs --std string-benchmark.quickjs.js "$count" >/dev/null
	'
else
	printf "Skipping QuickJS benchmark because qjs was not found.\n" >&2
fi

# Test Python
if [ -n "$pythonCmd" ]
then
	measure_run "Python" '
		"$pythonCmd" string-benchmark.py "$count" >/dev/null
	'
else
	printf "Skipping Python benchmark because python was not found.\n" >&2
fi

# Test Ruby
if have_command ruby
then
	measure_run "Ruby" '
		ruby string-benchmark.rb "$count" >/dev/null
	'
else
	printf "Skipping Ruby benchmark because ruby was not found.\n" >&2
fi

# Test PHP
if have_command php
then
	measure_run "PHP" '
		php string-benchmark.php "$count" >/dev/null
	'
else
	printf "Skipping PHP benchmark because php was not found.\n" >&2
fi

# Test Perl
if have_command perl
then
	measure_run "Perl" '
		perl string-benchmark.pl "$count" >/dev/null
	'
else
	printf "Skipping Perl benchmark because perl was not found.\n" >&2
fi

# Lua
if have_command lua
then
	measure_run "Lua" '
		lua string-benchmark.lua "$count" >/dev/null
	'
else
	printf "Skipping Lua benchmark because lua was not found.\n" >&2
fi
