#!/bin/bash

MYDIR="$(dirname "$0")"
MYDIR="$(cd "$MYDIR" || exit 1; pwd)"
TOPDIR="$(pwd)"

# shellcheck source=lib.sh disable=SC1091
. "${MYDIR}/lib.sh"

cd "${WORKDIR}" || exit 1

	clean_m2_repository "${WORKDIR}"
	clean_maven_target_directories "${WORKDIR}"
	clean_node_directories "${WORKDIR}"

	"${WORKDIR}/clean.pl"

	# first, make sure checkstyle is in the local ~/.m2/repository
	if [ -d "checkstyle" ]; then
		cd checkstyle || exit 1
			"${WORKDIR}/compile.pl" "${COMPILE_OPTIONS[@]}" "${SKIP_TESTS[@]}" -v install
		cd .. || exit 1
	fi

	# then, do the main build
	"${WORKDIR}/compile.pl" -Prun-expensive-tasks "${COMPILE_OPTIONS[@]}" "${SKIP_TESTS[@]}" -v install

	# ...and then install these sub-POMs manually
	for DIR in opennms-tools opennms-assemblies; do
		cd "$DIR" || exit 1
			"${WORKDIR}/compile.pl" -N "${COMPILE_OPTIONS[@]}" "${SKIP_TESTS[@]}" -v install
		cd .. || exit 1
	done

	"${MYDIR}"/generate-buildinfo.sh "${WORKDIR}" "${BAMBOO_WORKING_DIRECTORY}"

cd "${TOPDIR}" || exit 1
