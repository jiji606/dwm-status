#!/usr/bin/env bash

trap cleanup TERM EXIT QUIT

declare -r STATUS_FIFO="/tmp/status-fifo"

declare -i CLOCK_PID
declare -i MPC_PID

function cleanup {
	if [[ -e $STATUS_FIFO ]] ; then
		rm -f $STATUS_FIFO
	fi
	kill "$CLOCK_PID"
	kill "$MPC_PID"
}

function check_dependency {
	for dep in "$@" ; do
		if ! which "$dep" &> /dev/null ; then
			echo "Missing $dep"
			exit 1
		fi
	done
}

function reset_fifo {
	if [[ -e $STATUS_FIFO ]] ; then
		rm -f $STATUS_FIFO
	fi
	mkfifo $STATUS_FIFO
}

reset_fifo

check_dependency clock date xsetroot mpc

clock -sf 'S%a %H:%M' > "$STATUS_FIFO" & CLOCK_PID=$!
mpc idleloop player   > "$STATUS_FIFO" & MPC_PID=$!

cat "$STATUS_FIFO" | while read -r line ; do
	echo "$line"
done
