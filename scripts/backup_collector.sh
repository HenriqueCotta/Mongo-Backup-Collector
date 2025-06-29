#!/usr/bin/env bash
# scripts/backup_collector.sh

set -euo pipefail

# 0) carrega .env
ENV_FILE="$(dirname "$0")/../.env"
if [ -f "$ENV_FILE" ]; then
  set -o allexport
  source "$ENV_FILE"
  set +o allexport
fi

# 1) requisitos
: "${MONGO_URI:?MONGO_URI não definida em .env}"
: "${DB_NAME:?DB_NAME não definida em .env}"
command -v mongodump >/dev/null 2>&1 \
  || { echo >&2 "❌ mongodump não encontrado. Instale o Database Tools."; exit 1; }

# 2) timestamp e diretório
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
BASE_DIR="${BACKUP_DIR:-$(pwd)/backups}"
OUT_ROOT="$BASE_DIR/$TIMESTAMP"

# 3) coleções
if [ $# -lt 1 ]; then
  echo "Uso: $0 <coleção1> [coleção2 ...]"
  exit 1
fi

# 4) logging
mkdir -p "$OUT_ROOT"
LOG_FILE="$OUT_ROOT/backup.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "🔄 Iniciando backup em: $OUT_ROOT"
echo "    Banco:    $DB_NAME"
echo "    Coleções: $*"

# 5) dump
for coll in "$@"; do
  echo "  • Dump da coleção '$coll'…"
  mongodump \
    --uri="$MONGO_URI" \
    --db="$DB_NAME" \
    --collection="$coll" \
    --gzip \
    --archive="$OUT_ROOT/${coll}.gz"
done

echo "✅ Backup concluído em: $OUT_ROOT"
