#!/usr/bin/env bash
# scripts/backup_restore.sh
#
# Restaura um backup gerado pelo backup_collector.sh
# Uso:
#   chmod +x scripts/backup_restore.sh
#   source .env
#   ./scripts/backup_restore.sh <TIMESTAMP> [coleção1 coleção2 ...]

set -euo pipefail

# Carrega .env
ENV_FILE="$(dirname "$0")/../.env"
if [ -f "$ENV_FILE" ]; then
  set -o allexport; source "$ENV_FILE"; set +o allexport
fi

NUM_INS_WORKERS="${NUM_INS_WORKERS:-4}"

# 1) Requisitos
: "${MONGO_URI_RESTORE:?MONGO_URI_RESTORE não definida em .env}"
: "${DB_NAME_RESTORE:?DB_NAME_RESTORE não definida em .env}"
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
[ -d "$BACKUP_PATH" ] || { echo "❌ Snapshot não encontrado: $BACKUP_PATH"; exit 1; }

# 4) lista de coleções desejadas
if [ $# -eq 0 ]; then
  WANT=()  # vazio = todas
else
  WANT=( "$@" )
fi

echo "🔄 Restaurando snapshot $TIMESTAMP → DB destino: $DB_NAME_RESTORE"
echo "   Coleções filtradas: ${WANT[*]:-(todas)}"

# 4) Se não passou coleções, restaura todas as .gz
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

echo "🔄 Iniciando restauração do backup em: $BACKUP_PATH"
echo "    Banco destino: $DB_NAME_RESTORE"
echo "    Coleções: ${COLLS[*]}"
# 6) para cada DB de origem (subpasta)
for ORIG_DB_DIR in "$BACKUP_PATH"/*/; do
  [ -d "$ORIG_DB_DIR" ] || continue
  ORIG_DB=$(basename "$ORIG_DB_DIR")

  # 7) para cada arquivo .bson.gz naquela subpasta
  for file in "$ORIG_DB_DIR"/*.gz; do
    COLL=$(basename "$file" .gz)

    # se quiser apenas algumas collections, pule as outras
    if [ "${#WANT[@]}" -gt 0 ]; then
      skip=1
      for w in "${WANT[@]}"; do
        [ "$w" = "$COLL" ] && { skip=0; break; }
      done
      [ $skip -eq 1 ] && continue
    fi

    echo "  • Restaurando $ORIG_DB.$COLL → $DB_NAME_RESTORE.$COLL"
    mongorestore \
      --uri="$MONGO_URI_RESTORE" \
      --gzip \
      --archive="$file" \
      --nsFrom="${ORIG_DB}.${COLL}" \
      --nsTo="${DB_NAME_RESTORE}.${COLL}" \
      ----numInsertionWorkersPerCollection="$NUM_INS_WORKERS" 
  done
done

echo "✅ Restauração concluída."