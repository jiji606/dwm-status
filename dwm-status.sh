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
	kill "$MPC_PID"
	kill "$I3_PID"
	xsetroot -name " dwm "
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

function get_volume {
	local volume
	local is_muted

	is_muted="$(amixer get Master | grep -oP '\[(on|off)\]' | tr -d '[]')"
	if [[ $is_muted == on ]] ; then
		volume="$(amixer get Master | grep -oP '\[[0-9]+\%\]' | tr -d '[]%')%"
	elif [[ $is_muted == off ]] ; then
		volume="muted"
	fi
	echo $volume
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

mpc idleloop player > "$STATUS_FIFO" & MPC_PID=$! ; echo "mpc      $MPC_PID"
i3status            > "$STATUS_FIFO" & I3_PID=$!  ; echo "i3status $I3_PID"

while read -r line ; do
	case $line in
		player*)
			music_fmt=$(music_status)
			;;
		card*)
			volume_fmt=$(get_volume)
			;;
		b*)
			battery_fmt="${line#?}%"
			;;
		S*)
			clock_fmt="${line#?}"
			;;
		i3*)
			IFS='' read non vol load enp2s025 virbr0 wlp3s0 disk_root bat time <<< "$line"
			;;
	esac
	xsetroot -name "/ $enp2s025 / $wlp3s0 / $music_fmt / $vol / bat: $bat / $time "
done < "$STATUS_FIFO"
