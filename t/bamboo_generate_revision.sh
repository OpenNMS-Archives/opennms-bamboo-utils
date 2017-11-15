#!/bin/bash

source $(dirname $0)/../lib.sh

get_git_date() {
	echo "20170101"
}

testGenerateRevisionNoBamboo() {
	export bamboo_OPENNMS_BRANCH_NAME=""
	export bamboo_buildKey=""
	export bamboo_buildNumber=""
	export bamboo_planRepository_branchName=""
	export bamboo_shortPlanKey=""
	assertEqual "$(generate_revision "${MYDIR}")" "0.20170101.1"
}

testGenerateRevisionWithBamboo() {
#	export bamboo_OPENNMS_BRANCH_NAME="master"
#	export bamboo_buildKey="OPENNMS-ONMS1868-COMPILE"
#	export bamboo_buildNumber="32"
#	export bamboo_planRepository_branchName="master"
#	export bamboo_shortPlanKey="ONMS1868"
	assertEqual "true" "false"
	assertEqual "$(generate_revision "${MYDIR}")" "0.20170101.onms1868.master.32"
}

source $(dirname $0)/bashunit