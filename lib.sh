#!/bin/bash

WORKDIR="$1"; shift

if [ -z "$WORKDIR" ] || [ ! -d "$WORKDIR" ]; then
	echo "usage: $0 <working-directory>" >&2
	echo "" >&2
	exit 1
fi

if [ -z "$MYDIR" ] || [ ! -d "$MYDIR" ]; then
	echo "\$MYDIR not initialized!" >&2
	echo "" >&2
	exit 1
fi

# shellcheck source=environment.sh disable=SC1091
. "${MYDIR}/environment.sh"

# shellcheck source=lib/util.sh disable=SC1091
. "${MYDIR}/lib/util.sh"

# shellcheck source=lib/git.sh disable=SC1091
. "${MYDIR}/lib/git.sh"

# shellcheck source=lib/bamboo.sh disable=SC1091
. "${MYDIR}/lib/bamboo.sh"

# shellcheck source=lib/maven.sh disable=SC1091
. "${MYDIR}/lib/maven.sh"

# shellcheck source=lib/nodejs.sh disable=SC1091
. "${MYDIR}/lib/nodejs.sh"

# shellcheck source=lib/docker.sh disable=SC1091
. "${MYDIR}/lib/docker.sh"

# shellcheck source=lib/postgresql.sh disable=SC1091
. "${MYDIR}/lib/postgresql.sh"

# shellcheck source=lib/opennms.sh disable=SC1091
. "${MYDIR}/lib/opennms.sh"

### EVERYTHING LEFT IN HERE IS DEPRECATED ###

assert_opennms_repo_version() {
	local repoversion

	repoversion=$(opennms-release.pl | sed -e 's,^v,,' | cut -d. -f1-2)

	if [[ $(echo "${repoversion} < 2.9" | bc) == 1 ]]; then
		echo 'Install OpenNMS::Release 2.9.0 or greater!'
		exit 1
	fi
}

get_repo_name() {
	local _workdir
	local _repo_name

	_workdir="$1"; shift

	set +u
	# shellcheck disable=SC2154
	if [ -z "${bamboo_OPENNMS_BUILD_REPO}" ]; then
		_repo_name=$(cat "${_workdir}/.nightly")
	else
		_repo_name="${bamboo_OPENNMS_BUILD_REPO}"
	fi
	set -u

	echo "${_repo_name}"
}

### Set up strict error handling for things that include lib.sh
# -e = exit immediately if a command returns non-zero
# -u = treat unset variables as an error
# -o pipefail = treat failures in any part of a piped command as a failure
set -euo pipefail