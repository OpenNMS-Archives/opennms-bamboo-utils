#!/bin/bash

set -euo pipefail

reset_postgresql() {
	echo "- cleaning up postgresql:"

	retry_sudo service postgresql restart || :

	set +euo pipefail
	psql -U opennms -c 'SELECT datname FROM pg_database' -Pformat=unaligned -Pfooter=off 2>/dev/null | grep -E '^opennms_test' >/tmp/$$.databases
	set -euo pipefail

	(while read -r DB; do
		echo "  - removing $DB"
		dropdb -U opennms "$DB"
	done) < /tmp/$$.databases
	echo "- finished cleaning up postgresql"
	rm /tmp/$$.databases
}

set +euo pipefail