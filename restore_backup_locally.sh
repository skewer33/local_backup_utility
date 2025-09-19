#!/bin/bash
set -euo pipefail

# === Проверка прав ===
if [[ $EUID -ne 0 ]]; then
    echo "Скрипт нужно запускать от root (sudo)." >&2
    exit 1
fi

# === Подключаем конфиг ===
CONFIG_FILE="backup.conf"
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Файл конфигурации $CONFIG_FILE не найден" >&2
    exit 1
fi
source "$CONFIG_FILE"  # ожидаются BACKUP_DIR, FULL_DIR, INCR_DIR, LOG_DIR, SOURCE_DIR, SOURCE_DB

# === Дата восстановления ===
TARGET_DATE="${1:-$(date +%Y-%m-%d)}"
if ! [[ "$TARGET_DATE" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    echo "Неверный формат даты. Используется YYYY-MM-DD" >&2
    exit 1
fi

LOG_FILE="$LOG_DIR/restore_$TARGET_DATE.log"
echo "=== [$(date)] Запуск восстановления ===" | tee -a "$LOG_FILE"

# === Проверка SOURCE_DIR и SOURCE_DB ===
if [[ ${#SOURCE_DIR[@]} -eq 0 && ${#SOURCE_DB[@]} -eq 0 ]]; then
    echo "Нет указанных источников для восстановления!" | tee -a "$LOG_FILE"
    exit 1
fi

# === Собираем список всех бэкапов (full + incr) ===
ALL_BACKUPS=$( (ls -1 "$FULL_DIR" 2>/dev/null; ls -1 "$INCR_DIR" 2>/dev/null) | sort )
LAST_RESTORE_DATE=$(echo "$ALL_BACKUPS" | awk -v t="$TARGET_DATE" '$0 <= t' | tail -n1)

if [[ -z "$LAST_RESTORE_DATE" ]]; then
    echo "Нет доступных бэкапов до $TARGET_DATE" | tee -a "$LOG_FILE"
    exit 1
fi

echo "⚠️ Внимание! Вы собираетесь восстановить бэкап за $LAST_RESTORE_DATE."
echo "Восстановление может перезаписать существующие данные!"
read -p "Вы согласны? (y/n): " CONFIRM
[[ "$CONFIRM" != [yY] ]] && { echo "Отмена восстановления." | tee -a "$LOG_FILE"; exit 0; }

# === Определяем staging-папку ===
STAGING="/tmp/restore-$TARGET_DATE"
rm -rf "$STAGING"
mkdir -p "$STAGING"

# === Вспомогательная функция для применения бэкапа ===
apply_backup() {
    local src="$1"
    echo "Применяю бэкап из $src ..." | tee -a "$LOG_FILE"
    rsync -a "$src"/ "$STAGING"/
}

# === Применяем full и инкременты файлов ===
LAST_FULL=$(ls -1 "$FULL_DIR" | sort | tail -n1)
PREV_FULL=$(ls -1 "$FULL_DIR" | sort | tail -n2 | head -n1 || true)

LAST_NUM=$(date -d "$LAST_FULL" +%Y%m%d)
PREV_NUM=$(date -d "$PREV_FULL" +%Y%m%d || echo 0)
TARGET_NUM=$(date -d "$TARGET_DATE" +%Y%m%d)

if (( TARGET_NUM >= LAST_NUM )); then
    # последний full + все инкременты до TARGET_DATE
    apply_backup "$FULL_DIR/$LAST_FULL"
    for inc in $(ls -1 "$INCR_DIR" 2>/dev/null | sort); do
        inc_num=$(date -d "$inc" +%Y%m%d)
        if (( inc_num > LAST_NUM && inc_num <= TARGET_NUM )); then
            apply_backup "$INCR_DIR/$inc"
        fi
    done
elif (( TARGET_NUM < LAST_NUM && TARGET_NUM >= PREV_NUM )); then
    apply_backup "$FULL_DIR/$PREV_FULL"
fi

# === Восстановление файлов ===
for p in "${SOURCE_DIR[@]}"; do
    SRC="$STAGING/$p"
    DST="/$p"
    if [[ -d "$SRC" ]]; then
        echo "Восстанавливаю $DST ..." | tee -a "$LOG_FILE"
        rsync -a --delete "$SRC/" "$DST/"
    else
        echo "Пропуск: в бэкапе нет каталога $p" | tee -a "$LOG_FILE"
    fi
done

# === Восстановление баз данных ===
for db in "${SOURCE_DB[@]}"; do
    CONTAINER="${db%%:*}"
    REST="${db#*:}"
    TYPE="${REST%%:*}"
    DB_USER="${REST#*:}"

    # Ищем дамп
    DUMP_FILE=$(ls "$STAGING/db/${CONTAINER}"*".sql.gz" 2>/dev/null || true)
    if [[ -z "$DUMP_FILE" ]]; then
        echo "Пропуск: дамп для $CONTAINER не найден" | tee -a "$LOG_FILE"
        continue
    fi

    case "$TYPE" in
        postgres)
            echo "Восстанавливаю PostgreSQL в контейнер $CONTAINER от пользователя $DB_USER ..." | tee -a "$LOG_FILE"
            if ! gunzip -c "$DUMP_FILE" | docker exec -i "$CONTAINER" psql -U "$DB_USER" -d postgres; then
                echo "⚠️ Ошибка восстановления $CONTAINER" | tee -a "$LOG_FILE"
            fi
            ;;
        *)
            echo "⚠️ Неизвестный тип СУБД: $TYPE" | tee -a "$LOG_FILE"
            ;;
    esac
done

echo "=== [$(date)] Восстановление завершено ===" | tee -a "$LOG_FILE"
