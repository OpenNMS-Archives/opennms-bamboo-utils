#!/bin/sh

WORKDIR="$1"; shift
MYDIR=`dirname $0`
MYDIR=`cd "$MYDIR"; pwd`

if [ -z "$WORKDIR" ] || [ ! -d "$WORKDIR" ]; then
	echo "usage: $0 <working-directory>" >&2
	echo "" >&2
	exit 1
fi

. "${MYDIR}/environment.sh"

#### BRANCH NAME ####
if [ -n "${bamboo_OPENNMS_BRANCH_NAME}" ]; then
	BRANCH_NAME="${bamboo_OPENNMS_BRANCH_NAME}"
else
	BRANCH_NAME="${bamboo_planRepository_branchName}"
fi
if [ `echo "$BRANCH_NAME" | grep -c '\$'` -gt 0 ]; then
	# branch did not get substituted, use git instead
	echo "WARNING: \$bamboo_OPENNMS_BRANCH_NAME and \$bamboo_planRepository_branchName are not set, attempting to determine branch with \`git symbolic-ref HEAD\`." >&2
	BRANCH_NAME=`(cd "$WORKDIR"; git symbolic-ref HEAD) | sed -e 's,^refs/heads/,,'`
fi
if [ -z "$BRANCH_NAME" ]; then
	echo "Unable to determine branch name. Bailing." >&2
	echo "" >&2
	exit 1
fi
echo "$BRANCH_NAME" >opennms-build-branch.txt
echo "Build Branch: $BRANCH_NAME"

#### DEPLOYMENT REPOSITORY ####
if [ -n "${bamboo_OPENNMS_BUILD_REPO}" ]; then
	BUILD_REPO="${bamboo_OPENNMS_BUILD_REPO}"
else
	BUILD_REPO=`cat "${WORKDIR}/.nightly"`
fi
echo $BUILD_REPO >opennms-build-repo.txt
echo "Build Repo: $BUILD_REPO"

#### GIT HASH ####
BUILD_HASH=`cd "$WORKDIR"; git rev-parse HEAD`
echo $BUILD_HASH >opennms-build-hash.txt
echo "Build Hash: $BUILD_HASH"

#### OPENNMS VERSION ####
OPENNMS_VERSION=`grep '<version>' "${WORKDIR}/pom.xml" | head -n 1 | sed -e 's,^.*<version>,,' -e 's,<.version>.*$,,'`
echo $OPENNMS_VERSION > opennms-build-version.txt
echo "OpenNMS Version: $OPENNMS_VERSION"
