#!/bin/bash
set -euo pipefail

# Подключаем конфигурацию
CONFIG_FILE="$(dirname "$0")/backup.conf"
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    echo "⚠️ Конфигурационный файл $CONFIG_FILE не найден"
    exit 1
fi

LOG_FILE="$LOG_CLEANUP"

# Удаляем incremental старше 7 дней
find "$INCR_DIR" -mindepth 1 -maxdepth 1 -type d -mtime +7 -exec rm -rf {} \; -exec echo "Удалён старый incremental: {}" >> "$LOG_FILE" \;

# Удаляем full старше 14 дней
find "$FULL_DIR" -mindepth 1 -maxdepth 1 -type d -mtime +14 -exec rm -rf {} \; -exec echo "Удалён старый full: {}" >> "$LOG_FILE" \;
