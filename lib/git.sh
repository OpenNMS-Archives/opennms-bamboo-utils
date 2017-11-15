#!/bin/bash

set -euo pipefail

get_git_hash() {
	local _workdir

	_workdir="$1"; shift

	cd "${_workdir}" || exit 1
	git rev-parse HEAD
}

get_git_date() {
	local _workdir

	_workdir="$1"; shift

	cd "${_workdir}" || exit 1
	git log --pretty='format:%cd' --date='short' -1 | sed -e 's,-,,g'
}

set +euo pipefail