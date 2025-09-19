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

# Лог с датой
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/backup_${DATE}.log"

echo "=== [$(date)] Начало локального бэкапа ===" | tee -a "$LOG_FILE"

# === Проверка SOURCES ===
if [ ${#SOURCE_DIR[@]} -eq 0 ]; then
    echo "⚠️ SOURCES пустой, нечего бэкапить. Завершаем." | tee -a "$LOG_FILE"
    exit 0
fi

# === Тип бэкапа и DEST_DIR ===
if [ "$DAY_OF_WEEK" -eq 7 ]; then
    BACKUP_TYPE="full"
    DEST_DIR="$FULL_DIR/$DATE"
else
    BACKUP_TYPE="incremental"
    DEST_DIR="$INCR_DIR/$DATE"

    # Находим последний полный бэкап
    LAST_FULL=$(ls -1 "$FULL_DIR" 2>/dev/null | sort | tail -n1 || true)
    if [ -z "$LAST_FULL" ]; then
        echo "⚠️ Нет полного бэкапа — делаем full вместо incremental" | tee -a "$LOG_FILE"
        BACKUP_TYPE="full"
        DEST_DIR="$FULL_DIR/$DATE"
    else
        LINK_DEST="$FULL_DIR/$LAST_FULL"
    fi
fi

mkdir -p "$DEST_DIR"

# === rsync файлов ===
for SRC in "${SOURCE_DIR[@]}"; do
    if [ -d "$SRC" ]; then
        DEST_PATH="$DEST_DIR$SRC"
        mkdir -p "$DEST_PATH"
        if [ -n "${LINK_DEST:-}" ] && [ "$BACKUP_TYPE" = "incremental" ]; then
            rsync -a --delete --link-dest="$LINK_DEST$SRC" "$SRC/" "$DEST_PATH/"
        else
            rsync -a --delete "$SRC/" "$DEST_PATH/"
        fi
    else
        echo "⚠️ Каталога $SRC нет, пропускаем" | tee -a "$LOG_FILE"
    fi
done

# Копируем дампы БД
rsync -a "$DB_BACKUP_DIR/" "$DEST_DIR/db/"

echo "=== [$(date)] Локальный $BACKUP_TYPE бэкап завершен ===" | tee -a "$LOG_FILE"
