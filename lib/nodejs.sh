#!/bin/bash

set -euo pipefail

clean_node_directories() {
	local _workdir

	_workdir="$1"; shift

	retry_sudo rm -rf "${_workdir}/node_modules"
}

set +euo pipefail