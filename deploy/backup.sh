#!/bin/sh
# Database backup for TrueNAS (System → Advanced Settings → Cron Jobs, run as root):
#
#   /mnt/POOL/apps/plattensammlung/backup.sh /mnt/POOL/apps/plattensammlung/backups 30
#
# Writes a compressed pg_dump and deletes dumps older than the given number of
# days (default 30). Covers are protected by ZFS snapshots of their dataset.
set -eu

BACKUP_DIR="${1:?Aufruf: backup.sh <Zielordner> [Tage aufbewahren]}"
KEEP_DAYS="${2:-30}"
# TrueNAS names the compose project "ix-<app name>"
PROJECT="${PROJECT:-ix-plattensammlung}"

CONTAINER=$(docker ps -q \
  --filter "label=com.docker.compose.project=$PROJECT" \
  --filter "label=com.docker.compose.service=db")

if [ -z "$CONTAINER" ]; then
  echo "Datenbank-Container von $PROJECT läuft nicht" >&2
  exit 1
fi

mkdir -p "$BACKUP_DIR"
FILE="$BACKUP_DIR/plattensammlung-$(date +%Y%m%d-%H%M).sql.gz"

docker exec "$CONTAINER" pg_dump -U postgres --clean --if-exists plattensammlung | gzip > "$FILE.tmp"
mv "$FILE.tmp" "$FILE"

find "$BACKUP_DIR" -name 'plattensammlung-*.sql.gz' -mtime +"$KEEP_DAYS" -delete
echo "Backup geschrieben: $FILE"
