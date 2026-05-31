#!/bin/bash

TARGET_SIZE=$((1024 * 1024))
WORD_COUNT=16
LINE_LIMIT=80
FNV_OFFSET=-3750763034362895579
FNV_PRIME=1099511628211
REFERENCE_HASH=3877090371369832560

words=(
	"I"
	"we"
	"cat"
	"tree"
	"apple"
	"bridge"
	"lantern"
	"mountain"
	"blueberry"
	"basketball"
	"grandfather"
	"microbiology"
	"determination"
	"responsibility"
	"experimentation"
	"counterclockwise"
)


function random_next {
	local state=$1
	state=$(( (state * 1664525 + 1013904223) & 0xffffffff ))
	printf "%s" "$state"
}


function hash_bytes {
	local text=$1
	local hash=$FNV_OFFSET
	local i

	for ((i = 0; i < ${#text}; i++))
	do
		local char=${text:i:1}
		local byte
		printf -v byte '%d' "'$char"
		hash=$(( hash ^ byte ))
		hash=$(( hash * FNV_PRIME ))
	done

	printf "%s" "$hash"
}


function build_source_text {
	local state=0x12345678
	local length=0
	local word_count=0
	local text=

	while true
	do
		state=$(random_next "$state")
		local word=${words[state % WORD_COUNT]}

		if ((word_count > 0))
		then
			text+=" "
			((length += 1))
		fi

		text+="$word"
		((length += ${#word}))
		((word_count += 1))

		if ((length > TARGET_SIZE))
		then
			break
		fi
	done

	SOURCE_TEXT=$text
	SOURCE_HASH=$(hash_bytes "$text")
}


function wrap_words {
	local -a input_words=( "$@" )
	local text=
	local line_length=0
	local i

	for ((i = 0; i < ${#input_words[@]}; i++))
	do
		local word=${input_words[i]}
		local word_length=${#word}

		if ((i == 0))
		then
			text+="$word"
			line_length=$word_length
			continue
		fi

		if ((line_length + 1 + word_length >= LINE_LIMIT))
		then
			text+=$'\n'
			text+="$word"
			line_length=$word_length
		else
			text+=" "
			text+="$word"
			((line_length += 1 + word_length))
		fi
	done

	WRAPPED_TEXT=$text
}


function hash_wrapped_text {
	local text=$1
	local hash=$FNV_OFFSET
	local first=1

	while IFS= read -r line || [[ -n $line ]]
	do
		if ((first == 0))
		then
			hash=$(( hash ^ 32 ))
			hash=$(( hash * FNV_PRIME ))
		fi
		first=0

		local i
		for ((i = 0; i < ${#line}; i++))
		do
			local char=${line:i:1}
			local byte
			printf -v byte '%d' "'$char"
			hash=$(( hash ^ byte ))
			hash=$(( hash * FNV_PRIME ))
		done
	done <<< "$text"

	printf "%s" "$hash"
}


function format_hash {
	printf '0x%016x' "$1"
}


function run_benchmark {
	local source_text=$1
	local source_hash=$2
	local runs=$3
	local run

	for ((run = 0; run < runs; run++))
	do
		local -a split_words=()
		IFS=' ' read -r -a split_words <<< "$source_text"
		local wrapped_text
		local wrapped_hash

		wrap_words "${split_words[@]}"
		wrapped_text=$WRAPPED_TEXT
		wrapped_hash=$(hash_wrapped_text "$wrapped_text")

		if [[ $wrapped_hash != "$source_hash" ]]
		then
			printf \
				'Hash mismatch: %s != %s\n' \
				"$(format_hash "$wrapped_hash")" \
				"$(format_hash "$source_hash")" \
				>&2
			exit 1
		fi

		unset split_words
		unset wrapped_text
		unset wrapped_hash
	done
}


runs=1
if [[ -n ${1:-} ]]
then
	runs=$1
fi

build_source_text
if [[ $SOURCE_HASH != "$REFERENCE_HASH" ]]
then
	printf \
		'Source hash mismatch: %s != %s\n' \
		"$(format_hash "$SOURCE_HASH")" \
		"$(format_hash "$REFERENCE_HASH")" \
		>&2
	exit 1
fi

SECONDS=0
run_benchmark "$SOURCE_TEXT" "$SOURCE_HASH" "$runs"
printf 'Bash Elapsed %0.2f\n' "$SECONDS" >&2
