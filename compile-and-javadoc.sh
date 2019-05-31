#!/bin/bash

MYDIR=$(dirname "$0")
MYDIR=$(cd "$MYDIR" || exit 1; pwd)

# shellcheck source=lib.sh disable=SC1091
. "${MYDIR}/lib.sh"

pushd "${WORKDIR}" || exit 1

	"${MYDIR}/compile.sh" "${WORKDIR}"
	# first bamboo.pl call will have already cleaned
	export SKIP_CLEAN=1
	"${MYDIR}/javadoc.sh" "${WORKDIR}"

popd || exit 1
