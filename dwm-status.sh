#!/usr/bin/env bash

trap cleanup TERM EXIT QUIT

declare -r BATTERY_PATH="/sys/class/power_supply/BAT0/capacity"
declare -r STATUS_FIFO="/tmp/status-fifo"

declare -i BATTERY_CHECK_INT=5
declare -i BATTERY_PID
declare -i CLOCK_PID
declare -i MPC_PID
declare -i VOL_PID
declare -i VOLUME_CHECK_INT=5

function cleanup {
	if [[ -e $STATUS_FIFO ]] ; then
		rm -f $STATUS_FIFO
	fi
	kill "$CLOCK_PID"
	kill "$MPC_PID"
	kill "$BATTERY_PID"
	kill "$VOL_PID"
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

function battery_check {
	while true ; do
		battery_status="b$(cat $BATTERY_PATH)"
		echo "$battery_status"
		sleep "$BATTERY_CHECK_INT"
	done
}

function music_status {
	if (( $(mpc | wc -l) > 1 )) ; then
		mpc_current="$(mpc current)"
		mpc_status="$(mpc | grep -oP "(?<=\[)(\w+)" ) - ${mpc_current}"
		mpc_position="$(mpc -f %position% | head -n 1)"
		mpc_playlist="$(mpc playlist | wc -l)"
	elif (( $(mpc | wc -l) == 1 )) ; then
		if (( $(mpc playlist | wc -l) == 0 )) ; then
			mpc_status="playlist empty"
		elif (( $(mpc playlist | wc -l) > 0 )) ; then
			if [[ "$mpc_position" == "$mpc_playlist" ]] ; then
				mpc_status="playlist end"
			else
				mpc_status="stopped"
			fi
		fi
	fi
	echo "$mpc_status"
}

reset_fifo

check_dependency clock date xsetroot mpc

clock -sf 'S%a %H:%M'      > "$STATUS_FIFO" & CLOCK_PID=$!   ; echo "clock   $CLOCK_PID"
mpc idleloop player        > "$STATUS_FIFO" & MPC_PID=$!     ; echo "mpc     $MPC_PID"
stdbuf -oL alsactl monitor > "$STATUS_FIFO" & VOL_PID=$!     ; echo "volume  $VOL_PID"
battery_check              > "$STATUS_FIFO" & BATTERY_PID=$! ; echo "battery $BATTERY_PID"

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
