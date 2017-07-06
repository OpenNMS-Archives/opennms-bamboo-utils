#!/bin/bash

MYDIR=$(dirname "$0")
MYDIR=$(cd "$MYDIR" || exit 1; pwd)

# shellcheck source=lib.sh
. "${MYDIR}/lib.sh"

pushd "${WORKDIR}"

	"${WORKDIR}/clean.pl"

	# first, make sure checkstyle is in the local ~/.m2/repository
	if [ -d "checkstyle" ]; then
		pushd checkstyle
			"${WORKDIR}/bin/bamboo.pl" "${COMPILE_OPTIONS[@]}" "${SKIP_TESTS[@]}" -v install
		popd
	fi

	# then, do the main build
	"${WORKDIR}/bin/bamboo.pl" -Prun-expensive-tasks "${COMPILE_OPTIONS[@]}" "${SKIP_TESTS[@]}" -v install

	# ...and then install these sub-POMs manually
	for DIR in opennms-tools opennms-assemblies; do
		pushd "$DIR"
			"${WORKDIR}/bin/bamboo.pl" -N "${COMPILE_OPTIONS[@]}" "${SKIP_TESTS[@]}" -v install
		popd
	done

	"${MYDIR}"/generate-buildinfo.sh "${WORKDIR}" "${BAMBOO_WORKING_DIRECTORY}"

popd
