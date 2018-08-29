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

JAVA_HOME="$(opennms-source/bin/javahome.pl)"
PATH="/opt/firefox:/usr/local/bin:$PATH"
PHANTOMJS_CDNURL="https://mirror.internal.opennms.com/phantomjs/"

export JAVA_HOME PATH PHANTOMJS_CDNURL

CORE_RPM="$(find rpms -name opennms-core-\*.rpm -o -name meridian-core-\*.rpm)"
if [ "$(echo "$CORE_RPM" | wc -w)" -ne 1 ]; then
	echo "* ERROR: found more than one core RPM: $CORE_RPM"
	exit 1
fi

RPM_VERSION="$(rpm -q --queryformat='%{version}-%{release}\n' -p "${CORE_RPM}")"
echo "RPM Version: $RPM_VERSION"
ls -1 "${WORKDIR}"/rpms/*

set -eo pipefail

cd "${WORKDIR}" || exit 1
export SPLIT_TMPDIR="${WORKDIR}/tmp-split"
mkdir -p "${SPLIT_TMPDIR}"

TEST_FILE="$(get_classes "${WORKDIR}/opennms-source" "${SPLIT_TMPDIR}" "Test")"
split_file "${TEST_FILE}" "${NUM_JOBS}"

IT_FILE="$(get_classes "${WORKDIR}/opennms-source" "${SPLIT_TMPDIR}" "IT")"
split_file "${IT_FILE}" "${NUM_JOBS}"

if [ ! -e "${SPLIT_TMPDIR}/tests.${JOB_INDEX}" ] && [ ! -e "${SPLIT_TMPDIR}/its.${JOB_INDEX}" ]; then
	echo "Job index ${JOB_INDEX} does not exist."
	ls -1 "${SPLIT_TMPDIR}"/tests.* || :
	ls -1 "${SPLIT_TMPDIR}"/its.* || :
	exit 1
fi

TESTS="$(get_tests "${TEST_FILE}" "${JOB_INDEX}")"
ITS="$(get_tests "${IT_FILE}" "${JOB_INDEX}")"

echo "Running tests: ${TESTS}"
echo "Running ITs: ${ITS}"

if [ -n "${TESTS}" ]; then
	TESTS="-Dtest=${TESTS}"
fi

if [ -n "${ITS}" ]; then
	ITS="-Dit.test=${ITS}"
fi

SMOKE_TEST_API_VERSION="$(grep -C1 org.opennms.smoke.test-api "${WORKDIR}/opennms-source/smoke-test/pom.xml"  | grep '<version>' | sed -e 's,.*<version>,,' -e 's,</version>,,' -e 's,-SNAPSHOT$,,')"
case "$SMOKE_TEST_API_VERSION" in
	"2"|"3"|"4"|"5"|"6"|"7"|"8"|"9")
		DOCKERDIR="${WORKDIR}/opennms-system-test-api/docker"

		# this branch is using the new-style dockerized smoke tests
		# nothing special needed other than running the tests
		echo "* Found Dockerized smoke tests"

		case "$SMOKE_TEST_API_VERSION" in
			"4"|"5"|"6"|"7"|"8"|"9")
				echo "* Smoke Test API is >= 4, using newer Firefox if possible"
				export PATH="/usr/local/firefox:$PATH"
				;;
		esac

		mkdir -p "${DOCKERDIR}/opennms/rpms" "${DOCKERDIR}/minion/rpms" "${DOCKERDIR}/sentinel/rpms"
		rm -rf "${DOCKERDIR}"/opennms/rpms/*.rpm "${DOCKERDIR}"/minion/rpms/*.rpm "${DOCKERDIR}"/sentinel/rpms/*.rpm
		mv "${WORKDIR}"/rpms/*.rpm "${DOCKERDIR}/opennms/rpms/"
		mv "${DOCKERDIR}"/opennms/rpms/*-minion-* "${DOCKERDIR}"/minion/rpms/ || :
		mv "${DOCKERDIR}"/opennms/rpms/*-sentinel-* "${DOCKERDIR}"/sentinel/rpms/ || :

		cd "${DOCKERDIR}" || exit 1
			./build-docker-images.sh || exit 1
		cd "${WORKDIR}" || exit 1

		EXTRA_ARGS=""
		set +u
		# shellcheck disable=SC2154
		if [ -n "${bamboo_capability_host_address}" ]; then
			EXTRA_ARGS="-Dorg.opennms.advertised-host-address=${bamboo_capability_host_address}"
		fi
		set -u

		cd opennms-source || exit 1
			./compile.pl -Dmaven.test.skip.exec=true -Dsmoke=true --projects org.opennms:smoke-test --also-make install || exit 1
			cd smoke-test || exit 1
				# shellcheck disable=SC2086
				xvfb-run \
					--wait=20 \
					--server-args="-screen 0 1920x1080x24" \
					--server-num=80 \
					--auto-servernum \
					--listen-tcp \
					../compile.pl \
					-Dsurefire.rerunFailingTestsCount=2 \
					-Dfailsafe.rerunFailingTestsCount=2 \
					-Dorg.opennms.smoketest.logLevel=INFO \
					-Dtest.fork.count=2 \
					-Dorg.opennms.smoketest.docker=true \
					$EXTRA_ARGS \
					-Dsmoke=true \
					$TESTS \
					$ITS \
					-t install || exit 1
			cd ..
		cd ..
		;;
	*)
		cd smoke || exit 1
			# this branch has the old-style smoke tests
			echo "* Did NOT find Dockerized smoke tests"
			SHUNT_RPM="$(find debian-shunt -name debian-shunt-\*.noarch.rpm | sort -u | tail -n 1)"
			sudo rpm -Uvh "$SHUNT_RPM" || :

			sudo ./do-smoke-test.pl "${WORKDIR}"/opennms-source "${WORKDIR}"/rpms || exit 1
		cd ..
		;;
esac
