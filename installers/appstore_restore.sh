#!/bin/bash

# Получаем путь к текущей директории, где находится сам скрипт
SCRIPT_DIR=$(dirname "$0")
APPSTORE_FILE="$SCRIPT_DIR/../OUTPUT/reports/appstore.md"

# Логирование
LOG_FILE="$SCRIPT_DIR/../OUTPUT/logs/appstore_install_$(date +%F_%H-%M-%S).log"
mkdir -p "$(dirname "$LOG_FILE")"
exec > >(tee -a "$LOG_FILE") 2>&1

# Обработка аргументов
dry_run=false
for arg in "$@"; do
  if [ "$arg" == "--dry-run" ]; then
    dry_run=true
  fi
done

# Проверка наличия mas
if ! command -v mas >/dev/null; then
  echo "❗ Утилита 'mas' не найдена. Установи через: brew install mas"
  exit 1
fi

# Проверка наличия файла
if [ ! -f "$APPSTORE_FILE" ]; then
  echo "❗ Файл не найден: $APPSTORE_FILE"
  exit 1
fi

# Проверка аргументов
if [ "$1" == "--install-all" ] || [ "$1" == "--install-all" ]; then
  install_all=true
  echo "📦 Установка всех приложений из App Store..."
elif [[ "$1" == "--"* ]]; then
  app_to_install=$(echo "$1" | sed 's/--//')
  install_all=false
  echo "📦 Установка приложения: $app_to_install"
  [ "$dry_run" = true ] && echo "📝 Режим dry-run активен: установка не будет выполняться"

  if ! grep -q "$app_to_install" "$APPSTORE_FILE"; then
    echo "❗ Приложение '$app_to_install' не найдено в $APPSTORE_FILE"
    exit 1
  fi
else
  echo "❗ Использование: $0 --install-all [--dry-run] или --<название_приложения> [--dry-run]"
  exit 1
fi

# Чтение и установка
while read -r line; do
  id=$(echo "$line" | awk '{print $2}')
  name=$(echo "$line" | cut -d' ' -f3-)

  if [ "$install_all" = true ] || [ "$name" == "$app_to_install" ]; then
    if mas list | grep -q "$id"; then
      if [ "$dry_run" = true ]; then
        echo "📝 [dry-run] Уже установлено: $name ($id)"
      else
        echo -e "\033[32m✅ Уже установлено: $name ($id)\033[0m"
      fi
    else
      if [ "$dry_run" = true ]; then
        echo "📝 [dry-run] Установил бы: $name ($id)"
      else
        echo -e "\033[34m📥 Установка: $name ($id)\033[0m"
        if mas install "$id"; then
          app_path=$(find /Applications -type d -name "$name.app" 2>/dev/null | head -n 1)
          if [ -n "$app_path" ]; then
            echo -e "\033[32m✅ Установлено: $name ($id)\nПуть: $app_path\033[0m"
          else
            echo -e "\033[31m❌ Установлено, но путь не найден: $name ($id)\033[0m"
          fi
        else
          echo -e "\033[31m❌ Не удалось установить: $name ($id)\033[0m"
        fi
      fi
    fi
  fi

  # Прерывание, если устанавливали одно приложение
  if [ "$install_all" = false ] && [ "$name" == "$app_to_install" ]; then
    break
  fi
done < <(grep '^- ' "$APPSTORE_FILE")

echo -e "\n\033[32m🎉 Установка завершена!\033[0m"