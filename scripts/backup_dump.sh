#!/usr/bin/env bash
# scripts/backup_dump.sh
#
# Generates gzip backups of N collections and writes a log to logs/<TIMESTAMP>.log
#
# Usage:
#   chmod +x scripts/backup_dump.sh
#   source .env
#   ./scripts/backup_dump.sh collaborator turnOperation users

set -euo pipefail

# Load .env
ENV_FILE="$(dirname "$0")/../.env"
if [ -f "$ENV_FILE" ]; then
  set -o allexport; source "$ENV_FILE"; set +o allexport
fi

# 1) Requirements
: "${MONGO_URI_DUMP:?MONGO_URI_DUMP not defined in .env}"
: "${DB_NAME_DUMP:?DB_NAME_DUMP not defined in .env}"
command -v mongodump >/dev/null 2>&1 \
  || { echo >&2 "❌ mongodump not found. Please install the Database Tools."; exit 1; }

# 2) Arguments (collections)
if [ $# -lt 1 ]; then
  echo "Usage: $0 <collection1> [collection2 ...]"
  exit 1
fi

# 3) Timestamp and directory
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"

# 4) Directories
BASE_BACKUP_DIR="${BACKUP_DIR:-$(pwd)/backups}"
OUT_BACKUP="$BASE_BACKUP_DIR/$TIMESTAMP/$DB_NAME_DUMP"
mkdir -p "$OUT_BACKUP"

LOG_DIR="$(pwd)/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/$TIMESTAMP.log"

# 5) Redirect all output to console AND to $LOG_FILE
exec > >(tee -a "$LOG_FILE") 2>&1

echo "🔄 Starting backup at: $OUT_BACKUP"
echo "    Database:    $DB_NAME_DUMP"
echo "    Collections: $*"

# 6) Dump loop
for coll in "$@"; do
  echo "  • Dumping collection '$coll'…"
  mongodump \
    --uri="$MONGO_URI_DUMP" \
    --db="$DB_NAME_DUMP" \
    --collection="$coll" \
    --gzip \
    --archive="$OUT_BACKUP/${coll}.gz"
done

echo "✅ Backup completed at: $OUT_BACKUP"
echo "📓 Log saved at: $LOG_FILE"
