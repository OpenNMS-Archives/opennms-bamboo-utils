#!/bin/bash

MYDIR="$(dirname "$0")"
MYDIR="$(cd "$MYDIR" || exit 1; pwd)"
TOPDIR="$(pwd)"

GITHUB_BUILD_CONTEXT="compile"

# shellcheck source=lib.sh disable=SC1091
. "${MYDIR}/lib.sh"

pushd "${WORKDIR}" || exit 1

	# update_github_status "${WORKDIR}" "pending" "$GITHUB_BUILD_CONTEXT" "cleaning working tree"
	clean_m2_repository "${WORKDIR}"            || update_github_status "${WORKDIR}" "failure" "$GITHUB_BUILD_CONTEXT" "clean failed"
	clean_maven_target_directories "${WORKDIR}" || update_github_status "${WORKDIR}" "failure" "$GITHUB_BUILD_CONTEXT" "clean failed"
	clean_node_directories "${WORKDIR}"         || update_github_status "${WORKDIR}" "failure" "$GITHUB_BUILD_CONTEXT" "clean failed"

	# "${WORKDIR}/clean.pl" || update_github_status "${WORKDIR}" "failure" "$GITHUB_BUILD_CONTEXT" "clean failed"

	update_github_status "${WORKDIR}" "pending" "$GITHUB_BUILD_CONTEXT" "compiling"

	# first, make sure checkstyle is in the local ~/.m2/repository
	if [ -d "checkstyle" ]; then
		pushd checkstyle || exit 1
			"${WORKDIR}/bin/bamboo.pl" "${COMPILE_OPTIONS[@]}" "${SKIP_TESTS[@]}" -v install || update_github_status "${WORKDIR}" "failure" "$GITHUB_BUILD_CONTEXT" "checkstyle compile failed"
		popd || exit 1
	fi

	# then, do the main build
	"${WORKDIR}/bin/compile.pl" -Prun-expensive-tasks "${COMPILE_OPTIONS[@]}" "${SKIP_TESTS[@]}" -v install || update_github_status "${WORKDIR}" "failure" "$GITHUB_BUILD_CONTEXT" "compile failed"

	# ...and then install these sub-POMs manually
	for DIR in opennms-tools opennms-assemblies; do
		pushd "$DIR" || exit 1
			"${WORKDIR}/bin/compile.pl" -N "${COMPILE_OPTIONS[@]}" "${SKIP_TESTS[@]}" -v install || update_github_status "${WORKDIR}" "failure" "$GITHUB_BUILD_CONTEXT" "tools and assemblies pom compile failed"
		popd || exit 1
	done

	"${MYDIR}"/generate-buildinfo.sh "${WORKDIR}" "${BAMBOO_WORKING_DIRECTORY}" || update_github_status "${WORKDIR}" "failure" "$GITHUB_BUILD_CONTEXT" "buildinfo generation failed"

popd || exit 1

update_github_status "${WORKDIR}" "success" "$GITHUB_BUILD_CONTEXT" "compile complete"
