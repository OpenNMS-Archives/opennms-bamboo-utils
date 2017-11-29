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

get_git_branch_name() {
	local _workdir
	local _branch_name

	_workdir="$1"; shift

	set +u
	_branch_name="$( (cd "${_workdir}" || exit 1; git symbolic-ref HEAD) | sed -e 's,^refs/heads/,,')"
	echo "${_branch_name}"
	set -u
}

set +euo pipefail
