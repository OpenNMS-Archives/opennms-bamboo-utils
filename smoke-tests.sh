#!/bin/bash -x

MYDIR=$(dirname "$0")
MYDIR=$(cd "$MYDIR" || exit 1; pwd)

# shellcheck source=lib.sh
. "${MYDIR}/lib.sh"

set +eo pipefail

export PATH="/opt/firefox:/usr/local/bin:$PATH"
export PHANTOMJS_CDNURL="https://mirror.internal.opennms.com/phantomjs/"

if [ -x "opennms-source/bin/javahome.pl" ]; then
	JAVA_HOME="$(opennms-source/bin/javahome.pl)"
fi
export JAVA_HOME

RPM_VERSION="$(rpm -q --queryformat='%{version}\n' -p rpms/opennms-core-*.rpm)"
echo "RPM Version: $RPM_VERSION"
ls -1 "${WORKDIR}"/rpms/*

SMOKE_TEST_API_VERSION="$(grep -C1 org.opennms.smoke.test-api "${WORKDIR}/opennms-source/smoke-test/pom.xml"  | grep '<version>' | sed -e 's,.*<version>,,' -e 's,</version>,,' -e 's,-SNAPSHOT$,,')"
case "$SMOKE_TEST_API_VERSION" in
	"2")
		DOCKERDIR="${WORKDIR}/opennms-system-test-api/docker"

		# this branch is using the new-style dockerized smoke tests
		# nothing special needed other than running the tests
		echo "* Found Dockerized smoke tests"

		mkdir -p "${DOCKERDIR}/opennms/rpms" "${DOCKERDIR}/minion/rpms"
		rm -rf "${DOCKERDIR}"/rpms/*.rpm
		mv "${WORKDIR}"/rpms/*.rpm "${DOCKERDIR}/opennms/rpms/"
		mv "${DOCKERDIR}"/opennms/rpms/*minion* "${DOCKERDIR}"/minion/rpms/ || :
		cd "${DOCKERDIR}" || exit 1
			./build-docker-images.sh
		cd "${WORKDIR}" || exit 1

		cd opennms-source
			./compile.pl -Dmaven.test.skip.exec=true -Dsmoke=true --projects org.opennms:smoke-test --also-make install
			cd smoke-test
				xvfb-run --wait=20 --server-args="-screen 0 1920x1080x24" --server-num=80 --auto-servernum --listen-tcp ../compile.pl -Dorg.opennms.smoketest.logLevel=INFO -Dsmoke=true -t
			cd ..
		cd ..
		;;
	*)
		cd smoke
			# this branch has the old-style smoke tests
			echo "* Did NOT find Dockerized smoke tests"
			SHUNT_RPM="$(find debian-shunt -name debian-shunt-\*.noarch.rpm | sort -u | tail -n 1)"
			sudo rpm -Uvh "$SHUNT_RPM" || :

			sudo ./do-smoke-test.pl "${WORKDIR}"/opennms-source "${WORKDIR}"/rpms
		cd ..
		;;
esac
