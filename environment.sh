#!/bin/bash
if [ -z "${bamboo_buildKey}" ]; then
	echo "WARNING: \$bamboo_buildKey is unset.  Setting it to 'cli' but this is probably wrong." >&2
	export bamboo_buildKey="cli"
fi

export M2_LOCAL_REPOSITORY="$HOME/.m2/repository-${bamboo_buildKey}"
export JICMP_USE_SOCK_DGRAM="1"
export COMPILE_OPTIONS=("-DupdatePolicy=never" "-Dmaxmemory=2g" "-Dorg.ops4j.pax.url.mvn.localRepository=$M2_LOCAL_REPOSITORY" "-Daether.connector.basic.threads=1" "-Daether.connector.resumeDownloads=false" "--batch-mode" "-Dorg.slf4j.simpleLogger.log.org.apache.maven.cli.transfer.Slf4jMavenTransferListener=warn")
export SKIP_TESTS=("-Dmaven.test.skip.exec=true" "-DskipITs=true")
export ENABLE_TESTS=("-Dmaven.test.skip.exec=false" "-DskipITs=false")
export PATH="/usr/local/bin:$PATH"

# shellcheck disable=SC2154
export BAMBOO_BUILD_NUMBER="${bamboo_buildNumber}"

# shellcheck disable=SC2154
export BAMBOO_WORKING_DIRECTORY="${bamboo_working_directory}"

if [ -z "$MAVEN_OPTS" ]; then
	MAVEN_OPTS="-Xmx2048m -XX:ReservedCodeCacheSize=512m"
fi
