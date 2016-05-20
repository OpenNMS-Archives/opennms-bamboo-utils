#!/bin/bash

MYDIR=$(dirname "$0")
MYDIR=$(cd "$MYDIR" || exit 1; pwd)

# shellcheck source=lib.sh
. "${MYDIR}/lib.sh"

increase_limits
clean_m2_repository
clean_maven_target_directories "${WORKDIR}"
stop_compiles
stop_opennms
stop_firefox
reset_postgresql
fix_ownership "${WORKDIR}"
