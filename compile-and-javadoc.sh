#!/bin/bash

MYDIR=$(dirname "$0")
MYDIR=$(cd "$MYDIR" || exit 1; pwd)

# shellcheck source=lib.sh
. "${MYDIR}/lib.sh"

"${MYDIR}"/compile.sh "${WORKDIR}"

pushd "${WORKDIR}"

	"${WORKDIR}/bin/bamboo.pl" -Prun-expensive-tasks -v javadoc:aggregate
	tar -cvzf javadocs.tar.gz -C "${WORKDIR}/target/site/apidocs" .

	"${MYDIR}"/generate-buildinfo.sh "${WORKDIR}" "${BAMBOO_WORKING_DIRECTORY}"

popd
