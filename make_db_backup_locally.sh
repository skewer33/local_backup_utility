#!/bin/bash
set -euo pipefail

# === Настройки ===
CONFIG_FILE="$(dirname "$0")/backup.conf"
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    echo "⚠️ Конфигурационный файл $CONFIG_FILE не найден"
    exit 1
fi

DATE=$(date +%Y-%m-%d)
DAY_OF_WEEK=$(date +%u)
LOG_FILE="$LOG_DIR/backup_${DATE}.log"

echo "=== [$(date)] Начало бэкапа БД ===" | tee -a "$LOG_FILE"

# staging-папка
mkdir -p "$DB_BACKUP_DIR"

for db in "${SOURCE_DB[@]}"; do
    CONTAINER="${db%%:*}"
    REST="${db#*:}"
    TYPE="${REST%%:*}"
    DB_USER="${REST#*:}"

    if [[ "$TYPE" == "postgres" ]]; then
        echo "→ Дамп PostgreSQL из контейнера $CONTAINER от пользователя $DB_USER" | tee -a "$LOG_FILE"
        DUMP_FILE="$DB_BACKUP_DIR/${CONTAINER}_postgres.sql.gz"
        if docker exec -t "$CONTAINER" pg_dumpall -U "$DB_USER" | gzip > "$DUMP_FILE"; then
            echo "✔ Дамп PostgreSQL из $CONTAINER успешно создан" | tee -a "$LOG_FILE"
        else
            echo "⚠️ Не удалось сделать дамп PostgreSQL из $CONTAINER" | tee -a "$LOG_FILE"
        fi
    else
        echo "⚠️ Неизвестный тип СУБД: $TYPE" | tee -a "$LOG_FILE"
    fi
done


# === Определяем папку бэкапа (full/incremental) ===
if [ "$DAY_OF_WEEK" -eq 7 ]; then
    BACKUP_TYPE="full"
    DEST_DIR="$FULL_DIR/$DATE"
else
    BACKUP_TYPE="incremental"
    DEST_DIR="$INCR_DIR/$DATE"
fi

mkdir -p "$DEST_DIR/db"

# === Копируем staging → DEST_DIR/db ===
rsync -a "$DB_BACKUP_DIR/" "$DEST_DIR/db/"

echo "=== [$(date)] Бэкап БД завершен (тип: $BACKUP_TYPE) ===" | tee -a "$LOG_FILE"
