#!/bin/bash

### DEPRECATED ###

MYDIR=$(dirname "$0")
MYDIR=$(cd "$MYDIR" || exit 1; pwd)

# shellcheck source=lib.sh
. "${MYDIR}/lib.sh"

fix_ownership "${WORKDIR}"
