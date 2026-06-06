#!/bin/sh

set -euh

count=20
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
	"$CC" -O3 -o mandelbrot-c mandelbrot.c
	sleep 1
	./mandelbrot-c "$count" >/dev/null
	sleep 1
else
	printf "Skipping C benchmark because %s was not found.\n" "$CC" >&2
fi

# Test Rust
if have_command rustc
then
	rustc -C opt-level=3 -o mandelbrot-rust mandelbrot.rs
	sleep 1
	./mandelbrot-rust "$count" >/dev/null
	sleep 1
else
	printf "Skipping Rust benchmark because rustc was not found.\n" >&2
fi

# Test Swift
if have_command swift
then
	swift -O mandelbrot.swift "$count" >/dev/null
	sleep 1
else
	printf "Skipping Swift benchmark because swift was not found.\n" >&2
fi

# Test Go
if have_command go
then
	go build -o mandelbrot-go mandelbrot.go
	sleep 1
	./mandelbrot-go "$count" >/dev/null
	sleep 1
else
	printf "Skipping Go benchmark because go was not found.\n" >&2
fi


# Test Java
if have_command javac && have_command java
then
	javac -d . mandelbrot.java
	java -cp . Mandelbrot "$count" >/dev/null
	sleep 1
else
	printf "Skipping Java benchmark because javac or java was not found.\n" >&2
fi

# Test C#
if have_command mcs && have_command mono
then
	mcs -optimize+ -out:mandelbrot-mono mandelbrot.cs
	sleep 1
	mono --optimize=all mandelbrot-mono "$count" >/dev/null
	sleep 1
else
	printf "Skipping C# benchmark because mcs or mono was not found.\n" >&2
fi

# Test JavaScript (Node.js)
if have_command node
then
	printf "Node.js " >&2
	node mandelbrot.node.js "$count" >/dev/null
	sleep 1
else
	printf "Skipping Node.js benchmark because node was not found.\n" >&2
fi

# Test JavaScript (Bun)
if have_command bun
then
	printf "Bun " >&2
	bun mandelbrot.node.js "$count" >/dev/null
	sleep 1
else
	printf "Skipping Bun benchmark because bun was not found.\n" >&2
fi

# Test JavaScript (Bun, Compiled)
if have_command bun
then
	bun build --compile --outfile=mandelbrot-bun mandelbrot.node.js >/dev/null 2>&1
	sleep 1
	printf "Bun (compiled) " >&2
	./mandelbrot-bun "$count" >/dev/null
	sleep 1
else
	printf "Skipping Bun compiled benchmark because bun was not found.\n" >&2
fi

# Test Java (Interpreted)
if have_command javac && have_command java
then
	printf "Interpreted " >&2
	java -Xint -cp . Mandelbrot "$count" >/dev/null
	sleep 1
else
	printf "Skipping interpreted Java benchmark because javac or java was not found.\n" >&2
fi

# Test JavaScript (Node.js, Interpreted)
if have_command node
then
	printf "Node.js (Interpreted) " >&2
	node --jitless mandelbrot.node.js "$count" >/dev/null
	sleep 1
else
	printf "Skipping interpreted Node.js benchmark because node was not found.\n" >&2
fi

# Test JavaScript (QuickJS)
if have_command qjs
then
	qjs --std mandelbrot.quickjs.js "$count" >/dev/null
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
	"$pythonCmd" mandelbrot.py "$count" >/dev/null
	sleep 1
else
	printf "Skipping Python benchmark because python was not found.\n" >&2
fi

# Test Ruby
if have_command ruby
then
	ruby mandelbrot.rb "$count" >/dev/null
	sleep 1
else
	printf "Skipping Ruby benchmark because ruby was not found.\n" >&2
fi

# Test PHP
if have_command php
then
	php mandelbrot.php "$count" >/dev/null
	sleep 1
else
	printf "Skipping PHP benchmark because php was not found.\n" >&2
fi

# Test Perl
if have_command perl
then
	perl mandelbrot.pl "$count" >/dev/null
	sleep 1
else
	printf "Skipping Perl benchmark because perl was not found.\n" >&2
fi

# Lua
if have_command lua
then
	lua mandelbrot.lua "$count" >/dev/null
	sleep 1
else
	printf "Skipping Lua benchmark because lua was not found.\n" >&2
fi
