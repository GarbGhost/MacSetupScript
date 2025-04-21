#!/bin/bash

SCRIPT_DIR=$(dirname "$0")
LOG_FILE="$SCRIPT_DIR/../OUTPUT/logs/cask_install_$(date +%F_%H-%M-%S).log"
mkdir -p "$(dirname "$LOG_FILE")"
exec > >(tee -a "$LOG_FILE") 2>&1

dry_run=false
for arg in "$@"; do
  if [ "$arg" == "--dry-run" ]; then
    dry_run=true
  fi
done

# Путь к файлу с Cask приложениями
CASK_FILE="$SCRIPT_DIR/../OUTPUT/reports/cask.md"

# Аргументы
if [ "$1" == "--install-all" ]; then
  install_all=true
  echo "📦 Установка всех Cask-приложений из cask.md..."
elif [[ "$1" == "--"* ]]; then
  pkg_to_install=$(echo "$1" | sed 's/--//')
  install_all=false
  echo "🧃 Установка выбранного cask-пакета: $pkg_to_install"
  [ "$dry_run" = true ] && echo "📝 Режим dry-run активен: установка не будет выполняться"
  # Проверка, есть ли пакет в списке
  if ! grep -q -- "- $pkg_to_install" "$CASK_FILE"; then
    echo "❗ Пакет '$pkg_to_install' не найден в $CASK_FILE"
    echo "🔍 Похожие записи:"
    if ! grep -i -- "- .*${pkg_to_install}" "$CASK_FILE"; then
      echo "  (нет совпадений)"
    fi
    exit 1
  fi
else
  echo "❗ Использование: $0 --install-all или --<имя_пакета>"
  exit 1
fi

echo "📦 Установка Cask-приложений..."

while read -r line; do
  pkg=$(echo "$line" | sed 's/^- //')
  if [ "$install_all" = true ] || [ "$pkg" == "$pkg_to_install" ]; then
    if brew list --cask | grep -q "^$pkg\$"; then
      if [ "$dry_run" = true ]; then
        echo "📝 [dry-run] Уже установлено: $pkg"
      else
        echo -e "\033[32m✅ Уже установлено: $pkg\033[0m"
      fi
    else
      echo -e "\033[34m📥 Установка: $pkg\033[0m"
      if [ "$dry_run" = true ]; then
        echo "📝 [dry-run] Установил бы: $pkg"
        continue
      fi
      if brew install --cask "$pkg"; then
        echo -e "\033[32m✅ Установлено: $pkg\033[0m"
      else
        echo -e "\033[31m❌ Не удалось установить: $pkg\033[0m"
      fi
    fi
  fi

  if [ "$pkg" == "$pkg_to_install" ]; then
    break
  fi
done < <(grep '^- ' "$CASK_FILE")

echo -e "\n\033[32m🎉 Установка Cask-приложений завершена!\033[0m"