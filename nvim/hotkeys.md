# 📝 Шпаргалка горячих клавиш (Neovim + Neovide + DeepSeek)

## 🔑 Основное
- **Лидер (Leader)**: `Space`
- **Выйти из Insert**: `jk`
- **Выйти из Terminal**: `jk`
- **Переключение окон**: `Ctrl + h/j/k/l`
- **Разделить окно**: `Space sv` (вертикально) / `Space sh` (горизонтально) / `Space sc` (закрыть)

## 📂 Файлы и поиск
- `Space e` — **NvimTree**
- `Space ff` — поиск файлов (Telescope)
- `Space fg` — поиск текста (ripgrep через Telescope)
- `Space fb` — список открытых буферов (Telescope)

## 📑 Буферы
- `Shift + l` — следующий буфер
- `Shift + h` — предыдущий буфер
- `Space bb` — закрыть текущий буфер
- `Space bl` — закрыть все слева
- `Space br` — закрыть все справа
- `Space ba` — закрыть все кроме текущего

## 🖥️ Neovide (GUI)
- `Ctrl + =` — увеличить масштаб
- `Ctrl + -` — уменьшить масштаб
- `Ctrl + 0` — сбросить масштаб

## 🧰 Терминалы (ToggleTerm)
- **Быстрые терминалы**:
  - `Space tt` — терминал в плавающем окне
  - `Space th` — терминал в горизонтальном сплите
  - `Space tv` — терминал в вертикальном сплите
  - `Space tl` — терминал в плавающем окне

## 🤖 DeepSeek (через CodeCompanion)
- **Normal Mode Префикс: <leader> (обычно Space)**:
- `Space + ai` - Панель действий AI
- `Space + ac` - Открыть чат AI

- **Visual Mode (выделите код сначала)**:
- `Space + ac` - Чат по выделенному коду
- `Space + ae` - Объяснить код
- `Space + af` - Исправить код
- `Space + ao` - Оптимизировать код
- `Space + ad` - Документировать код

## 🎨 Тема
- Активна: **Gruvbox**

## 🔑 Переменная окружения для DeepSeek
```bash
    export DEEPSEEK_API_KEY="твой_ключ"

