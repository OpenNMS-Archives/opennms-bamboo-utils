#!/bin/bash

shellcheck ./*.sh ./lib/*.sh

bamboo_buildKey=cli

MYDIR=$(dirname "$0")
MYDIR=$(cd "$MYDIR" || exit 1; pwd)

export bamboo_buildKey MYDIR

for file in t/*.sh; do
	$file "$(pwd)"
done
