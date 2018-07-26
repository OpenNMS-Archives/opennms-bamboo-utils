#!/bin/bash -x

MYDIR=$(dirname "$0")
MYDIR=$(cd "$MYDIR" || exit 1; pwd)

# shellcheck source=lib.sh disable=SC1091
. "${MYDIR}/lib.sh"

NUM_JOBS="$1"; shift
JOB_INDEX="$1"; shift

if [ -z "$JOB_INDEX" ]; then
	echo "usage: $0 <workdir> <num-jobs> <job-index>"
	echo ""
	echo "WARNING: num-jobs or job-index not specified.  Building everything."
	echo ""
	NUM_JOBS=1
	JOB_INDEX=aa
fi

if [ ! -x "${WORKDIR}/opennms-source/compile.pl" ]; then
	echo "\$WORKDIR should be set to the bamboo root. It is expected this directory contains rpms and opennms-source."
	exit 1
fi


set +eo pipefail

COMPILE_OPTIONS=("${COMPILE_OPTIONS[@]}" "-Dmaxmemory=3g")
JAVA_HOME="$("${WORKDIR}"/opennms-source/bin/javahome.pl)"
JICMP_USE_SOCK_DGRAM=1
MAVEN_OPTS="-Xmx3g -XX:ReservedCodeCacheSize=512m -XX:PermSize=512m -XX:MaxPermSize=1g"
PATH="/opt/firefox:/usr/local/bin:$PATH"
SKIP_OPENJDK=1
SKIP_CLEAN=true

export COMPILE_OPTIONS JAVA_HOME JICMP_USE_SOCK_DGRAM MAVEN_OPTS MYDIR PATH SKIP_OPENJDK SKIP_CLEAN

set -eo pipefail

cd "${WORKDIR}" || exit 1
export SPLIT_TMPDIR="${WORKDIR}/tmp-split"
mkdir -p "${SPLIT_TMPDIR}"

# create a list of test classes
find opennms-source/* -name \*Test.java -print0 | \
	xargs -0 grep 'public class' | \
	grep -v '/smoke-test/' | \
	cut -d: -f2 | \
	awk '{ print $3 }' | \
	grep -E 'Test$' | \
	sort -u > "${SPLIT_TMPDIR}/tests.txt"

# create a list of integration test classes
find opennms-source/* -name \*IT.java -print0 | \
	xargs -0 grep 'public class' | \
	grep -v '/smoke-test/' | \
	cut -d: -f2 | \
	awk '{ print $3 }' | \
	grep -E 'IT$' | \
	sort -u > "${SPLIT_TMPDIR}/its.txt"

# split the list of tests into $NUM_JOBS pieces
TEST_COUNT="$(wc -l < "${SPLIT_TMPDIR}/tests.txt")"
if [ -z "${TEST_COUNT}" ]; then
	echo "Failed to figure out how many tests there are."
	exit 1
fi
if [ "$TEST_COUNT" -gt 0 ]; then
	split -l $(( TEST_COUNT / NUM_JOBS )) "${SPLIT_TMPDIR}/tests.txt" "${SPLIT_TMPDIR}/tests."
fi

# split the list of ITs into $NUM_JOBS pieces
IT_COUNT="$(wc -l < "${SPLIT_TMPDIR}/its.txt")"
if [ -z "${IT_COUNT}" ]; then
	echo "Failed to figure out how many ITs there are."
	exit 1
fi
if [ "$IT_COUNT" -gt 0 ]; then
	split -l $(( IT_COUNT / NUM_JOBS )) "${SPLIT_TMPDIR}/its.txt" "${SPLIT_TMPDIR}/its."
fi

if [ ! -e "${SPLIT_TMPDIR}/tests.${JOB_INDEX}" ] || [ ! -e "${SPLIT_TMPDIR}/its.${JOB_INDEX}" ]; then
	echo "Job index ${JOB_INDEX} does not exist."
	ls -1 "${SPLIT_TMPDIR}"/tests.* || :
	ls -1 "${SPLIT_TMPDIR}"/its.* || :
	exit 1
fi

TESTS="$(paste -sd , - < "${SPLIT_TMPDIR}/tests.${JOB_INDEX}")"
ITS="$(paste -sd , - < "${SPLIT_TMPDIR}/its.${JOB_INDEX}")"

echo "Running tests: ${TESTS}"
echo "Running ITs: ${ITS}"
./compile.pl "${COMPILE_OPTIONS[@]}" "${ENABLE_TESTS[@]}" \
	-Dorg.opennms.core.test-api.dbCreateThreads=1 \
	-Dorg.opennms.core.test-api.snmp.useMockSnmpStrategy=false \
	-Djava.security.egd=file:/dev/./urandom \
	-t \
	-v \
	-Pbuild-bamboo \
	-DfailIfNoTests=false \
	-Dtest="${TESTS}" \
	-Dit.test="${ITS}" \
	install
