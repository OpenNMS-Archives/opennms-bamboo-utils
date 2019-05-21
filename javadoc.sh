#!/bin/bash

MYDIR=$(dirname "$0")
MYDIR=$(cd "$MYDIR" || exit 1; pwd)

GITHUB_BUILD_CONTEXT="javadoc"

# shellcheck source=lib.sh disable=SC1091
. "${MYDIR}/lib.sh"

pushd "${WORKDIR}" || exit 1

	"${WORKDIR}/bin/bamboo.pl" -Prun-expensive-tasks "${COMPILE_OPTIONS[@]}" "${SKIP_TESTS[@]}" -v javadoc:aggregate || update_github_status "${WORKDIR}" "failure" "$GITHUB_BUILD_CONTEXT" "javadoc failed"
	tar -cvzf javadocs.tar.gz -C "${WORKDIR}/target/site/apidocs" . || update_github_status "${WORKDIR}" "failure" "$GITHUB_BUILD_CONTEXT" "tarball generation failed"

popd || exit 1

update_github_status "${WORKDIR}" "success" "$GITHUB_BUILD_CONTEXT" "javadoc complete"
