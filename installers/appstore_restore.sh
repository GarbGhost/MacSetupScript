#!/bin/bash

# Получаем путь к текущей директории, где находится сам скрипт
SCRIPT_DIR=$(dirname "$0")

# Абсолютный путь к файлу appstore.md относительно директории скрипта
APPSTORE_FILE="$SCRIPT_DIR/../OUTPUT/reports/appstore.md"

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
if [ "$1" == "--install-all" ]; then
  install_all=true
  echo "📦 Установка всех приложений из App Store..."
elif [[ "$1" == "--"* ]]; then
  app_to_install=$(echo "$1" | sed 's/--//')
  install_all=false
  echo "📦 Установка приложения: $app_to_install"
else
  echo "❗ Неизвестный аргумент. Используйте --install-all или --<название_приложения>"
  exit 1
fi

# Проверка, есть ли приложение в appstore.md
if ! grep -q "$app_to_install" "$APPSTORE_FILE"; then
  echo "❗ Приложение '$app_to_install' не найдено в $APPSTORE_FILE"
  exit 1
fi

# Чтение и установка приложений
while read -r line; do
  id=$(echo "$line" | awk '{print $2}')
  name=$(echo "$line" | cut -d' ' -f3-)

  # Если мы устанавливаем все, или только одно приложение
  if [ "$install_all" = true ] || [ "$name" == "$app_to_install" ]; then
    if mas list | grep -q "$id"; then
      echo -e "\033[32m✅ Уже установлено: $name ($id)\033[0m"
    else
      echo -e "\033[34m📥 Установка: $name ($id)\033[0m"
      if mas install "$id"; then
        # Поиск пути установки приложения
        app_path=$(find /Applications -type d -name "$name.app" 2>/dev/null | head -n 1)
        if [ -n "$app_path" ]; then
          echo -e "\033[32m✅ Установлено: $name ($id)\nПуть: $app_path\033[0m"
        else
          echo -e "\033[31m❌ Не удалось найти путь установки для: $name ($id)\033[0m"
        fi
      else
        echo -e "\033[31m❌ Не удалось установить: $name ($id)\033[0m"
      fi
    fi
  fi

  # Если мы установили нужное приложение, выходим из цикла
  if [ "$name" == "$app_to_install" ]; then
    break
  fi
done < <(grep '^- ' "$APPSTORE_FILE")

echo -e "\n\033[32m🎉 Установка завершена!\033[0m"