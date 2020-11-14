#!/bin/bash


set -o errexit -o errtrace -o nounset

fail()
{
	echo "ERROR - $1" >&2
	exit 1
}

echo -e "\\n=== $(date) BACKUP STARTED ===\\n"

BACKUP_ROOT="/mnt/backup"
BACKUP_FILES="$BACKUP_ROOT/files"
BACKUP_MYSQL_FILE="$BACKUP_FILES/mysql_backup_$(date +%F).sql"

SCRIPT_ROOT=$(dirname "$(realpath "$0")")
CONFIG_FILE="$SCRIPT_ROOT/backup.conf"

# shellcheck source=/dev/null
. "$CONFIG_FILE"

NAS_WAIT_TIMEOUT=600
nas_wait_count=0

echo "Wake up NAS..."
wakeonlan '00:11:32:59:52:13'

echo -n "Wait for NAS to be up and running"
while ! ping -c 1 -W 2 nas &>/dev/null; do
	echo -n "."
	sleep 1
	nas_wait_count=$((nas_wait_count+1))
	[ "$nas_wait_count" -ge "$NAS_WAIT_TIMEOUT" ] && fail "Failed to reach NAS!"
done

echo
echo "Waiting 2 minutes for the NAS share fs to be ready"

sleep 120

echo "Files in $BACKUP_FILES"
ls "$BACKUP_FILES" || ls "$BACKUP_FILES" || fail "Failed to access NAS share fs"

echo "Starting backup"

rsnapshot weekly

mysqldump -u "$MYSQL_USER" --password="$MYSQL_PASSWORD" --all-databases --quick --single-transaction > "$BACKUP_MYSQL_FILE"

chmod 640 "$BACKUP_MYSQL_FILE"

ln -sf "$BACKUP_MYSQL_FILE" "$BACKUP_ROOT/last_mysql_backup.tgz"

echo "Will suppress:"
find "$BACKUP_FILES" -maxdepth 1 -mindepth 1 -type f -mtime +100 -exec ls -l {} \;
find "$BACKUP_FILES" -maxdepth 1 -mindepth 1 -type f -mtime +100 -exec rm -f {} \;

echo -e "\\n=== $(date) BACKUP ENDED ===\\n"

exit 0

