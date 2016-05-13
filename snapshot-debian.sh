#!/bin/bash

MYDIR=$(dirname "$0")
MYDIR=$(cd "$MYDIR" || exit 1; pwd)

# shellcheck source=lib.sh
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
