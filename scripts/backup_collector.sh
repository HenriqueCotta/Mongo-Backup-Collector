#!/usr/bin/env bash
# scripts/backup_collector.sh
#
# Gera backups gzip de N coleções e escreve um log em logs/<TIMESTAMP>.log
#
# Uso:
#   chmod +x scripts/backup_collector.sh
#   source .env
#   ./scripts/backup_collector.sh collaborator turnOperation users

set -euo pipefail

# 0) carrega .env
ENV_FILE="$(dirname "$0")/../.env"
if [ -f "$ENV_FILE" ]; then
  set -o allexport; source "$ENV_FILE"; set +o allexport;
fi

# 1) requisitos
: "${MONGO_URI_DUMP:?MONGO_URI_DUMP não definida em .env}"
: "${DB_NAME_DUMP:?DB_NAME_DUMP não definida em .env}"
command -v mongodump >/dev/null 2>&1 \
  || { echo >&2 "❌ mongodump não encontrado. Instale o Database Tools."; exit 1; }

# 2) Argumentos (coleções)
if [ $# -lt 1 ]; then
  echo "Uso: $0 <coleção1> [coleção2 ...]"
  exit 1
fi

# 3) timestamp e diretório
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"

# 4) Diretórios
BASE_BACKUP_DIR="${BACKUP_DIR:-$(pwd)/backups}"
OUT_BACKUP="$BASE_BACKUP_DIR/$TIMESTAMP/$DB_NAME_DUMP"
mkdir -p "$OUT_BACKUP"

LOG_DIR="$(pwd)/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/$TIMESTAMP.log"

# 5) Redireciona todo output para console **e** para $LOG_FILE
exec > >(tee -a "$LOG_FILE") 2>&1

echo "🔄 Iniciando backup em: $OUT_BACKUP"
echo "    Banco:    $DB_NAME_DUMP"
echo "    Coleções: $*"

# 6) Loop de dump
for coll in "$@"; do
  echo "  • Dump da coleção '$coll'…"
  mongodump \
    --uri="$MONGO_URI_DUMP" \
    --db="$DB_NAME_DUMP" \
    --collection="$coll" \
    --gzip \
    --archive="$OUT_BACKUP/${coll}.gz"
done

echo "✅ Backup concluído em: $OUT_BACKUP"
echo "📓 Log gravado em: $LOG_FILE"
