#!/bin/bash

MYDIR=$(dirname "$0")
MYDIR=$(cd "$MYDIR" || exit 1; pwd)

# shellcheck source=lib.sh disable=SC1091
. "${MYDIR}/lib.sh"

BACKUPDIR="$1"; shift
# shellcheck disable=SC2154
REPODIR="$HOME/.m2/repository-${bamboo_buildKey}"

if [ -z "$BACKUPDIR" ]; then
	echo "usage: $0 <opennms-source-directory> <backup-file-directory>"
	echo ""
	exit 1
fi

if [ ! -e "$BACKUPDIR/target.tar.gz" ]; then
	echo "ERROR: no target.tar.gz file in $BACKUPDIR"
	echo ""
	exit 1
fi

mkdir -p "$WORKDIR"
pushd "$WORKDIR" || exit 1
	echo "* unpacking target.tar.gz in $WORKDIR"
	tar -xvzf "$BACKUPDIR/target.tar.gz"
popd || exit 1

if [ -e "$BACKUPDIR/repo.tar.gz" ]; then
	mkdir -p "$REPODIR"
	pushd "$REPODIR" || exit 1
		echo "* unpacking repo.tar.gz in $BACKUPDIR"
		tar -xvzf "$BACKUPDIR/repo.tar.gz"
	popd || exit 1
else
	echo "WARNING: no repo.tar.gz file in $BACKUPDIR"
fi
