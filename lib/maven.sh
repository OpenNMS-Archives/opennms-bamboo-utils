#!/bin/bash

set -euo pipefail

clean_m2_repository() {
	if [ -d "$HOME/.m2" ]; then
		retry_sudo rm -rf "$HOME"/.m2/repository*/org/opennms
	fi
}

clean_maven_target_directories() {
	local _workdir

	_workdir="$1"; shift

	retry_sudo find "$_workdir" -type d -name target -delete
}

set +euo pipefail