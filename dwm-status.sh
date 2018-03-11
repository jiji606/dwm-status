#!/usr/bin/env bash

trap cleanup TERM EXIT QUIT

declare -r STATUS_FIFO="/tmp/status-fifo"

function cleanup {
	if [[ -e $STATUS_FIFO ]] ; then
		rm -f $STATUS_FIFO
	fi
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
