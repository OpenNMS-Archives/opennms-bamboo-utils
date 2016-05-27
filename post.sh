#!/bin/bash

MYDIR=$(dirname "$0")
MYDIR=$(cd "$MYDIR" || exit 1; pwd)

# shellcheck source=lib.sh
. "${MYDIR}/lib.sh"

stop_compiles
stop_opennms
stop_firefox
reset_postgresql
reset_docker
fix_ownership "${WORKDIR}"
