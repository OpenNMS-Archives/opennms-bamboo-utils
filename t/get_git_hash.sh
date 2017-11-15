#!/bin/bash

source $(dirname $0)/../lib.sh

git() {
	ARG3=${3:-}
	if [ "$1" = "rev-parse" ] && [ "$2" = "HEAD" ] && [ -z "$ARG3" ]; then
		echo f966aa2704a7496ddae633c391467fa884c6a4b8
	else
		echo "expected: git rev-parse HEAD" >&2
		echo "got: git $@" >&2
		return 1
	fi
}

testGetGitHash() {
	assertEqual "$(get_git_hash "${MYDIR}")" "f966aa2704a7496ddae633c391467fa884c6a4b8"
}

source $(dirname $0)/bashunit