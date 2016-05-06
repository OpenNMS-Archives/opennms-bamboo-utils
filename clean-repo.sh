#!/bin/sh

REPODIR="$1"; shift

if [ -z "$REPODIR" ] || [ ! -d "$REPODIR" ]; then
	echo "usage: $0 <repodir>" >&2
	echo "" >&2
	exit 1
fi

if [ -d "$HOME/.m2" ]; then
	rm -rf "$HOME"/.m2/repository*/org/opennms
fi

find "$REPODIR" -type d -name target -print0 | xargs -0 rm -rf
