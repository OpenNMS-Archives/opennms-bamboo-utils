#!/bin/bash

WORKDIR="$1"; shift

if [ -z "$WORKDIR" ] || [ ! -d "$WORKDIR" ]; then
	echo "usage: $0 <working-directory>" >&2
	echo "" >&2
	exit 1
fi

if [ -z "$MYDIR" ] || [ ! -d "$MYDIR" ]; then
	echo "\$MYDIR not initialized!" >&2
	echo "" >&2
	exit 1
fi

# shellcheck source=environment.sh
. "${MYDIR}/environment.sh"

set -euo pipefail

retry_sudo() {
	set +e
	if "$@"; then
		return 0
	else
		sudo "$@"
	fi
	set -e
}

### OpenNMS Scripts ###
assert_opennms_repo_version() {
	local repoversion

	repoversion=$(opennms-release.pl | sed -e 's,^v,,' | cut -d. -f1-2)

	if [[ $(echo "${repoversion} < 2.9" | bc) == 1 ]]; then
		echo 'Install OpenNMS::Release 2.9.0 or greater!'
		exit 1
	fi
}

stop_opennms() {
	local _systemctl
	local _opennms

	_systemctl="$(which systemctl)"
	_opennms="/opt/opennms/bin/opennms"

	if [ -e "${_systemctl}" ] && [ -x "${_systemctl}" ]; then
		retry_sudo "${_systemctl}" stop opennms || :
	fi
	if [ -e "${_opennms}" ] && [ -x "${_opennms}" ]; then
		retry_sudo "${_opennms}" stop || :
		sleep 5
		retry_sudo "${_opennms}" kill || :
	fi
}

stop_firefox() {
	retry_sudo killall firefox >/dev/null 2>&1 || :
}

stop_compiles() {
	set +eo pipefail
	KILLME=`ps auxwww | grep -i -E '(failsafe|surefire|bin/java .*install$)' | grep -v ' grep ' | awk '{ print $2 }'`
	kill $KILLME >/dev/null 2>&1 || :
	sleep 5
	kill -9 $KILLME >/dev/null 2>&1 || :
	set -eo pipefail
}


### GIT and Maven ###
get_branch_name() {
	local _workdir
	local _branch_name

	_workdir="$1"; shift

	set +u
	# shellcheck disable=SC2154
	if [ -z "${bamboo_OPENNMS_BRANCH_NAME}" ]; then
		_branch_name="${bamboo_planRepository_branchName}"
	else
		_branch_name="${bamboo_OPENNMS_BRANCH_NAME}"
	fi
	set -u

	if [ -z "$_branch_name" ] || [ "$(echo "$_branch_name" | grep -c '\$')" -gt 0 ]; then
		# branch did not get substituted, use git instead
		echo "WARNING: \$bamboo_OPENNMS_BRANCH_NAME and \$bamboo_planRepository_branchName are not set, attempting to determine branch with \`git symbolic-ref HEAD\`." >&2
		_branch_name="$( (cd "${_workdir}" || exit 1; git symbolic-ref HEAD) | sed -e 's,^refs/heads/,,')"
	fi

	echo "${_branch_name}"
}

get_repo_name() {
	local _workdir
	local _repo_name

	_workdir="$1"; shift

	set +u
	# shellcheck disable=SC2154
	if [ -z "${bamboo_OPENNMS_BUILD_REPO}" ]; then
		_repo_name=$(cat "${_workdir}/.nightly")
	else
		_repo_name="${bamboo_OPENNMS_BUILD_REPO}"
	fi
	set -u

	echo "${_repo_name}"
}

get_opennms_version() {
	local _workdir

	_workdir="$1"; shift

	set +o pipefail
	grep '<version>' "${_workdir}/pom.xml" | head -n 1 | sed -e 's,^.*<version>,,' -e 's,<.version>.*$,,'
	set -o pipefail
}

get_git_hash() {
	local _workdir

	_workdir="$1"; shift

	cd "${_workdir}" || exit 1
	git rev-parse HEAD
}

clean_m2_repository() {
	if [ -d "$HOME/.m2" ]; then
		retry_sudo rm -rf "$HOME"/.m2/repository*/org/opennms
	fi
}

clean_maven_target_directories() {
	local _workdir

	_workdir="$1"; shift

	retry_sudo find "$_workdir" -type d -name target -print0 | xargs -0 rm -rf
}


### Filesystem/Path Admin ###
fix_ownership() {
	local _workdir
	local _chown_id

	_workdir="$1"; shift
	_chown_id="$(id -u bamboo 2>/dev/null)"

	if [ -z "${_chown_id}" ] || [ "${_chown_id}" -eq 0 ]; then
		_chown_id="opennms"
	fi

	retry_sudo chown -R "${_chown_id}:${_chown_id}" "${_workdir}"
}
