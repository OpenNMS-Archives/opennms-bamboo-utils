#!/bin/bash

MYDIR=$(dirname "$0")
MYDIR=$(cd "$MYDIR" || exit 1; pwd)

# shellcheck source=lib.sh
. "${MYDIR}/lib.sh"

increase_limits
stop_compiles
stop_firefox
stop_opennms
clean_m2_repository
clean_maven_target_directories "${WORKDIR}"
clean_node_directories "${WORKDIR}"
clean_opennms
reset_postgresql
reset_docker
fix_ownership "${WORKDIR}"
