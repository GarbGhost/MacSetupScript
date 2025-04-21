#!/bin/bash

# Получаем путь к текущей директории, где находится сам скрипт
SCRIPT_DIR=$(dirname "$0")
LOG_FILE="$SCRIPT_DIR/../OUTPUT/logs/dmg_install_$(date +%F_%H-%M-%S).log"
mkdir -p "$(dirname "$LOG_FILE")"
exec > >(tee -a "$LOG_FILE") 2>&1

dry_run=false
for arg in "$@"; do
  if [ "$arg" == "--dry-run" ]; then
    dry_run=true
  fi
done

DMG_FILE="$SCRIPT_DIR/../OUTPUT/reports/dmg.md"
ARCHIVE_DIR="$HOME/Downloads"

if [ ! -f "$DMG_FILE" ]; then
  echo "❗ Файл не найден: $DMG_FILE"
  exit 1
fi

if [ ! -d "$ARCHIVE_DIR" ]; then
  echo "❗ Папка с DMG не найдена: $ARCHIVE_DIR"
  exit 1
fi

if [ "$1" == "--install-all" ]; then
  install_all=true
  echo "📦 Установка всех приложений из DMG..."
elif [[ "$1" == "--"* ]]; then
  app_to_install=$(echo "$1" | sed 's/--//')
  install_all=false
  echo "📦 Установка приложения: $app_to_install"
  if ! grep -q -- "- $app_to_install" "$DMG_FILE"; then
    echo "❗ Приложение '$app_to_install' не найдено в $DMG_FILE"
    echo "🔍 Похожие записи:"
    if ! grep -i -- "- .*${app_to_install}" "$DMG_FILE"; then
      echo "  (нет совпадений)"
    fi
    exit 1
  fi
else
  echo "❗ Использование: $0 --install-all [--dry-run] или --<имя_приложения> [--dry-run]"
  exit 1
fi

restore_app_from_dmg() {
  local app="$1"
  local dmg_path="$ARCHIVE_DIR/$app.dmg"

  if [ ! -f "$dmg_path" ]; then
    echo -e "\033[33m⚠️  Пропущено: $app — файл $app.dmg не найден\033[0m"
    return
  fi

  echo -e "\033[34m📥 Установка: $app из $app.dmg\033[0m"

  mount_output=$(hdiutil attach "$dmg_path" -nobrowse -quiet)
  mount_point=$(echo "$mount_output" | grep -o '/Volumes/[^"]*' | head -n 1)

  if [ -z "$mount_point" ]; then
    echo -e "\033[31m❌ Не удалось смонтировать: $app.dmg\033[0m"
    return
  fi

  app_path=$(find "$mount_point" -maxdepth 1 -name "*.app" -print -quit)
  if [ -z "$app_path" ]; then
    echo -e "\033[31m❌ Не найден .app внутри: $app.dmg\033[0m"
    hdiutil detach "$mount_point" -quiet
    return
  fi

  if [ "$dry_run" = true ]; then
    echo "📝 [dry-run] Установил бы: $app из $dmg_path"
    return
  fi

  cp -R "$app_path" /Applications/
  hdiutil detach "$mount_point" -quiet

  echo -e "\033[32m✅ Установлено: $app → /Applications/$(basename "$app_path")\033[0m"
}

while read -r line; do
  app=$(echo "$line" | sed 's/^- //')
  if [ "$install_all" = true ] || [ "$app" == "$app_to_install" ]; then
    if [ -d "/Applications/$app.app" ]; then
      if [ "$dry_run" = true ]; then
        echo "📝 [dry-run] Уже установлено: $app"
      else
        echo -e "\033[32m✅ Уже установлено: $app\033[0m"
      fi
      continue
    else
      restore_app_from_dmg "$app"
    fi
  fi

  if [ "$app" == "$app_to_install" ]; then
    break
  fi
done < <(grep '^- ' "$DMG_FILE")

echo -e "\n\033[32m🎉 Установка приложений из DMG завершена!\033[0m"