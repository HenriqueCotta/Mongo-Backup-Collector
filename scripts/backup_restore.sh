#!/usr/bin/env bash
# scripts/restore_collector.sh
#
# Restaura um backup gerado pelo backup_collector.sh
# Uso:
#   chmod +x scripts/restore_collector.sh
#   source .env
#   ./scripts/restore_collector.sh <TIMESTAMP> [coleção1 coleção2 ...]

set -euo pipefail

# Carrega .env
ENV_FILE="$(dirname "$0")/../.env"
if [ -f "$ENV_FILE" ]; then
  set -o allexport; source "$ENV_FILE"; set +o allexport
fi

# 1) Requisitos
: "${MONGO_URI:?MONGO_URI não definida em .env}"
: "${DB_NAME:?DB_NAME não definida em .env}"
command -v mongorestore >/dev/null 2>&1 \
  || { echo >&2 "❌ mongorestore não encontrado. Instale o Database Tools."; exit 1; }

# 2) Argumentos
if [ $# -lt 1 ]; then
  echo "Uso: $0 <TIMESTAMP> [coleção1 coleção2 ...]"
  exit 1
fi

TIMESTAMP="$1"
shift  # remove o primeiro argumento do array "$@"

# 3) Local do backup
BASE_BACKUP_DIR="${BACKUP_DIR:-$(pwd)/backups}"
BACKUP_PATH="$BASE_BACKUP_DIR/$TIMESTAMP"

if [ ! -d "$BACKUP_PATH" ]; then
  echo "❌ Pasta de backup não encontrada: $BACKUP_PATH"
  exit 1
fi

# 4) Se não passou coleções, restaura todas as .gz
if [ $# -eq 0 ]; then
  COLLS=( "$(cd "$BACKUP_PATH" && ls *.gz | sed 's/\.gz$//')" )
else
  COLLS=( "$@" )
fi

echo "🔄 Iniciando restauração do backup em: $BACKUP_PATH"
echo "    Banco destino: $DB_NAME"
echo "    Coleções: ${COLLS[*]}"

# 5) Loop de restore
for coll in "${COLLS[@]}"; do
  ARCHIVE="$BACKUP_PATH/${coll}.gz"
  if [ ! -f "$ARCHIVE" ]; then
    echo "⚠️  Arquivo não encontrado: $ARCHIVE (pulando)"
    continue
  fi
  echo "  • Restaurando coleção '$coll'…"
  mongorestore \
    --uri="$MONGO_URI" \
    --db="$DB_NAME" \
    --collection="$coll" \
    --gzip \
    --archive="$ARCHIVE" \
    --numInsertionWorkers 4
done

echo "✅ Restauração concluída."
