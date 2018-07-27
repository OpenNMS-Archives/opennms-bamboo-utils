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

# shellcheck source=environment.sh disable=SC1091
. "${MYDIR}/environment.sh"

set -euo pipefail

### SYSTEM SCRIPTS ###
get_primary_host_ip() {
	local _host_ip
	local _hostname
	local _ifconfig

	set +e

	_hostname="$(hostname)"
	if [ "$(host "$_hostname" 2>/dev/null | grep -c 'has address')" -gt 0 ]; then
		_host_ip="$(host "$_hostname" 2>/dev/null | grep 'has address' | head -n 1 | sed -e 's,^.*has address ,,')"
	else
		_ifconfig="$(command -v ifconfig)"
		if [ -n "$_ifconfig" ]; then
			_host_ip="$(ifconfig "$(netstat -rn | grep -E "^default|^0.0.0.0" | head -1 | awk '{print $NF}')" 2>/dev/null | grep 'inet ' | awk '{print $2}' | sed -e 's,^addr:,,' -e 's,/.*$,,')"
		else
			_host_ip="$(ip addr show dev "$(netstat -rn | grep -E "^default|^0.0.0.0" | head -1 | awk '{print $NF}')" 2>/dev/null | grep 'inet ' | awk '{print $2}' | sed -e 's,^addr:,,' -e 's,/.*$,,')"
		fi

	fi

	if [ -n "$_host_ip" ]; then
		echo "$_host_ip"
	else
		echo 127.0.0.1
	fi

	set -e
}

retry_sudo() {
	set +e
	if echo "" | "$@" >/tmp/$$.output 2>&1; then
		cat /tmp/$$.output
		rm /tmp/$$.output
		return 0
	else
		rm /tmp/$$.output
		echo "" | sudo -n "$@"
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

	_systemctl="$(command -v systemctl 2>/dev/null || :)"
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
	psql -U opennms -c 'SELECT datname FROM pg_database' -Pformat=unaligned -Pfooter=off 2>/dev/null | grep -E '^opennms_(test|it)_' >/tmp/$$.databases
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
	local docker_running
	set +eo pipefail

	# shellcheck disable=SC2046
	# stop all running docker containers
	docker_running="$(docker ps --no-trunc -a -q)"
	if [ -n "${docker_running}" ]; then
		# shellcheck disable=SC2086
		docker kill ${docker_running} 2>/dev/null || :
	fi

	if [ -e /var/run/docker.sock ]; then
		cat <<END >/tmp/docker-gc-exclude.txt
.*kafka.*:.*
.*elasticsearch.*:.*
END
		# garbage-collect old docker containers and images
		(docker run -v /tmp/docker-gc-exclude.txt:/tmp/docker-gc-exclude.txt -v /var/run/docker.sock:/var/run/docker.sock spotify/docker-gc env MINIMUM_IMAGES_TO_SAVE=1 EXCLUDE_FROM_GC=/tmp/docker-gc-exclude.txt /docker-gc) 2>/dev/null || :
	else
		docker system prune --all --volumes --force 2>/dev/null || :
	fi

	# remove any dangling mounted volumes
	docker system prune --volumes --force 2>/dev/null || :
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

get_sanitized_branch_name() {
	local _workdir
	local _branch_name

	_workdir="$1"; shift
	_branch_name="$(get_branch_name "${_workdir}" | sed -e 's,[^[:alnum:]][^[:alnum:]]*,.,g' -e 's,^\.,,' -e 's,\.$,,')"

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
		retry_sudo rm -rf "$HOME"/.m2/repository*/{com,org}/opennms
	fi
}

clean_maven_target_directories() {
	local _workdir

	_workdir="$1"; shift

	retry_sudo find "$_workdir" -type d -name target -print0 | xargs -0 rm -rf
}

clean_node_directories() {
	local _workdir

	_workdir="$1"; shift

	retry_sudo rm -rf "${_workdir}/node_modules"
}

### Filesystem/Path Admin ###

get_classes() {
	local _workdir
	local _outputdir
	local _suffix
	local _exclude

	local _workfile
	local _outputfile

	_workdir="$1"; shift
	_outputdir="$1"; shift
	_suffix="$1"; shift
	_exclude="$1"; shift || :

	(
		set -e
		set +o pipefail

		_workfile="${_outputdir}/$(echo "${_suffix}" | tr '[:upper:]' '[:lower:]')-files.txt"
		_outputfile="${_outputdir}/$(echo "${_suffix}" | tr '[:upper:]' '[:lower:]')s.txt"

		FIND=(find "${_workdir}/" -type f -name "*${_suffix}.java")
		"${FIND[@]}"
		if [ -n "${_exclude-}" ]; then
			"${FIND[@]}" | sed -e 's,//,/,g' | grep -v "${_exclude}" > "${_workfile}"
		else
			"${FIND[@]}" | sed -e 's,//,/,g' > "${_workfile}"
		fi
		xargs grep 'public class' < "${_workfile}" | \
			cut -d: -f2 | \
			sed -e 's,^.*public[	 ][	 ]*class[	 ][	 ]*,,' -e 's,[	 ][	 ]*.*$,,' | \
			grep -E "${_suffix}"'$' | \
			sort -u > "${_outputfile}"
		echo "${_outputfile}"
	)
}

split_file() {
	local _inputfile
	local _pieces

	local _count
	local _outputdir
	local _prefix

	_inputfile="$1"; shift
	_pieces="$1"; shift

	(
		set -eo pipefail
		_outputdir="$(dirname "${_inputfile}")"
		_prefix="${_inputfile%.*}"

		_count="$(wc -l < "${_inputfile}")"
		if [ -z "${_count}" ] || [ "${_count}" -eq 0 ]; then
			echo "no lines found" >&2
			echo 0
			return
		fi
		split -l $(( _count / _pieces )) "${_inputfile}" "${_prefix}."
		echo "${_count}"
	)
}

get_tests() {
	local _testfile
	local _job

	local _prefix

	_testfile="$1"; shift
	_job="$1"; shift

	(
		set -eo pipefail

		_prefix="${_testfile%.*}"

		if [ ! -e "${_prefix}.${_job}" ]; then
			echo "WARNING: ${_prefix}.${_job} does not exist. Returning an empty string." >&2
			echo ""
			return
		fi

		paste -sd , - < "${_prefix}.${_job}"
	)
}

# usage: fix_ownership $WORKDIR [$file_to_match]
# If file_to_match is not passed, attempts to use the bamboo uid/gid.
# If bamboo uid/gid can't be determined, falls back to the 'opennms' user/group.
fix_ownership() {
	local _workdir
	local _chown_user
	local _chown_group

	_workdir="$1"; shift
	set +u
	if [ -n "$1" ]; then
		# shellcheck disable=SC2012
		_chown_user="$(ls -n "$1" | awk '{ print $3 }')"
		# shellcheck disable=SC2012
		_chown_group="$(ls -n "$1" | awk '{ print $4 }')"
	else
		_chown_user="$(id -u bamboo 2>/dev/null)"
		_chown_group="$(id -g bamboo 2>/dev/null)"
	fi
	set -u

	if [ -z "${_chown_user}" ] || [ "${_chown_user}" -eq 0 ]; then
		_chown_user="opennms"
	fi
	if [ -z "${_chown_group}" ] || [ "${_chown_group}" -eq 0 ]; then
		_chown_group="opennms"
	fi

	retry_sudo chown -R "${_chown_user}:${_chown_group}" "${_workdir}"
}

warn_ownership() {
	local _workdir
	local _user
	local _group

	_workdir="$1"; shift
	if [ -z "$1" ]; then
		echo 'You must specify a file to match!'
		exit 1
	fi
	_checkfile="$1"; shift

	set +u
	# shellcheck disable=SC2012
	_user="$(ls -n "${_checkfile}" | awk '{ print $3 }')"
	# shellcheck disable=SC2012
	_group="$(ls -n "${_checkfile}" | awk '{ print $4 }')"
	set -u

	if [ -z "${_user}" ] || [ -z "${_group}" ]; then
		echo "Unable to determine UID and GID of ${_checkfile}"
		exit 1
	fi

	COUNT="$(find "${_workdir}" ! -uid "${_user}" -o ! -gid "${_group}" | wc -l | sed -e 's, *,,')"
	if [ "$COUNT" -gt 0 ]; then
		echo "WARNING: $COUNT file(s) are not owned by ${_user}:${_group}."
	fi
	return "$COUNT"
}
