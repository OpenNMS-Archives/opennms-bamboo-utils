#!/bin/bash

MYDIR=$(dirname "$0")
MYDIR=$(cd "$MYDIR" || exit 1; pwd)

# shellcheck source=lib.sh
. "${MYDIR}/lib.sh"

pushd "${WORKDIR}"

	"${MYDIR}/compile.sh" "${WORKDIR}"
	"${MYDIR}/javadoc.sh" "${WORKDIR}"

popd
