#!/bin/bash

set -euo pipefail

get_branch_name() {
	local _workdir
	local _branch_name

	_workdir="$1"; shift

	set +u
	# shellcheck disable=SC2154
	if [ -z "${bamboo_OPENNMS_BRANCH_NAME}" ]; then
		_branch_name="${bamboo_planRepository_branchName}"
	else
		_branch_name="${bamboo_OPENNMS_BRANCH_NAME}"
	fi
	set -u

	if [ -z "$_branch_name" ] || [ "$(echo "$_branch_name" | grep -c '\$')" -gt 0 ]; then
		# branch did not get substituted, use git instead
		echo "WARNING: \$bamboo_OPENNMS_BRANCH_NAME and \$bamboo_planRepository_branchName are not set, attempting to determine branch with \`git symbolic-ref HEAD\`." >&2
		_branch_name="$(get_git_branch_name "${_workdir}")"
	fi

	echo "${_branch_name}"
}

generate_revision() {
	local _workdir
	_workdir="$1"; shift
	_point=1

	if [ "$#" -gt 0 ]; then
		_point="$1"; shift
	fi
	DATESTAMP="$(get_git_date "${_workdir}")"
	echo "0.${DATESTAMP}.${_point}";
}

set +euo pipefail
