#!/usr/bin/env bash
# scripts/backup_restore.sh
#
# Restores a backup generated by backup_collector.sh
# Use:
#   ./scripts/backup_restore.sh <TIMESTAMP> [collection1 collection2 ...]

set -euo pipefail

# Load .env
ENV_FILE="$(dirname "$0")/../.env"
if [ -f "$ENV_FILE" ]; then
  set -o allexport; source "$ENV_FILE"; set +o allexport
fi

NUM_INS_WORKERS="${NUM_INS_WORKERS:-4}"

# 1) Requirements
: "${MONGO_URI_RESTORE:?MONGO_URI_RESTORE not defined in .env}"
: "${DB_NAME_RESTORE:?DB_NAME_RESTORE not defined in .env}"
command -v mongorestore >/dev/null 2>&1 \
  || { echo >&2 "❌ mongorestore not found. Please install the Database Tools."; exit 1; }

# 2) Arguments
if [ $# -lt 1 ]; then
  echo "Usage: $0 <TIMESTAMP> [collection1 collection2 ...]"
  exit 1
fi

TIMESTAMP="$1"
shift  # remove the first argument from "$@"

# 3) Backup location
BASE_BACKUP_DIR="${BACKUP_DIR:-$(pwd)/backups}"
BACKUP_PATH="$BASE_BACKUP_DIR/$TIMESTAMP"
[ -d "$BACKUP_PATH" ] || { echo "❌ Snapshot not found: $BACKUP_PATH"; exit 1; }

# 4) Desired collections list
if [ $# -eq 0 ]; then
  WANT=()  # empty = all
else
  WANT=( "$@" )
fi

echo "🔄 Restoring snapshot $TIMESTAMP → destination DB: $DB_NAME_RESTORE"
echo "   Filtered collections: ${WANT[*]:-(all)}"

# 5) If no collections passed, restore all .gz
if [ $# -eq 0 ]; then
    mapfile -t COLLS < <(
        cd "$BACKUP_PATH"
        for f in *.gz; do
            printf '%s\n' "${f%.gz}"
        done
    )
else
  COLLS=( "$@" )
fi

echo "🔄 Starting restore from backup at: $BACKUP_PATH"
echo "    Destination DB: $DB_NAME_RESTORE"
echo "    Collections: ${COLLS[*]}"

# 6) For each source DB (subfolder)
for ORIG_DB_DIR in "$BACKUP_PATH"/*/; do
  [ -d "$ORIG_DB_DIR" ] || continue
  ORIG_DB=$(basename "$ORIG_DB_DIR")

  # 7) For each .gz file in that subfolder
  for file in "$ORIG_DB_DIR"/*.gz; do
    COLL=$(basename "$file" .gz)

    # if specific collections requested, skip others
    if [ "${#WANT[@]}" -gt 0 ]; then
      skip=1
      for w in "${WANT[@]}"; do
        [ "$w" = "$COLL" ] && { skip=0; break; }
      done
      [ $skip -eq 1 ] && continue
    fi

    echo "  • Restoring $ORIG_DB.$COLL → $DB_NAME_RESTORE.$COLL"
    mongorestore \
      --uri="$MONGO_URI_RESTORE" \
      --gzip \
      --archive="$file" \
      --nsFrom="${ORIG_DB}.${COLL}" \
      --nsTo="${DB_NAME_RESTORE}.${COLL}" \
      ----numInsertionWorkersPerCollection="$NUM_INS_WORKERS"
  done
done

echo "✅ Restore completed."