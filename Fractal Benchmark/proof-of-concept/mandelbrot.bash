#!/bin/bash

BAILOUT=16
MAX_ITERATIONS=1000


bcPid=
bcDir=


function start_bc {
	bcDir=$(mktemp -d)
	mkfifo "$bcDir/in" "$bcDir/out"
	bc <"$bcDir/in" >"$bcDir/out" &
	bcPid=$!
	exec 3>"$bcDir/in"
	exec 4<"$bcDir/out"
}


function stop_bc {
	exec 3>&-
	exec 4<&-
	if [[ -n ${bcPid:-} ]]
	then
		wait "$bcPid" 2>/dev/null || true
		bcPid=
	fi
	if [[ -n ${bcDir:-} ]]
	then
		rm -rf "$bcDir"
		bcDir=
	fi
}


function bc_eval {
	printf "scale=16; %s\n" "$1" >&3
	local result
	read -r result <&4
	printf "%s" "$result"
}


function iterate {
	# $1 is x
	# $2 is y
	local zi=0
	local zr=0
	local i=0

	local cr
	cr=$(bc_eval "$2 - 0.5")

	while true
	do
		local temp
		local zr2
		local zi2
		i=$((i + 1))
		zr2=$(bc_eval "($zr * $zr) - ($zi * $zi) + $cr")
		zi2=$(bc_eval "(($zr * $zi) * 2) + $1")
		temp=$(bc_eval "($zi * $zi) + ($zr * $zr) > $BAILOUT")

		if ((temp == 1))
		then
			return "$i"
		fi

		if ((i > MAX_ITERATIONS))
		then
			return 0
		fi

		zr="$zr2"
		zi="$zi2"
	done
}


function mandelbrot {
	local runs=1
	if [[ -n ${1:-} ]]
	then
		runs=$1
	fi

	local run
	for ((run = 0; run < runs; run++))
	do
		local y
		for ((y = -39; y < 39; y++))
		do
			printf "\n"
			local x
			for ((x = -39; x < 39; x++))
			do
				local xi
				local yi
				local ires
				xi=$(bc_eval "$x / 40.0")
				yi=$(bc_eval "$y / 40.0")
				iterate "$xi" "$yi"
				ires=$?

				if ((ires == 0))
				then
					printf "*"
				else
					printf " "
				fi
			done
		done
		printf "\n"
	done
}

start_bc
trap stop_bc EXIT
mandelbrot "$1"
stop_bc
trap - EXIT
