#!/bin/bash

MYDIR=$(dirname "$0")
MYDIR=$(cd "$MYDIR" || exit 1; pwd)

GITHUB_BUILD_CONTEXT="assembly"

# shellcheck source=lib.sh disable=SC1091
. "${MYDIR}/lib.sh"

pushd "${WORKDIR}" || exit 1

	"${MYDIR}/compile-only.sh" "${WORKDIR}"

	update_github_status "${WORKDIR}" "pending" "$GITHUB_BUILD_CONTEXT" "compiling assemblies"
	pushd opennms-full-assembly || exit 1
		"${WORKDIR}/bin/bamboo.pl" -Prun-expensive-tasks "${COMPILE_OPTIONS[@]}" "${SKIP_TESTS[@]}" -v install || update_github_status "${WORKDIR}" "failure" "$GITHUB_BUILD_CONTEXT" "assembly compile failed"
	popd || exit 1

popd || exit 1

update_github_status "${WORKDIR}" "success" "$GITHUB_BUILD_CONTEXT" "assembly complete"
