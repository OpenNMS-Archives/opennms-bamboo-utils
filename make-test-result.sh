#!/bin/bash

MYDIR=$(dirname "$0")
MYDIR=$(cd "$MYDIR" || exit 1; pwd)

# shellcheck source=lib.sh
. "${MYDIR}/lib.sh"

mkdir -p "${WORKDIR}/target/failsafe-reports"

cat <<END >"${WORKDIR}/target/failsafe-reports/failsafe-summary.xml"
<?xml version="1.0" encoding="UTF-8"?>
<failsafe-summary timeout="false">
  <completed>0</completed>
  <errors>0</errors>
  <failures>0</failures>
  <skipped>420</skipped>
  <failureMessage/>
</failsafe-summary>
END
