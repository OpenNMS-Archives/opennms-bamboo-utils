#!/bin/bash

MYDIR=$(dirname "$0")
MYDIR=$(cd "$MYDIR" || exit 1; pwd)

# shellcheck source=lib.sh
. "${MYDIR}/lib.sh"

pushd "${WORKDIR}"

	"${WORKDIR}/clean.pl"
	"${WORKDIR}/bin/bamboo.pl" -Prun-expensive-tasks "${COMPILE_OPTIONS[@]}" "${SKIP_TESTS[@]}" -v install
	pushd opennms-full-assembly
		"${WORKDIR}/bin/bamboo.pl" -Prun-expensive-tasks "${COMPILE_OPTIONS[@]}" "${SKIP_TESTS[@]}" -v install
	popd

	"${MYDIR}"/generate-buildinfo.sh "${WORKDIR}" "${BAMBOO_WORKING_DIRECTORY}"

popd
