#!/bin/bash -x

MYDIR=$(dirname "$0")
MYDIR=$(cd "$MYDIR" || exit 1; pwd)

GITHUB_BUILD_CONTEXT="smoke"

# shellcheck source=lib.sh disable=SC1091
. "${MYDIR}/lib.sh"

set +eo pipefail

FLAPPING=false

while getopts f OPT; do
	case $OPT in
		f) FLAPPING=true
			;;
		*)
			;;
	esac
done

if [ "$FLAPPING" = "true" ]; then
	FLAPPING_TESTS="$(git grep runFlappers | grep -c IfProfileValue)"

	if [ "$FLAPPING_TESTS" -gt 0 ]; then
		echo "This branch does not support separating out flapping tests.  Skipping."
		exit 0
	fi
	echo "* Running flapping tests."
else
	echo "* Skipping flapping tests."
fi

export PATH="/opt/firefox:/usr/local/bin:$PATH"
export PHANTOMJS_CDNURL="https://mirror.internal.opennms.com/phantomjs/"
export OPENNMS_SOURCEDIR="${WORKDIR}/opennms-source"

if [ -x "${WORKDIR}/opennms-source/bin/javahome.pl" ]; then
	JAVA_HOME="$("${OPENNMS_SOURCEDIR}/bin/javahome.pl")"
fi
export JAVA_HOME

CORE_RPM="$(find "${WORKDIR}/rpms" -name opennms-core-\*.rpm -o -name meridian-core-\*.rpm)"
if [ "$(echo "$CORE_RPM" | wc -w)" -ne 1 ]; then
	echo "* ERROR: found more than one core RPM: $CORE_RPM"
	exit 1
fi

RPM_VERSION="$(rpm -q --queryformat='%{version}-%{release}\n' -p "${CORE_RPM}")"
echo "RPM Version: $RPM_VERSION"
ls -1 "${WORKDIR}"/rpms/*

SMOKE_TEST_API_VERSION="$(grep -C1 org.opennms.smoke.test-api "${OPENNMS_SOURCEDIR}/smoke-test/pom.xml"  | grep '<version>' | sed -e 's,.*<version>,,' -e 's,</version>,,' -e 's,-SNAPSHOT$,,')"

TEST_CONTAINERS="$(grep -c org.testcontainers "${OPENNMS_SOURCEDIR}/smoke-test/pom.xml")"

if [ "$TEST_CONTAINERS" -gt 0 ]; then
	SMOKE_TEST_API_VERSION=9999
fi


set -e

declare -a DO_COMPILE=("${OPENNMS_SOURCEDIR}/compile.pl" "-DskipTests=true" "-DskipITs=true" "-Dmaven.test.skip.exec=true" "-Dsmoke=true" --projects org.opennms:smoke-test --also-make install)
declare -a DO_SMOKE=("${OPENNMS_SOURCEDIR}/compile.pl" -t -Pbamboo "-Dsmoke=true" "-Dorg.opennms.smoketest.logLevel=INFO" "-Dorg.opennms.smoketest.docker=true")


set +u
# shellcheck disable=SC2154
if [ -n "${bamboo_capability_host_address}" ]; then
	DO_SMOKE+=("-Dorg.opennms.advertised-host-address=${bamboo_capability_host_address}")
fi
set -u

RERUNS=2
if [ "$FLAPPING" = "true" ]; then
	RERUNS=0
	DO_SMOKE+=('-DrunFlappers=true')
fi

if [ "$SMOKE_TEST_API_VERSION" = "9999" ]; then
	RERUNS=0
fi

DO_SMOKE+=("-Dsurefire.rerunFailingTestsCount=${RERUNS}" "-Dfailsafe.rerunFailingTestsCount=${RERUNS}")

pushd "${OPENNMS_SOURCEDIR}"

case "$SMOKE_TEST_API_VERSION" in
	9999)
		mkdir -p "${OPENNMS_SOURCEDIR}/target/rpm/RPMS/noarch"
		mv "${WORKDIR}"/rpms/*.rpm "${OPENNMS_SOURCEDIR}/target/rpm/RPMS/noarch/"
		for FILE in "${OPENNMS_SOURCEDIR}/opennms-container"/*/build_container_image.sh; do
			DIR="$(dirname "$FILE")"
			pushd "$DIR" || exit 1
				CONTAINER="$(basename "$DIR")"
				update_github_status "${OPENNMS_SOURCEDIR}" "pending" "$GITHUB_BUILD_CONTEXT" "building docker image: ${CONTAINER}"
				./build_container_image.sh || update_github_status "${OPENNMS_SOURCEDIR}" "failure" "$GITHUB_BUILD_CONTEXT" "failed to build docker image ($CONTAINER)"
			popd || exit 1
		done
		update_github_status "${OPENNMS_SOURCEDIR}" "pending" "$GITHUB_BUILD_CONTEXT" "compiling v2 smoke tests"
		"${DO_COMPILE[@]}" || update_github_status "${OPENNMS_SOURCEDIR}" "failure" "$GITHUB_BUILD_CONTEXT" "failed to compile v2 smoke tests"
		pushd smoke-test || exit 1
			"${DO_SMOKE[@]}" \
				"-Dtest.fork.count=2" \
				"-Duser.timezone=UTC" \
				install \
				verify || update_github_status "${OPENNMS_SOURCEDIR}" "failure" "$GITHUB_BUILD_CONTEXT" "v2 smoke tests failed"
		popd || exit 1
		;;
	"2"|"3"|"4"|"5"|"6"|"7")
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

		update_github_status "${OPENNMS_SOURCEDIR}" "pending" "$GITHUB_BUILD_CONTEXT" "building docker images"
		cd "${DOCKERDIR}" || exit 1
			./build-docker-images.sh || update_github_status "${OPENNMS_SOURCEDIR}" "failure" "$GITHUB_BUILD_CONTEXT" "failed to build docker images"
		cd "${WORKDIR}" || exit 1

		cd "${OPENNMS_SOURCEDIR}" || exit 1
			update_github_status "${OPENNMS_SOURCEDIR}" "pending" "$GITHUB_BUILD_CONTEXT" "compiling v2 smoke tests"
			"${DO_COMPILE[@]}" || update_github_status "${OPENNMS_SOURCEDIR}" "failure" "$GITHUB_BUILD_CONTEXT" "failed to compile v2 smoke tests"
			cd smoke-test || exit 1
				# shellcheck disable=SC2086
				xvfb-run \
					--wait=20 \
					--server-args="-screen 0 1920x1080x24" \
					--server-num=80 \
					--auto-servernum \
					--listen-tcp \
					"${DO_SMOKE[@]}" \
					-Dtest.fork.count=1 \
					install \
					verify || update_github_status "${OPENNMS_SOURCEDIR}" "failure" "$GITHUB_BUILD_CONTEXT" "v2 smoke tests failed"
			cd ..
		cd ..
		;;
	*)
		cd smoke || exit 1
			# this branch has the old-style smoke tests
			echo "* Did NOT find Dockerized smoke tests"
			SHUNT_RPM="$(find debian-shunt -name debian-shunt-\*.noarch.rpm | sort -u | tail -n 1)"
			sudo rpm -Uvh "$SHUNT_RPM" || :

			update_github_status "${OPENNMS_SOURCEDIR}" "pending" "$GITHUB_BUILD_CONTEXT" "running v1 smoke tests"
			sudo ./do-smoke-test.pl "${OPENNMS_SOURCEDIR}" "${WORKDIR}/rpms" || update_github_status "${OPENNMS_SOURCEDIR}" "failure" "$GITHUB_BUILD_CONTEXT" "v1 smoke tests failed"
		cd ..
		;;
esac

update_github_status "${OPENNMS_SOURCEDIR}" "success" "$GITHUB_BUILD_CONTEXT" "smoke tests complete"
