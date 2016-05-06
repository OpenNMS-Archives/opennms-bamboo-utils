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

#### BRANCH NAME ####
# shellcheck disable=SC2154
if [ -z "${bamboo_OPENNMS_BRANCH_NAME}" ]; then
	BRANCH_NAME="${bamboo_planRepository_branchName}"
else
	BRANCH_NAME="${bamboo_OPENNMS_BRANCH_NAME}"
fi
if [ -z "$BRANCH_NAME" ] || [ "$(echo "$BRANCH_NAME" | grep -c '\$')" -gt 0 ]; then
	# branch did not get substituted, use git instead
	echo "WARNING: \$bamboo_OPENNMS_BRANCH_NAME and \$bamboo_planRepository_branchName are not set, attempting to determine branch with \`git symbolic-ref HEAD\`." >&2
	BRANCH_NAME="$( (cd "$WORKDIR" || exit 1; git symbolic-ref HEAD) | sed -e 's,^refs/heads/,,')"
fi
if [ -z "$BRANCH_NAME" ]; then
	echo "Unable to determine branch name. Bailing." >&2
	echo "" >&2
	exit 1
fi
echo "$BRANCH_NAME" >opennms-build-branch.txt
echo "Build Branch: $BRANCH_NAME"

#### DEPLOYMENT REPOSITORY ####
# shellcheck disable=SC2154
if [ -z "${bamboo_OPENNMS_BUILD_REPO}" ]; then
	BUILD_REPO=$(cat "${WORKDIR}/.nightly")
else
	BUILD_REPO="${bamboo_OPENNMS_BUILD_REPO}"
fi
echo "$BUILD_REPO" >opennms-build-repo.txt
echo "Build Repo: $BUILD_REPO"

#### GIT HASH ####
BUILD_HASH=$(cd "$WORKDIR" || exit 1; git rev-parse HEAD)
echo "$BUILD_HASH" >opennms-build-hash.txt
echo "Build Hash: $BUILD_HASH"

#### OPENNMS VERSION ####
OPENNMS_VERSION=$(grep '<version>' "${WORKDIR}/pom.xml" | head -n 1 | sed -e 's,^.*<version>,,' -e 's,<.version>.*$,,')
echo "$OPENNMS_VERSION" > opennms-build-version.txt
echo "OpenNMS Version: $OPENNMS_VERSION"
