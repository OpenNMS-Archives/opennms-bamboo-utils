#!/bin/bash

MYDIR=$(dirname "$0")
MYDIR=$(cd "$MYDIR" || exit 1; pwd)

# shellcheck source=lib.sh disable=SC1091
. "${MYDIR}/lib.sh"

set +u
BUILD_STATE="$1"; shift || :
BUILD_CONTEXT="$1"; shift || :
BUILD_DESCRIPTION="$1"; shift || :

if [ -z "$GITHUB_AUTH_TOKEN" ]; then
	echo "\$GITHUB_AUTH_TOKEN is not set.  Failing."
	echo ""
	exit 1
fi

if [ -z "$BUILD_DESCRIPTION" ]; then
	echo "usage: $0 <workdir> <state> <context> <description>"
	echo ""
	exit 1
fi
set -u

update_github_status "$WORKDIR" "$BUILD_STATE" "$BUILD_CONTEXT" "$BUILD_DESCRIPTION"

exit $?
