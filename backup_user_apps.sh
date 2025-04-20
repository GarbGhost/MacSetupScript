#!/bin/bash
# ⏱ Старт таймера
SECONDS=0

spinner() {
  local pid=$!
  local delay=0.1
  local spinstr='|/-\\'
  while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
    local temp=${spinstr#?}
    printf " [%c]  " "$spinstr"
    spinstr=$temp${spinstr%"$temp"}
    sleep $delay
    printf "\b\b\b\b\b\b"
  done
  printf "    \b\b\b\b"
}

write_visual_chart() {
  mkdir -p "$REPORT_DIR"
  local file="$REPORT_DIR/apps_chart.html"
  
  cat <<EOF > "$file"
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Приложения на MacBook</title>
  <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
  <style>
    body {
      font-family: Arial, sans-serif;
      display: flex;
      flex-direction: column;
      align-items: center;
      padding: 2em;
      margin: 0;
      height: auto;
    }
    canvas {
      max-width: 90%;
      cursor: pointer;
    }
    pre {
      white-space: pre-wrap;
      word-wrap: break-word;
    }
    #details {
      margin-top: 20px;
      max-width: 800px;
      max-height: 60vh;
      overflow-y: auto;
      padding: 1em;
      background: #f5f5f5;
      border-radius: 8px;
    }
    body.dark {
      background-color: #1e1e1e;
      color: #eee;
    }
    body.dark #details {
      background-color: #2c2c2c;
      color: #ccc;
    }
  </style>
</head>
<body>
  <div>
    <h1>Статистика установленных приложений</h1>
    <label for="themeToggle">Тема:</label>
    <select id="themeToggle">
      <option value="light" selected>Светлая</option>
      <option value="dark">Тёмная</option>
    </select>
    <label for="chartType">Тип диаграммы:</label>
    <select id="chartType">
      <option value="pie" selected>Круговая</option>
      <option value="bar">Столбчатая</option>
    </select>
    <canvas id="appChart"></canvas>
    <div id="details"></div>
    <script>
      function countLines(file) {
        return fetch(file)
          .then(response => response.text())
          .then(text => {
            return {
              count: text.split('\\n').filter(line => line.trim().startsWith('-')).length,
              content: text
            };
          });
      }

      const files = {
        '.app (DMG)': 'dmg.md',
        'App Store': 'appstore.md',
        'Homebrew CLI': 'brew.md',
        'Homebrew Casks': 'cask.md',
        'pip': 'pip.md'
      };

      const labels = Object.keys(files);
      const fileList = Object.values(files);
      let appChart = null;

      Promise.all(fileList.map(file => countLines(file)))
        .then(results => {
          const counts = results.map(r => r.count);
          const contents = Object.fromEntries(labels.map((label, i) => [label, results[i].content]));

          const ctx = document.getElementById('appChart').getContext('2d');

          function renderChart(type, labels, counts, contents) {
            if (appChart) appChart.destroy();

            appChart = new Chart(ctx, {
              type: type,
              data: {
                labels: labels,
                datasets: [{
                  label: 'Количество приложений',
                  data: counts,
                  backgroundColor: ['#36A2EB', '#FFCD56', '#FF5733', '#4CAF50', '#FFB6C1'],
                  hoverOffset: 4
                }]
              },
              options: {
                responsive: true,
                plugins: {
                  legend: { position: 'top' },
                  tooltip: {
                    callbacks: {
                      label: function(context) {
                        return \`\${context.label}: \${context.raw} приложений\`;
                      }
                    }
                  }
                },
                onClick: function(evt, elements) {
                  if (!elements.length) return;
                  const label = appChart.data.labels[elements[0].index];
                  const text = contents[label] || '';
                  const detailDiv = document.getElementById('details');
                  const escapedText = text
                    .replace(/&/g, '&amp;')
                    .replace(/</g, '&lt;')
                    .replace(/>/g, '&gt;/');
                  detailDiv.innerHTML = \`<h2>\${label}</h2><pre>\${escapedText}</pre>\`;
                }
              }
            });
          }

          renderChart('pie', labels, counts, contents);

          document.getElementById('chartType').addEventListener('change', function () {
            const selectedType = this.value;
            renderChart(selectedType, labels, counts, contents);
          });

          document.getElementById('themeToggle').addEventListener('change', function () {
            const theme = this.value;
            document.body.classList.toggle('dark', theme === 'dark');
          });
        })
        .catch(err => console.error('Ошибка при загрузке данных:', err));
    </script>
  </div>
</body>
</html>
EOF
  echo -e "\033[32m✅ Генерация диаграммы завершена: $file\033[0m"
}

# Функция для проверки наличия команды
check_command() {
  if ! command -v "$1" >/dev/null; then
    echo -e "\033[33m⚠️  Утилита '$1' не найдена. Установи через: brew install $1\033[0m"
  fi
}

# Функция для проверки всех зависимостей
check_dependencies() {
  check_command brew
  check_command pip3
  check_command mas
}

# # Вызов функции проверки зависимостей
check_dependencies

# 📁 Папка для отчетов
OUTPUT_DIR="./OUTPUT"
REPORT_DIR="$OUTPUT_DIR/reports"
DATA_DIR="$OUTPUT_DIR/data"

write_header() {
  local file="$1"
  local title="$2"
  mkdir -p "$(dirname "$1")"
  echo "# 📦 $title" > "$file"
  echo "_Дата генерации: $(date "+%Y-%m-%d %H:%M:%S")_" >> "$file"
  echo >> "$file"
}

filter_dmg_apps() {
  find /Applications ~/Applications -type d -name "*.app" \
    | grep -v "Contents" \
    | sed 's#.*/##; s#.app##' \
    | grep -vE 'Helper|Renderer|Plugin|GPU|Alerts|Crash|Updater|Autoupdate|LoginLauncher|Browser Helper|Safari|Pages|Numbers|TestFlight|Preview' \
    | sort -u
}

write_dmg() {
  mkdir -p "$REPORT_DIR"
  local file="$REPORT_DIR/dmg.md"
  write_header "$file" "Приложения из .app (DMG / ручная установка)"
  filter_dmg_apps | awk '{print "- " $0}' >> "$file"
}

write_appstore() {
  mkdir -p "$REPORT_DIR"
  local file="$REPORT_DIR/appstore.md"
  write_header "$file" "Приложения из App Store"
  mas list 2>/dev/null | awk '{print "- " $2}' | sort >> "$file"
}

write_brew() {
  mkdir -p "$REPORT_DIR"
  local file="$REPORT_DIR/brew.md"
  write_header "$file" "CLI пакеты Homebrew"
  brew list --formula | sort | awk '{print "- " $1}' >> "$file"
}

write_cask() {
  mkdir -p "$REPORT_DIR"
  local file="$REPORT_DIR/cask.md"
  write_header "$file" "GUI приложения (Casks) Homebrew"
  brew list --cask | sort | awk '{print "- " $1}' >> "$file"
}

write_pip() {
  mkdir -p "$REPORT_DIR"
  local file="$REPORT_DIR/pip.md"
  write_header "$file" "Пакеты, установленные через pip"
  pip3 list --format=columns 2>/dev/null | tail -n +3 | awk '{print "- " $1 " (" $2 ")"}' >> "$file"
}

count_lines() {
  [ -f "$1" ] && grep -c '^-' "$1" || echo 0
}

write_all() {
  mkdir -p "$REPORT_DIR"
  local date_str=$(date '+%Y-%m-%d')
  local file="$REPORT_DIR/installed_apps-$date_str.md"
  write_header "$file" "Установленные приложения на MacBook (Sequoia 15.5)"

  local tasks=(dmg appstore brew cask pip)
  local labels=(".app" "App Store" "Brew CLI" "Cask" "pip")
  local funcs=(write_dmg write_appstore write_brew write_cask write_pip)
  local total=${#tasks[@]}

  for i in "${!tasks[@]}"; do
    local progress=$(( (i+1)*10/total ))
    local bar=$(printf '#%.0s' $(seq 1 $((i+1))))
    local space=$(printf ' %.0s' $(seq 1 $((total-i-1))))
    echo -ne "\r[$bar$space] $((i+1))/$total: ${labels[i]}..."
    ${funcs[i]} > /dev/null
    echo -ne "\r[$bar$space] $((i+1))/$total: ${labels[i]} ✅\n"
  done
  
  echo -ne "\r[##########] 6/6: визуализация..."
  write_visual_chart > /dev/null
  echo -ne "\r[##########] 6/6: Визуализация HTML ✅\n"

  

  # 📤 JSON-отчёт со списками приложений
  mkdir -p "$DATA_DIR"
  local json_file="$DATA_DIR/installed_apps-$date_str.json"

  apps_dmg=$(awk '{gsub(/^- /,""); print}' "$REPORT_DIR/dmg.md" | jq -R . | jq -s .)
  apps_appstore=$(awk '{gsub(/^- /,""); print}' "$REPORT_DIR/appstore.md" | jq -R . | jq -s .)
  apps_brew=$(awk '{gsub(/^- /,""); print}' "$REPORT_DIR/brew.md" | jq -R . | jq -s .)
  apps_cask=$(awk '{gsub(/^- /,""); print}' "$REPORT_DIR/cask.md" | jq -R . | jq -s .)
  apps_pip=$(awk '{gsub(/^- /,""); print}' "$REPORT_DIR/pip.md" | jq -R . | jq -s .)

  cat <<EOF > "$json_file"
  {
    "date": "$(date "+%Y-%m-%d %H:%M:%S")",
    "apps": {
      ".app": $apps_dmg,
      "App Store": $apps_appstore,
      "Homebrew CLI": $apps_brew,
      "Homebrew Casks": $apps_cask,
      "pip": $apps_pip
    }
  }
EOF

  echo -e "\033[32m✅ JSON-файл с приложениями создан: $json_file\033[0m"
}

case "$1" in
  --dmg)
    echo -e "\033[34m📦 Генерация dmg...\033[0m"
    (write_dmg) & spinner
    echo -e "\033[32m✅ dmg готов!\033[0m"
    ;;
  --appstore)
    echo -e "\033[34m🛒 Генерация App Store...\033[0m"
    (write_appstore) & spinner
    echo -e "\033[32m✅ App Store готов!\033[0m"
    ;;
  --brew)
    echo -e "\033[34m🍺 Генерация Homebrew CLI...\033[0m"
    (write_brew) & spinner
    echo -e "\033[32m✅ Homebrew CLI готов!\033[0m"
    ;;
  --cask)
    echo -e "\033[34m🧃 Генерация Homebrew Casks...\033[0m"
    (write_cask) & spinner
    echo -e "\033[32m✅ Homebrew Casks готов!\033[0m"
    ;;
  --pip)
    echo -e "\033[34m🐍 Генерация pip...\033[0m"
    (write_pip) & spinner
    echo -e "\033[32m✅ pip готов!\033[0m"
    ;;
  --all)
    echo -e "\033[34m🔄 Генерация полного отчёта...\033[0m"
    write_all
    echo -e "\033[32m✅ Полный отчёт создан: ./OUTPUT/installed_apps-$(date '+%Y-%m-%d').md\033[0m"
    ;;
  *) echo "❗ Использование: $0 [--dmg | --appstore | --brew | --cask | --pip | --all]" ;;
esac
# ⏱ Показать время выполнения
echo "🎉 Файл(ы) готовы за $SECONDS секунд."