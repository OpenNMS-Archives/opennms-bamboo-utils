#!/bin/sh

if [ -z "${bamboo_buildKey}" ]; then
	echo "WARNING: \$bamboo_buildKey is unset.  Setting it to 'cli' but this is probably wrong."
	export bamboo_buildKey="cli"
fi

export M2_LOCAL_REPOSITORY="$HOME/.m2/repository-${bamboo_buildKey}"
export JICMP_USE_SOCK_DGRAM="1"
export COMPILE_OPTIONS="-DupdatePolicy=never -Dorg.ops4j.pax.url.mvn.localRepository=$M2_LOCAL_REPOSITORY"
export SKIP_TESTS="-Dmaven.test.skip.exec=true -DskipITs=true"
export ENABLE_TESTS="-Dmaven.test.skip.exec=false -DskipITs=false"
