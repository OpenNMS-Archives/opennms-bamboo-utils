#!/bin/sh

WORKDIR="$1"; shift

if [ -z "$WORKDIR" ] || [ ! -d "$WORKDIR" ]; then
	echo "usage: $0 <working-directory>" >&2
	echo "" >&2
	exit 1
fi

if [ -d "$HOME/.m2" ]; then
	rm -rf "$HOME"/.m2/repository*/org/opennms
fi

find "$WORKDIR" -type d -name target -print0 | xargs -0 rm -rf
