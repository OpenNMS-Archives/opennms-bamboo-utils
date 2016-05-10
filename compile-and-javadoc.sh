#!/bin/bash

WORKDIR="$1"; shift
MYDIR=$(dirname "$0")
MYDIR=$(cd "$MYDIR" || exit 1; pwd)

if [ -z "$WORKDIR" ] || [ ! -d "$WORKDIR" ]; then
	echo "usage: $0 <working-directory>" >&2
	echo "" >&2
	exit 1
fi

# shellcheck source=/dev/null
. "${MYDIR}/environment.sh"

# shellcheck source=/dev/null
. "${MYDIR}/lib.sh"

pushd "${WORKDIR}"

	"${WORKDIR}/clean.pl"
	"${WORKDIR}/bin/bamboo.pl" "${COMPILE_OPTIONS[@]}" "${SKIP_TESTS[@]}" -v install
	pushd opennms-full-assembly
		"${WORKDIR}/bin/bamboo.pl" "${COMPILE_OPTIONS[@]}" "${SKIP_TESTS[@]}" -v install
	popd
	"${WORKDIR}/bin/bamboo.pl" -Pbuild.bamboo -v javadoc:aggregate

	tar -cvzf javadocs.tar.gz -C "${WORKDIR}/target/site/apidocs" .
	"${MYDIR}"/generate-buildinfo.sh "$WORKDIR"

popd
