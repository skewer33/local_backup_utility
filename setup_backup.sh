#!/bin/bash
set -euo pipefail

# Этот скрипт должен запускаться от sudo
if [ "$EUID" -ne 0 ]; then
    echo "⚠️ Этот скрипт нужно запускать через sudo"
    exit 1
fi

CONFIG_FILE="$(dirname "$0")/backup.conf"
if [ ! -f "$CONFIG_FILE" ]; then
    echo "⚠️ Конфигурационный файл $CONFIG_FILE не найден"
    exit 1
fi

# Подключаем конфиг
source "$CONFIG_FILE"

# Пользователь, от имени которого будут запускаться бэкапы
USER=$(logname)

# Создаём папки, если их нет
for DIR in "$BACKUP_DIR" "${SOURCE_DIR[@]}" "$FULL_DIR" "$INCR_DIR" "$LOG_DIR" "$DB_BACKUP_DIR"; do
    if [ ! -d "$DIR" ]; then
        mkdir -p "$DIR"
        echo "Создана папка $DIR"
    fi
done

# Выдаём права для чтения и копирования (без смены владельца)
for SRC in "${SOURCE_DIR[@]}"; do
    if [ -d "$SRC" ]; then
        chmod -R a+rX "$SRC"
        echo "Даны права на чтение $SRC"
    fi
done

chmod +x make_backup_locally.sh
chmod +x restore_backup_locally.sh
chmod +x cleanup_local_backups.sh

# --- Настраиваем cron ---
if [ -f "example_cron.txt" ]; then
    echo "🔧 Устанавливаю cron-задачи из example_cron.txt"
    crontab -u "$USER" "example_cron.txt"
else
    echo "⚠️ Файл example_cron.txt не найден, cron-задачи не настроены"
fi

echo "✅ Настройка бэкапа завершена"
