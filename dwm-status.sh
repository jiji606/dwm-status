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

clock -sf 'S%a %H:%M'      > "$STATUS_FIFO" & CLOCK_PID=$!   ; echo "clock   $CLOCK_PID"
mpc idleloop player        > "$STATUS_FIFO" & MPC_PID=$!     ; echo "mpc     $MPC_PID"

while read -r line ; do
	case $line in
		player*)
			now_playing=$(music_status)
			;;
		card*)
			volume="$(amixer get Master | grep -oP '\[[0-9]+\%\]' | tr -d '[]%')"
			volume_fmt="${volume}%"
			;;
		b*)
			battery_fmt="${line#?}%"
			;;
		S*)
			clock_fmt="${line#?}"
			;;
	esac
	xsetroot -name " / $now_playing / vol:$volume_fmt / bat:$battery_fmt / $clock_fmt "
done < "$STATUS_FIFO"
