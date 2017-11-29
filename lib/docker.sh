#!/bin/bash

set -euo pipefail

reset_docker() {
	echo "- killing and removing existing Docker containers..."
	set +eo pipefail
	# shellcheck disable=SC2046
	# stop all running docker containers
	(docker kill $(docker ps --no-trunc -a -q)) 2>/dev/null || :

	if [ -e /var/run/docker.sock ]; then
		cat <<END >/tmp/docker-gc-exclude.$$
opennms/*
stests/*
END
		# garbage-collect old docker containers and images
		(docker run -v /tmp/docker-gc-exclude.$$:/tmp/docker-gc-exclude.txt -v /var/run/docker.sock:/var/run/docker.sock spotify/docker-gc env MINIMUM_IMAGES_TO_SAVE=1 EXCLUDE_FROM_GC=/tmp/docker-gc-exclude.txt /docker-gc) 2>/dev/null || :
	else
		docker system prune --all --volumes --force 2>/dev/null || :
	fi

	# remove any dangling mounted volumes
	docker system prune --volumes --force 2>/dev/null || :
	rm -f /tmp/docker-gc-exclude.$$ || :
	set -eo pipefail
}

set +euo pipefail
