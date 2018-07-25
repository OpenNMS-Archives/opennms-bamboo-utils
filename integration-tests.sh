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

set +eo pipefail

JICMP_USE_SOCK_DGRAM=1
MAVEN_OPTS="-Xmx3g -XX:ReservedCodeCacheSize=512m -XX:PermSize=512m -XX:MaxPermSize=1g"
PATH="/opt/firefox:/usr/local/bin:$PATH"
SKIP_OPENJDK=1
SKIP_CLEAN=true

COMPILE_OPTIONS=("${COMPILE_OPTIONS[@]}" "-Dmaxmemory=3g")

if [ -x "${WORKDIR}/bin/javahome.pl" ]; then
	JAVA_HOME="$("${WORKDIR}"/bin/javahome.pl)"
fi

export COMPILE_OPTIONS JAVA_HOME JICMP_USE_SOCK_DGRAM MAVEN_OPTS MYDIR PATH SKIP_OPENJDK SKIP_CLEAN

set -eo pipefail

cd "${WORKDIR}" || exit 1
mkdir -p "${WORKDIR}/target"

# create a list of test classes
find ./* -name \*Test.java | \
	grep -v -E '^./smoke-test' | \
	xargs grep 'public class' | \
	cut -d: -f2 | \
	awk '{ print $3 }' | \
	grep -E 'Test$' | \
	sort -u > target/tests.txt

# create a list of integration test classes
find ./* -name \*IT.java | \
	grep -v -E '^./smoke-test' | \
	xargs grep 'public class' | \
	cut -d: -f2 | \
	awk '{ print $3 }' | \
	grep -E 'IT$' | \
	sort -u > target/its.txt

# split the list of tests into $NUM_JOBS pieces
TEST_COUNT="$(wc -l < target/tests.txt)"
if [ -z "${TEST_COUNT}" ]; then
	echo "Failed to figure out how many tests there are."
	exit 1
fi
split -l $(( TEST_COUNT / NUM_JOBS )) target/tests.txt target/tests.

# split the list of ITs into $NUM_JOBS pieces
IT_COUNT="$(wc -l < target/its.txt)"
if [ -z "${IT_COUNT}" ]; then
	echo "Failed to figure out how many ITs there are."
	exit 1
fi
split -l $(( IT_COUNT / NUM_JOBS )) target/its.txt target/its.

if [ ! -e target/"tests.${JOB_INDEX}" ] || [ ! -e target/"its.${JOB_INDEX}" ]; then
	echo "Job index ${JOB_INDEX} does not exist."
	ls -1 target/tests.*
	ls -1 target/its.*
	exit 1
fi

TESTS="$(paste -sd , - < target/"tests.${JOB_INDEX}")"
ITS="$(paste -sd , - < target/"its.${JOB_INDEX}")"

#find . -type d -name target -exec rm -rf {} \;

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
