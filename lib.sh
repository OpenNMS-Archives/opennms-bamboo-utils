#!/bin/bash

set -euo pipefail

assert_opennms_repo_version() {
	local repoversion

	repoversion=$(opennms-release.pl | sed -e 's,^v,,' | cut -d. -f1-2)

	if [[ $(echo "${repoversion} < 2.9" | bc) == 1 ]]; then
		echo 'Install OpenNMS::Release 2.9.0 or greater!'
		exit 1
	fi
}

get_branch_name() {
	local workdir
	local branch_name

	workdir="$1"

	set +u
	# shellcheck disable=SC2154
	if [ -z "${bamboo_OPENNMS_BRANCH_NAME}" ]; then
		branch_name="${bamboo_planRepository_branchName}"
	else
		branch_name="${bamboo_OPENNMS_BRANCH_NAME}"
	fi
	set -u

	if [ -z "$branch_name" ] || [ "$(echo "$branch_name" | grep -c '\$')" -gt 0 ]; then
		# branch did not get substituted, use git instead
		echo "WARNING: \$bamboo_OPENNMS_BRANCH_NAME and \$bamboo_planRepository_branchName are not set, attempting to determine branch with \`git symbolic-ref HEAD\`." >&2
		branch_name="$( (cd "${workdir}" || exit 1; git symbolic-ref HEAD) | sed -e 's,^refs/heads/,,')"
	fi

	echo "${branch_name}"
}

get_repo_name() {
	local workdir
	local repo_name

	workdir="$1";

	set +u
	# shellcheck disable=SC2154
	if [ -z "${bamboo_OPENNMS_BUILD_REPO}" ]; then
		repo_name=$(cat "${workdir}/.nightly")
	else
		repo_name="${bamboo_OPENNMS_BUILD_REPO}"
	fi
	set -u

	echo "${repo_name}"
}

get_opennms_version() {
	local workdir

	workdir="$1"

	set +o pipefail
	grep '<version>' "${workdir}/pom.xml" | head -n 1 | sed -e 's,^.*<version>,,' -e 's,<.version>.*$,,'
	set -o pipefail
}

get_git_hash() {
	local workdir

	workdir="$1"

	cd "${workdir}" || exit 1
	git rev-parse HEAD
}
