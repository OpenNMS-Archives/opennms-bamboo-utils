#!/bin/bash

source $(dirname $0)/../lib.sh

git() {
	ARG5=${5:-}
	if [ "$1" = "log" ] && [ "$2" = "--pretty=format:%cd" ] && [ "$3" = "--date=short" ] && [ "$4" = "-1" ] && [ -z "$ARG5" ]; then
		echo 20170101
	else
		echo "expected: git log --pretty=format:%cd --date=short -1" >&2
		echo "got: git $@" >&2
		exit 1
	fi
}

testGetGitDate() {
	assertEqual "$(get_git_date "${MYDIR}")" "20170101"
}

source $(dirname $0)/bashunit