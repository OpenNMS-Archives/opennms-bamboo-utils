#!/bin/bash -x

MYDIR=$(dirname "$0")
MYDIR=$(cd "$MYDIR" || exit 1; pwd)

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
	"${MYDIR}/make-test-result.sh" "${WORKDIR}/opennms-source"

	SUPPORTS_FLAPPING="$(grep -c opennms.test.excludedGroups "${WORKDIR}/pom.xml")"

	if [ "$SUPPORTS_FLAPPING" -eq 0 ]; then
		echo "This branch does not support separating out flapping tests.  Skipping."
		exit 0
	fi
fi

export PATH="/opt/firefox:/usr/local/bin:$PATH"
export PHANTOMJS_CDNURL="https://mirror.internal.opennms.com/phantomjs/"

if [ -x "${WORKDIR}/opennms-source/bin/javahome.pl" ]; then
	JAVA_HOME="$("${WORKDIR}/opennms-source/bin/javahome.pl")"
fi
export JAVA_HOME

CORE_RPM="$(find rpms -name opennms-core-\*.rpm -o -name meridian-core-\*.rpm)"
if [ "$(echo "$CORE_RPM" | wc -w)" -ne 1 ]; then
	echo "* ERROR: found more than one core RPM: $CORE_RPM"
	exit 1
fi

RPM_VERSION="$(rpm -q --queryformat='%{version}-%{release}\n' -p "${CORE_RPM}")"
echo "RPM Version: $RPM_VERSION"
ls -1 "${WORKDIR}"/rpms/*

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

		EXTRA_ARGS=()
		# shellcheck disable=SC2154
		set +u
		if [ -n "${bamboo_capability_host_address}" ]; then
			EXTRA_ARGS+=("-Dorg.opennms.advertised-host-address=${bamboo_capability_host_address}")
		fi
		set -u

		RERUNS=2
		if [ "$FLAPPING" = "true" ]; then
			RERUNS=0
			EXTRA_ARGS+=('-Dopennms.test.excludedGroups=!org.opennms.core.test.junit.FlappingTests' '-Dopennms.test.groups=org.opennms.core.test.junit.FlappingTests')
		fi

		cd "${WORKDIR}/opennms-source" || exit 1
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
					-Dsurefire.rerunFailingTestsCount="${RERUNS}" \
					-Dfailsafe.rerunFailingTestsCount="${RERUNS}" \
					-Dorg.opennms.smoketest.logLevel=INFO \
					-Dtest.fork.count=2 \
					-Dorg.opennms.smoketest.docker=true \
					"${EXTRA_ARGS[@]}" \
					-Dsmoke=true \
					-t || exit 1
			cd ..
		cd ..
		;;
	*)
		cd smoke || exit 1
			# this branch has the old-style smoke tests
			echo "* Did NOT find Dockerized smoke tests"
			SHUNT_RPM="$(find debian-shunt -name debian-shunt-\*.noarch.rpm | sort -u | tail -n 1)"
			sudo rpm -Uvh "$SHUNT_RPM" || :

			sudo ./do-smoke-test.pl "${WORKDIR}/opennms-source" "${WORKDIR}/rpms" || exit 1
		cd ..
		;;
esac
