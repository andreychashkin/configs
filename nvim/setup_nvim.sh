#!/usr/bin/env bash
# setup_nvim.sh — установка Neovim-конфига и clangd-конфига (Debian/Ubuntu)
# Требования:
# - НЕ создаём .clangd в проектах!
# - Глобальный конфиг clangd читается из ~/.config/clangd/config.yaml
# - Копируем предоставленные файлы init.lua и config.yaml из исходной папки
#
# Использование:
#   bash setup_nvim.sh               # берёт файлы из текущей директории
#   bash setup_nvim.sh --from /path  # берёт файлы из /path

set -euo pipefail

SRC_DIR="$(pwd)"
if [[ "${1:-}" == "--from" ]]; then
  SRC_DIR="${2:-}"
fi

have() { command -v "$1" >/dev/null 2>&1; }

log() { printf "\033[1;32m[•]\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m[!]\033[0m %s\n" "$*"; }
err() { printf "\033[1;31m[x]\033[0m %s\n" "$*"; }

log "Определение менеджера пакетов..."
if have apt-get; then
  PM="apt-get"
  SUDO="sudo"
elif have apt; then
  PM="apt"
  SUDO="sudo"
else
  warn "apt не найден. Пропускаю установку пакетов. Убедись, что зависимости установлены вручную."
  PM=""
  SUDO=""
fi

if [[ -n "$PM" ]]; then
  log "Обновление индексов пакетов..."
  $SUDO $PM update -y

  log "Установка зависимостей..."
  $SUDO $PM install -y \
    neovim git curl ca-certificates tar xz-utils unzip \
    ripgrep fd-find build-essential clangd bear python3 python3-pip

  # На Ubuntu fd называется fdfind — делаем alias, если нужно
  if ! have fd && have fdfind; then
    if [[ ! -f "$HOME/.local/bin/fd" ]]; then
      log "Создаю shim для fd -> fdfind"
      mkdir -p "$HOME/.local/bin"
      printf '#!/usr/bin/env bash\nexec fdfind "$@"\n' > "$HOME/.local/bin/fd"
      chmod +x "$HOME/.local/bin/fd"
      if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
        warn "Добавь $HOME/.local/bin в PATH (например в ~/.bashrc или ~/.zshrc)"
      fi
    fi
  fi
fi

# Пути конфигов
NVIM_DIR="$HOME/.config/nvim"
CLANGD_DIR="$HOME/.config/clangd"
INIT_SRC="$SRC_DIR/init.lua"
CLANGD_SRC_YAML="$SRC_DIR/config.yaml"

log "Подготовка директорий..."
mkdir -p "$NVIM_DIR" "$CLANGD_DIR"

# Копируем init.lua
if [[ -f "$INIT_SRC" ]]; then
  log "Копирую init.lua -> $NVIM_DIR/init.lua"
  install -m 0644 "$INIT_SRC" "$NVIM_DIR/init.lua"
else
  err "Файл init.lua не найден в $SRC_DIR — пропускаю копирование."
fi

# Копируем config.yaml для clangd (глобальный путь XDG: ~/.config/clangd/config.yaml)
if [[ -f "$CLANGD_SRC_YAML" ]]; then
  log "Копирую config.yaml -> $CLANGD_DIR/config.yaml"
  install -m 0644 "$CLANGD_SRC_YAML" "$CLANGD_DIR/config.yaml"
else
  warn "Файл config.yaml не найден в $SRC_DIR — создам минимальный ~/.config/clangd/config.yaml"
  cat > "$CLANGD_DIR/config.yaml" <<'YAML'
CompileFlags:
  Add: [-xc++, -std=c++20, -Wall]
Index:
  Background: Build
Diagnostics:
  UnusedIncludes: Strict
InlayHints:
  Enabled: Yes
  ParameterNames: Yes
  DeducedTypes: Yes
YAML
fi

# НЕ создаём .clangd в корне проекта — удаляем прежний автогенератор, если был
# Ничего править в проектах не нужно. Если где-то лежит .clangd, clangd отдаст приоритет проектному конфигу.

# Быстрые проверки
log "Проверки версий:"
if have nvim; then nvim --version | head -n 1; else warn "nvim не найден"; fi
if have clangd; then clangd --version | head -n 1; else warn "clangd не найден"; fi
if have bear; then bear --version | head -n 1 || true; else warn "bear не найден"; fi

cat <<'MSG'

Готово! Что дальше:
  1) Убедись, что у тебя установлен Nerd Font (например JetBrainsMono Nerd Font) — для значков.
  2) Для DeepSeek установи переменную окружения:
       export DEEPSEEK_API_KEY="..."
  3) Для C/C++ сгенерируй compile_commands.json в корне проекта, например:
       bear -- make -j$(nproc)
     (clangd автоматически найдёт его, конфиг берётся из ~/.config/clangd/config.yaml)

Подсказка: Перезапусти LSP внутри Neovim при необходимости: :LspRestart
MSG

log "Готово."
