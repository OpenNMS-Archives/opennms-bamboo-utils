#!/bin/bash

set -euo pipefail

stop_opennms() {
	local _systemctl
	local _opennms

	_systemctl="$(which systemctl 2>/dev/null || :)"
	_opennms="/opt/opennms/bin/opennms"

	if [ -e "${_systemctl}" ] && [ -x "${_systemctl}" ]; then
		retry_sudo "${_systemctl}" stop opennms || :
	fi
	if [ -e "${_opennms}" ] && [ -x "${_opennms}" ]; then
		retry_sudo "${_opennms}" stop || :
		sleep 5
		retry_sudo "${_opennms}" kill || :
	else
		echo "WARNING: ${_opennms} does not exist"
	fi
}

clean_opennms() {
	for PKG_SUFFIX in \
		upgrade \
		docs \
		core \
		plugin-ticketer-centric \
		source \
		remote-poller \
		minion-core \
		minion-features \
		minion-container
	do
		retry_sudo yum -y remove "opennms-${PKG_SUFFIX}" || :
		retry_sudo yum -y remove "meridian-${PKG_SUFFIX}" || :
	done
	retry_sudo rm -rf /opt/opennms /opt/minion /usr/lib/opennms, /usr/share/opennms, /var/lib/opennms, /var/log/opennms, /var/opennms
}

get_opennms_version() {
	local _workdir

	_workdir="$1"; shift

	set +o pipefail
	grep '<version>' "${_workdir}/pom.xml" | head -n 1 | sed -e 's,^.*<version>,,' -e 's,<.version>.*$,,'
	set -o pipefail
}

set +euo pipefail