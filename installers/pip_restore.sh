#!/bin/bash

SCRIPT_DIR=$(dirname "$0")

# Логирование
LOG_FILE="$SCRIPT_DIR/../OUTPUT/logs/pip_install_$(date +%F_%H-%M-%S).log"
mkdir -p "$(dirname "$LOG_FILE")"
exec > >(tee -a "$LOG_FILE") 2>&1

dry_run=false
for arg in "$@"; do
  if [ "$arg" == "--dry-run" ]; then
    dry_run=true
  fi
done

PIP_FILE="$SCRIPT_DIR/../OUTPUT/reports/pip.md"

# Проверка наличия pip3
if ! command -v pip3 >/dev/null; then
  echo "❗ pip3 не найден. Установи его через: brew install python"
  exit 1
fi

# Проверка наличия файла
if [ ! -f "$PIP_FILE" ]; then
  echo "❗ Файл не найден: $PIP_FILE"
  exit 1
fi

# Аргументы
if [ "$1" == "--install-all" ]; then
  install_all=true
  echo "🐍 Установка всех pip-пакетов..."
elif [[ "$1" == "--"* ]]; then
  pkg_to_install=$(echo "$1" | sed 's/--//')
  install_all=false
  echo "🐍 Установка выбранного пакета: $pkg_to_install"
  [ "$dry_run" = true ] && echo "📝 Режим dry-run активен: установка не будет выполняться"

  if ! grep -q -- "- $pkg_to_install" "$PIP_FILE"; then
    echo "❗ Пакет '$pkg_to_install' не найден в $PIP_FILE"
    echo "🔍 Похожие записи:"
    if ! grep -i -- "- .*${pkg_to_install}" "$PIP_FILE"; then
      echo "  (нет совпадений)"
    fi
    exit 1
  fi
else
  echo "❗ Использование: $0 --install-all [--dry-run] или --<имя_пакета> [--dry-run]"
  exit 1
fi

# Чтение и установка
while read -r line; do
  pkg=$(echo "$line" | sed 's/^- //')
  version=$(echo "$line" | grep -oP '\(\K[^\)]+' || echo "")
  install_string=$pkg
  [ -n "$version" ] && install_string="$pkg==$version"

  if [ "$install_all" = true ] || [ "$pkg" == "$pkg_to_install" ]; then
    if pip3 show "$pkg" >/dev/null 2>&1; then
      if [ "$dry_run" = true ]; then
        echo "📝 [dry-run] Уже установлено: $pkg"
      else
        echo -e "\033[32m✅ Уже установлено: $pkg\033[0m"
      fi
    else
      echo -e "\033[34m📥 Установка: $install_string\033[0m"
      if [ "$dry_run" = true ]; then
        echo "📝 [dry-run] Установил бы: $install_string"
        continue
      fi
      if pip3 install "$install_string"; then
        echo -e "\033[32m✅ Установлено: $install_string\033[0m"
      else
        echo -e "\033[31m❌ Не удалось установить: $install_string\033[0m"
      fi
    fi
  fi

  if [ "$pkg" == "$pkg_to_install" ]; then
    break
  fi
done < <(grep '^- ' "$PIP_FILE")

echo -e "\n\033[32m🎉 Установка pip-пакетов завершена!\033[0m"