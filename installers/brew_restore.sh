#!/bin/bash

SCRIPT_DIR=$(dirname "$0")
BREW_FILE="$SCRIPT_DIR/../OUTPUT/reports/brew.md"

# Аргументы
if [ "$1" == "--install-all" ]; then
  install_all=true
  echo "📦 Установка всех CLI-пакетов из brew.md..."
elif [[ "$1" == "--"* ]]; then
  pkg_to_install=$(echo "$1" | sed 's/--//')
  install_all=false
  echo "📦 Установка выбранного пакета: $pkg_to_install"
  # Проверка, есть ли пакет в списке
  if ! grep -q -- "- $pkg_to_install" "$BREW_FILE"; then
    echo "❗ Пакет '$pkg_to_install' не найден в $BREW_FILE"
    echo "🔍 Похожие записи:"
    if ! grep -i -- "- .*${pkg_to_install}" "$BREW_FILE"; then
      echo "  (нет совпадений)"
    fi
    exit 1
  fi
else
  echo "❗ Использование: $0 --install-all или --<имя_пакета>"
  exit 1
fi

echo "📦 Установка CLI-пакетов Homebrew..."

while read -r line; do
  pkg=$(echo "$line" | sed 's/^- //')
  if [ "$install_all" = true ] || [ "$pkg" == "$pkg_to_install" ]; then
    if brew list --formula | grep -q "^$pkg\$"; then
      echo -e "\033[32m✅ Уже установлено: $pkg\033[0m"
    else
      echo -e "\033[34m📥 Установка: $pkg\033[0m"
      if brew install "$pkg"; then
        echo -e "\033[32m✅ Установлено: $pkg\033[0m"
      else
        echo -e "\033[31m❌ Не удалось установить: $pkg\033[0m"
      fi
    fi
  fi

  if [ "$pkg" == "$pkg_to_install" ]; then
    break
  fi
done < <(grep '^- ' "$BREW_FILE")

echo -e "\n\033[32m🎉 Установка CLI-пакетов завершена!\033[0m"