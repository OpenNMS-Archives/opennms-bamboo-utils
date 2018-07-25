#!/bin/bash

MYDIR=$(dirname "$0")
MYDIR=$(cd "$MYDIR" || exit 1; pwd)

# shellcheck source=lib.sh
. "${MYDIR}/lib.sh"

pushd "${WORKDIR}"

	"${MYDIR}/compile.sh" "${WORKDIR}"

	"${WORKDIR}/compile.pl" -Prun-expensive-tasks "${COMPILE_OPTIONS[@]}" "${SKIP_TESTS[@]}" -v javadoc:aggregate
	tar -cvzf javadocs.tar.gz -C "${WORKDIR}/target/site/apidocs" .

popd
