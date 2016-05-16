#!/bin/bash

MYDIR=$(dirname "$0")
MYDIR=$(cd "$MYDIR" || exit 1; pwd)

# shellcheck source=lib.sh
. "${MYDIR}/lib.sh"

clean_m2_repository
clean_maven_target_directories "${WORKDIR}"
stop_opennms
