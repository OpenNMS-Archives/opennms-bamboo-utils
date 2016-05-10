#!/bin/bash

WORKDIR="$1"; shift
MYDIR=$(dirname "$0")
MYDIR=$(cd "$MYDIR" || exit 1; pwd)

if [ -z "$WORKDIR" ] || [ ! -d "$WORKDIR" ]; then
	echo "usage: $0 <working-directory>" >&2
	echo "" >&2
	exit 1
fi

# shellcheck source=/dev/null
. "${MYDIR}/environment.sh"

# shellcheck source=/dev/null
. "${MYDIR}/lib.sh"

assert_opennms_repo_version

BRANCH_NAME="$(get_branch_name "${WORKDIR}")"
if [ -z "$BRANCH_NAME" ]; then
	echo "Unable to determine branch name. Bailing." >&2
	echo "" >&2
	exit 1
fi

pushd "${WORKDIR}"
	nightly.pl -t debian -b "${BRANCH_NAME}"
popd
