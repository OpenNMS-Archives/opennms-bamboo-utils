#!/bin/bash

MYDIR=$(dirname "$0")
MYDIR=$(cd "$MYDIR" || exit 1; pwd)

# shellcheck source=lib.sh
. "${MYDIR}/lib.sh"

OUTPUTDIR="$1"; shift
if [ -z "$OUTPUTDIR" ] || [ ! -d "$OUTPUTDIR" ]; then
	OUTPUTDIR="$WORKDIR"
fi

#### BRANCH NAME ####
BRANCH_NAME="$(get_branch_name "${WORKDIR}")"
if [ -z "$BRANCH_NAME" ]; then
	echo "Unable to determine branch name. Bailing." >&2
	echo "" >&2
	exit 1
fi
echo "Build Branch: $BRANCH_NAME"
echo "$BRANCH_NAME" >"${OUTPUTDIR}/opennms-build-branch.txt"

#### DEPLOYMENT REPOSITORY ####
BUILD_REPO="$(get_repo_name "${WORKDIR}")"
echo "Build Repo: $BUILD_REPO"
echo "$BUILD_REPO" >"${OUTPUTDIR}/opennms-build-repo.txt"

#### GIT HASH ####
BUILD_HASH="$(get_git_hash "$WORKDIR")"
echo "Build Hash: $BUILD_HASH"
echo "$BUILD_HASH" >"${OUTPUTDIR}/opennms-build-hash.txt"

#### OPENNMS VERSION ####
OPENNMS_VERSION="$(get_opennms_version "${WORKDIR}")"
echo "OpenNMS Version: $OPENNMS_VERSION"
echo "$OPENNMS_VERSION" >"${OUTPUTDIR}/opennms-build-version.txt"

echo ""
