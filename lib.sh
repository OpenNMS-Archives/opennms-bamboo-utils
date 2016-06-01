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

### SYSTEM SCRIPTS ###
retry_sudo() {
	set +e
	if echo "" | "$@" >/tmp/$$.output 2>&1; then
		cat /tmp/$$.output
		rm /tmp/$$.output
		return 0
	else
		rm /tmp/$$.output
		echo "" | sudo "$@"
	fi
	set -e
}

increase_limits() {
	local limit

	limit=$(ulimit -n)
	if [ "$limit" -lt 4096 ]; then
		ulimit -n 4096
	fi

	limit=$(cat /proc/sys/kernel/threads-max)
	if [ "$limit" -lt 200000 ]; then
		sudo bash -c 'echo 200000 > /proc/sys/kernel/threads-max'
	fi

	limit=$(cat /proc/sys/vm/max_map_count)
	if [ "$limit" -lt 100000 ]; then
		sudo bash -c 'echo 128000 > /proc/sys/vm/max_map_count'
	fi
}

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

stop_firefox() {
	retry_sudo killall firefox >/dev/null 2>&1 || :
}

stop_compiles() {
	set +eo pipefail
	KILLME=$(pgrep -f '(failsafe|surefire|git-upload-pack|bin/java .*install$)')
	if [ -n "$KILLME" ]; then
		# shellcheck disable=SC2086
		retry_sudo kill $KILLME || :
		sleep 5
		# shellcheck disable=SC2086
		retry_sudo kill -9 $KILLME || :
	fi
	set -eo pipefail
}

reset_postgresql() {
	echo "- cleaning up postgresql:"

	retry_sudo service postgresql restart || :

	set +euo pipefail
	psql -U opennms -c 'SELECT datname FROM pg_database' -Pformat=unaligned -Pfooter=off 2>/dev/null | grep -E '^opennms_test' >/tmp/$$.databases
	set -euo pipefail

	(while read -r DB; do
		echo "  - removing $DB"
		dropdb -U opennms "$DB"
	done) < /tmp/$$.databases
	echo "- finished cleaning up postgresql"
	rm /tmp/$$.databases
}

reset_docker() {
	echo "- killing and removing existing Docker containers..."
	set +eo pipefail
	# shellcheck disable=SC2046
	(docker kill $(docker ps --no-trunc -a -q)) 2>/dev/null | :
	# shellcheck disable=SC2046
	(docker rm $(docker ps --no-trunc -a -q)) 2>/dev/null || :
	(docker images --no-trunc | grep none | awk '{ print $3 }' | xargs docker rmi) 2>/dev/null || :
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
