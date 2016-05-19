#!/bin/bash

MYDIR=$(dirname "$0")
MYDIR=$(cd "$MYDIR" || exit 1; pwd)

# shellcheck source=lib.sh
. "${MYDIR}/lib.sh"

"${MYDIR}/fix-ownership.sh" "${WORKDIR}"
"${MYDIR}/stop-opennms.sh" "${WORKDIR}"
