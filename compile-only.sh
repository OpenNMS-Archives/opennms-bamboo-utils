#!/bin/bash

MYDIR=$(dirname "$0")
MYDIR=$(cd "$MYDIR" || exit 1; pwd)

# shellcheck source=lib.sh
. "${MYDIR}/lib.sh"

pushd "${WORKDIR}"

	"${WORKDIR}/clean.pl"
	"${WORKDIR}/bin/bamboo.pl" -Prun-expensive-tasks "${COMPILE_OPTIONS[@]}" "${SKIP_TESTS[@]}" -v install

	if [ -d "checkstyle" ]; then
		pushd checkstyle
			"${WORKDIR}/bin/bamboo.pl" "${COMPILE_OPTIONS[@]}" "${SKIP_TESTS[@]}" -v install
		popd
	fi

	for DIR in opennms-tools opennms-assembly opennms-full-assembly; do
		pushd "$DIR"
			"${WORKDIR}/bin/bamboo.pl" -N "${COMPILE_OPTIONS[@]}" "${SKIP_TESTS[@]}" -v install
		popd
	done

	"${MYDIR}"/generate-buildinfo.sh "${WORKDIR}" "${BAMBOO_WORKING_DIRECTORY}"

popd
