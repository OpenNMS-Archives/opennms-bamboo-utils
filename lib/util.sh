#!/bin/bash

set -euo pipefail

retry_sudo() {
	set +e
	if echo "" | "$@" >/tmp/$$.output 2>&1; then
		cat /tmp/$$.output
		rm /tmp/$$.output
		return 0
	else
		rm /tmp/$$.output
		echo "" | sudo "$@"
	fi
	set -e
}

increase_limits() {
	local limit

	limit=$(ulimit -n)
	if [ "$limit" -lt 4096 ]; then
		ulimit -n 4096
	fi

	limit=$(cat /proc/sys/kernel/threads-max)
	if [ "$limit" -lt 200000 ]; then
		sudo bash -c 'echo 200000 > /proc/sys/kernel/threads-max'
	fi

	limit=$(cat /proc/sys/vm/max_map_count)
	if [ "$limit" -lt 100000 ]; then
		sudo bash -c 'echo 128000 > /proc/sys/vm/max_map_count'
	fi
}

stop_firefox() {
	retry_sudo killall firefox >/dev/null 2>&1 || :
}

stop_compiles() {
	set +eo pipefail
	KILLME=$(pgrep -f '(failsafe|surefire|git-upload-pack|bin/java .*install$)')
	if [ -n "$KILLME" ]; then
		# shellcheck disable=SC2086
		retry_sudo kill $KILLME || :
		sleep 5
		# shellcheck disable=SC2086
		retry_sudo kill -9 $KILLME || :
	fi
	set -eo pipefail
}

# usage: fix_ownership $WORKDIR [$file_to_match]
# If file_to_match is not passed, attempts to use the bamboo uid/gid.
# If bamboo uid/gid can't be determined, falls back to the 'opennms' user/group.
fix_ownership() {
	local _workdir
	local _chown_user
	local _chown_group

	_workdir="$1"; shift
	set +u
	if [ -n "$1" ]; then
		# shellcheck disable=SC2012
		_chown_user="$(ls -n "$1" | awk '{ print $3 }')"
		# shellcheck disable=SC2012
		_chown_group="$(ls -n "$1" | awk '{ print $4 }')"
	else
		_chown_user="$(id -u bamboo 2>/dev/null)"
		_chown_group="$(id -g bamboo 2>/dev/null)"
	fi
	set -u

	if [ -z "${_chown_user}" ] || [ "${_chown_user}" -eq 0 ]; then
		_chown_user="opennms"
	fi
	if [ -z "${_chown_group}" ] || [ "${_chown_group}" -eq 0 ]; then
		_chown_group="opennms"
	fi

	retry_sudo chown -R "${_chown_user}:${_chown_group}" "${_workdir}"
}

set +euo pipefail