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
if have_command "$CC"
then
	"$CC" -O3 -o string-benchmark-c string-benchmark.c
	sleep 1
	./string-benchmark-c "$count" >/dev/null
	sleep 1
else
	printf "Skipping C benchmark because %s was not found.\n" "$CC" >&2
fi

# Test C (wchar_t)
if have_command "$CC"
then
	"$CC" -O3 -o string-benchmark-c-wchar string-benchmark-wchar.c
	sleep 1
	./string-benchmark-c-wchar "$count" >/dev/null
	sleep 1
else
	printf "Skipping C wchar benchmark because %s was not found.\n" \
		"$CC" >&2
fi

# Test Rust
if have_command rustc
then
	rustc -C opt-level=3 -o string-benchmark-rust string-benchmark.rs
	sleep 1
	./string-benchmark-rust "$count" >/dev/null
	sleep 1
else
	printf "Skipping Rust benchmark because rustc was not found.\n" >&2
fi

# Test Rust (Unicode scalar values)
if have_command rustc
then
	rustc -C opt-level=3 -o string-benchmark-rust-unicode \
		string-benchmark-unicode.rs
	sleep 1
	./string-benchmark-rust-unicode "$count" >/dev/null
	sleep 1
else
	printf "Skipping Rust Unicode benchmark because rustc was not found.\n" \
		>&2
fi

# Test Swift
if have_command swift
then
	CLANG_MODULE_CACHE_PATH="$tmp" \
		swift -module-cache-path "$tmp" -O \
		string-benchmark.swift "$count" >/dev/null
	sleep 1
else
	printf "Skipping Swift benchmark because swift was not found.\n" >&2
fi

# Test Objective-C
if have_command "$CC"
then
	"$CC" -O3 -fobjc-arc -framework Foundation \
		-o string-benchmark-objc string-benchmark.m
	sleep 1
	./string-benchmark-objc "$count" >/dev/null
	sleep 1
else
	printf "Skipping Objective-C benchmark because %s was not found.\n" \
		"$CC" >&2
fi

# Test Go
if have_command go
then
	go build -o string-benchmark-go string-benchmark.go
	sleep 1
	./string-benchmark-go "$count" >/dev/null
	sleep 1
else
	printf "Skipping Go benchmark because go was not found.\n" >&2
fi

# Test Java
if have_command javac && have_command java
then
	javac -d . string-benchmark.java
	java -cp . StringBenchmark "$count" >/dev/null
	sleep 1
else
	printf "Skipping Java benchmark because javac or java was not found.\n" >&2
fi

# Test C#
if have_command mcs && have_command mono
then
	mcs -optimize+ -out:string-benchmark-mono string-benchmark.cs
	sleep 1
	mono --optimize=all string-benchmark-mono "$count" >/dev/null
	sleep 1
else
	printf "Skipping C# benchmark because mcs or mono was not found.\n" >&2
fi

# Test JavaScript (Node.js)
if have_command node
then
	printf "Node.js " >&2
	node string-benchmark.node.js "$count" >/dev/null
	sleep 1
else
	printf "Skipping Node.js benchmark because node was not found.\n" >&2
fi

# Test JavaScript (Bun)
if have_command bun
then
	printf "Bun " >&2
	bun string-benchmark.node.js "$count" >/dev/null
	sleep 1
else
	printf "Skipping Bun benchmark because bun was not found.\n" >&2
fi

# Test JavaScript (Bun, Compiled)
if have_command bun
then
	bun build --compile --outfile=string-benchmark-bun string-benchmark.node.js >/dev/null 2>&1
	sleep 1
	printf "Bun (compiled) " >&2
	./string-benchmark-bun "$count" >/dev/null
	sleep 1
else
	printf "Skipping Bun compiled benchmark because bun was not found.\n" >&2
fi

# Test Java (Interpreted)
if have_command javac && have_command java
then
	printf "Interpreted " >&2
	java -Xint -cp . StringBenchmark "$count" >/dev/null
	sleep 1
else
	printf "Skipping interpreted Java benchmark because javac or java was not found.\n" >&2
fi

# Test JavaScript (Node.js, Interpreted)
if have_command node
then
	printf "Interpreted " >&2
	node --jitless string-benchmark.node.js "$count" >/dev/null
	sleep 1
else
	printf "Skipping interpreted Node.js benchmark because node was not found.\n" >&2
fi

# Test JavaScript (QuickJS)
if have_command qjs
then
	qjs --std string-benchmark.quickjs.js "$count" >/dev/null
	sleep 1
else
	printf "Skipping QuickJS benchmark because qjs was not found.\n" >&2
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
if [ -n "$pythonCmd" ]
then
	"$pythonCmd" string-benchmark.py "$count" >/dev/null
	sleep 1
else
	printf "Skipping Python benchmark because python was not found.\n" >&2
fi

# Test Ruby
if have_command ruby
then
	ruby string-benchmark.rb "$count" >/dev/null
	sleep 1
else
	printf "Skipping Ruby benchmark because ruby was not found.\n" >&2
fi

# Test PHP
if have_command php
then
	php string-benchmark.php "$count" >/dev/null
	sleep 1
else
	printf "Skipping PHP benchmark because php was not found.\n" >&2
fi

# Test Perl
if have_command perl
then
	perl string-benchmark.pl "$count" >/dev/null
	sleep 1
else
	printf "Skipping Perl benchmark because perl was not found.\n" >&2
fi

# Lua
if have_command lua
then
	lua string-benchmark.lua "$count" >/dev/null
	sleep 1
else
	printf "Skipping Lua benchmark because lua was not found.\n" >&2
fi
