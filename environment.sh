#!/bin/bash
set +u
if [ -z "${bamboo_planKey}" ]; then
	echo "WARNING: \$bamboo_planKey is unset.  Setting it to 'cli' but this is probably wrong." >&2
	export bamboo_planKey="cli"
fi

export M2_LOCAL_REPOSITORY="$HOME/.m2/repository-${bamboo_planKey}"
export JICMP_USE_SOCK_DGRAM="1"
export COMPILE_OPTIONS=("-DupdatePolicy=never" "-Dmaxmemory=4g" "-Dorg.ops4j.pax.url.mvn.localRepository=$M2_LOCAL_REPOSITORY" "-Daether.connector.basic.threads=1" "-Daether.connector.resumeDownloads=false" "-Dorg.slf4j.simpleLogger.log.org.apache.maven.cli.transfer.Slf4jMavenTransferListener=warn" "--batch-mode")
export SKIP_TESTS=("-Dmaven.test.skip.exec=true" "-DskipITs=true")
export ENABLE_TESTS=("-Dmaven.test.skip.exec=false" "-DskipITs=false")
export PATH="/usr/local/bin:$PATH"

# shellcheck disable=SC2154
export BAMBOO_BUILD_NUMBER="${bamboo_buildNumber}"

# shellcheck disable=SC2154
export BAMBOO_WORKING_DIRECTORY="${bamboo_working_directory}"

if [ -z "$MAVEN_OPTS" ]; then
	MAVEN_OPTS="-Xmx4g -XX:ReservedCodeCacheSize=1g"
fi
set -u
