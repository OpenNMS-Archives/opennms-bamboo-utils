#!/bin/bash

MYDIR=$(dirname "$0")
MYDIR=$(cd "$MYDIR" || exit 1; pwd)

# shellcheck source=lib.sh disable=SC1091
. "${MYDIR}/lib.sh"

BACKUPDIR="$1"; shift
# shellcheck disable=SC2154
REPODIR="$HOME/.m2/repository-${bamboo_planKey}"

if [ -z "$BACKUPDIR" ]; then
	echo "usage: $0 <opennms-source-directory> <backup-file-directory>"
	echo ""
	exit 1
fi

TARGETFILES="$(find "$BACKUPDIR" -name 'target.tar.gz*')"
REPOFILES="$(find "$BACKUPDIR" -name 'repo.tar.gz*')"

if [ -z "$TARGETFILES" ] && [ -z "$REPOFILES" ]; then
	echo "ERROR: target.tar.gz* and repo.tar.gz* not found"
	echo ""
	exit 1
fi

if [ -n "$TARGETFILES" ]; then
	mkdir -p "$WORKDIR"
	pushd "$WORKDIR" || exit 1
		echo "* unpacking target.tar.gz* in $WORKDIR"
		# shellcheck disable=SC2002
		find "$BACKUPDIR" -type f -name 'target.tar.gz*' | sort | xargs cat | tar -xzf -
	popd || exit 1
else
	echo "WARNING: no target.tar.gz* file(s) in $BACKUPDIR"
fi

if [ -n "$REPOFILES" ]; then
	mkdir -p "$REPODIR"
	pushd "$REPODIR" || exit 1
		echo "* unpacking repo.tar.gz* in $BACKUPDIR"
		# shellcheck disable=SC2002
		find "$BACKUPDIR" -type f -name 'repo.tar.gz*' | sort | xargs cat | tar -xzf -
	popd || exit 1
else
	echo "WARNING: no repo.tar.gz* file(s) in $BACKUPDIR"
fi
