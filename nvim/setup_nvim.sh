#!/usr/bin/env bash
# install.sh — установка Neovim (>=0.8), Neovide и конфига с DeepSeek (CodeCompanion) + тема Nightfox (из подборки Ben Frain)
set -euo pipefail

have() { command -v "$1" >/dev/null 2>&1; }

echo "[1/9] Проверка apt..."
if ! have apt-get; then
  echo "Это не Debian/Ubuntu. Скрипт рассчитан на Debian/Ubuntu." >&2
  exit 1
fi
export DEBIAN_FRONTEND=noninteractive

echo "[2/9] Установка базовых пакетов..."
sudo apt-get update -y
sudo apt-get install -y \
  git curl ca-certificates tar xz-utils unzip \
  ripgrep fd-find \
  build-essential cmake pkg-config \
  python3-venv python3-pip \
  bear clangd \
  qt6-base-dev qt6-base-dev-tools \
  fonts-jetbrains-mono fontconfig \
  xclip wl-clipboard

# fd в Debian = fdfind
mkdir -p "$HOME/.local/bin"
export PATH="$HOME/.local/bin:/usr/local/bin:$PATH"
if have fdfind && ! have fd; then
  ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"
fi

echo "[3/9] Установка/обновление Neovim (≥ 0.8)..."
need_nvim=1
if have nvim; then
  if nvim --headless +"lua if vim.fn.has('nvim-0.8')==1 then os.exit(0) else os.exit(1) end" +q >/dev/null 2>&1; then
    need_nvim=0
  fi
fi

install_to="/usr/local/bin"
opt_dir="/opt/nvim-linux64"
user_dir="$HOME/.local/nvim-linux64"

if [[ "$need_nvim" -eq 1 ]]; then
  echo "  -> Ставлю Neovim из официальных релизов (tar.gz, при провале — AppImage)…"
  tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' RETURN
  cd "$tmp"
  if curl -fL --retry 3 --retry-all-errors \
      -o nvim-linux64.tar.gz \
      "https://github.com/neovim/neovim-releases/releases/latest/download/nvim-linux64.tar.gz" \
    || curl -fL --retry 3 --retry-all-errors \
      -o nvim-linux64.tar.gz \
      "https://github.com/neovim/neovim/releases/latest/download/nvim-linux64.tar.gz"; then
    if tar -tzf nvim-linux64.tar.gz >/dev/null 2>&1; then
      echo "  -> Архив OK, распаковываю…"
      if sudo -n true 2>/dev/null; then
        sudo rm -rf "$opt_dir"
        sudo tar -C /opt -xzf nvim-linux64.tar.gz
        sudo ln -sfn "$opt_dir/bin/nvim" "$install_to/nvim"
      else
        rm -rf "$user_dir"
        tar -xzf nvim-linux64.tar.gz -C "$HOME/.local"
        ln -sfn "$user_dir/bin/nvim" "$HOME/.local/bin/nvim"
        install_to="$HOME/.local/bin"
      fi
    else
      echo "  -> Tarball повреждён. Пробую AppImage…"
      curl -fL --retry 3 --retry-all-errors \
        -o nvim.appimage \
        "https://github.com/neovim/neovim-releases/releases/latest/download/nvim.appimage" \
      || curl -fL --retry 3 --retry-all-errors \
        -o nvim.appimage \
        "https://github.com/neovim/neovim/releases/latest/download/nvim.appimage"
      chmod +x nvim.appimage
      ./nvim.appimage --appimage-extract
      if sudo -n true 2>/dev/null; then
        sudo rm -rf /opt/nvim-appimage
        sudo mv squashfs-root /opt/nvim-appimage
        sudo ln -sfn /opt/nvim-appimage/AppRun /usr/local/bin/nvim
      else
        rm -rf "$HOME/.local/nvim-appimage"
        mv squashfs-root "$HOME/.local/nvim-appimage"
        ln -sfn "$HOME/.local/nvim-appimage/AppRun" "$HOME/.local/bin/nvim"
        install_to="$HOME/.local/bin"
      fi
    fi
  else
    echo "  -> Не удалось скачать Neovim." >&2
    exit 2
  fi
  cd - >/dev/null
  trap - RETURN
  hash -r
  echo "  -> Установлен: $("$install_to"/nvim --version | head -n1)"
else
  echo "  -> Текущая версия подходит: $(nvim --version | head -n1)"
fi

# приоритет /usr/local/bin и ~/.local/bin
case ":$PATH:" in *":/usr/local/bin:"*) :;; *) export PATH="/usr/local/bin:$PATH";; esac
case ":$PATH:" in *":$HOME/.local/bin:"*) :;; *) export PATH="$HOME/.local/bin:$PATH";; esac

echo "[4/9] Установка Neovide (AppImage)…"
NEOVIDE_APPDIR="/opt/neovide-appimage"
NEOVIDE_LOCALDIR="$HOME/.local/neovide-appimage"
NEOVIM_BIN="$(command -v nvim || true)"

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' RETURN
cd "$tmp"
if curl -fL --retry 3 --retry-all-errors \
     -o neovide.appimage \
     "https://github.com/neovide/neovide/releases/latest/download/neovide.AppImage"; then
  chmod +x neovide.appimage
  ./neovide.appimage --appimage-extract
  if sudo -n true 2>/dev/null; then
    sudo rm -rf "$NEOVIDE_APPDIR"
    sudo mv squashfs-root "$NEOVIDE_APPDIR"
    sudo ln -sfn "$NEOVIDE_APPDIR/AppRun" /usr/local/bin/neovide
    printf '%s\n' '#!/usr/bin/env bash' \
      "exec /usr/local/bin/neovide --neovim-bin \"${NEOVIM_BIN:-/usr/local/bin/nvim}\" \"\$@\"" \
      | sudo tee /usr/local/bin/neovide-nvim >/dev/null
    sudo chmod +x /usr/local/bin/neovide-nvim
  else
    rm -rf "$NEOVIDE_LOCALDIR"
    mv squashfs-root "$NEOVIDE_LOCALDIR"
    ln -sfn "$NEOVIDE_LOCALDIR/AppRun" "$HOME/.local/bin/neovide"
    printf '%s\n' '#!/usr/bin/env bash' \
      "exec \"$HOME/.local/bin/neovide\" --neovim-bin \"${NEOVIM_BIN:-$HOME/.local/bin/nvim}\" \"\$@\"" \
      > "$HOME/.local/bin/neovide-nvim"
    chmod +x "$HOME/.local/bin/neovide-nvim"
  fi
  echo "  -> Neovide установлен: $(neovide --version 2>/dev/null | head -n1 || echo 'ok')"
else
  echo "  -> Не удалось скачать Neovide. Пропускаю установку GUI."
fi
cd - >/dev/null
trap - RETURN

echo "[5/9] Бэкап старого ~/.config/nvim (если есть)…"
NVIM_DIR="$HOME/.config/nvim"
if [ -e "$NVIM_DIR" ]; then
  ts="$(date +%Y%m%d-%H%M%S)"
  mv "$NVIM_DIR" "$NVIM_DIR.backup-$ts"
  echo "  -> Старый конфиг перемещён в: ~/.config/nvim.backup-$ts"
fi
mkdir -p "$NVIM_DIR"

echo "[6/9] Пишу init.lua (lazy.nvim + Telescope/NvimTree/Bufferline/LSP/Treesitter + CodeCompanion DeepSeek + тема Nightfox)…"
cat > "$NVIM_DIR/init.lua" <<'LUA'
-- =========================
-- init.lua — Debian-ready, NVIM 0.8+, DeepSeek через CodeCompanion + тема Nightfox
-- =========================

if vim.fn.has("nvim-0.8") ~= 1 then
  local v = vim.version()
  vim.api.nvim_echo({{
    "Neovim 0.8+ требуется для этой сборки. Текущая: "
      .. v.major .. "." .. v.minor .. "." .. v.patch, "ErrorMsg"}}, true, {})
  return
end

-- Отключаем netrw
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- ---------- БАЗОВОЕ ----------
vim.g.mapleader = " "
vim.o.termguicolors  = true
vim.o.number         = true
vim.o.relativenumber = false
vim.o.wrap           = false
vim.o.mouse          = "a"
vim.o.clipboard      = "unnamedplus"
vim.o.completeopt    = "menu,menuone,noselect"
vim.o.swapfile       = false
vim.o.undofile       = true
vim.lsp.set_log_level("ERROR")

vim.o.timeout     = true
vim.o.timeoutlen  = 300
vim.o.ttimeoutlen = 10

-- Отступ: 4 пробела
vim.o.expandtab   = true
vim.o.shiftwidth  = 4
vim.o.tabstop     = 4
vim.o.softtabstop = 4
vim.o.smartindent = true

-- Makefile — реальные табы
vim.api.nvim_create_autocmd("FileType", {
  pattern = "make",
  callback = function()
    vim.bo.expandtab   = false
    vim.bo.tabstop     = 8
    vim.bo.shiftwidth  = 8
    vim.bo.softtabstop = 0
  end,
})

local map = vim.keymap.set

-- Терминал: jk -> нормал
map("t", "jk", [[<C-\><C-n>]], { desc = "Exit terminal (jk)" })

-- Окна/буферы
map("n", "<C-h>", "<C-w>h"); map("n", "<C-j>", "<C-w>j"); map("n", "<C-k>", "<C-w>k"); map("n", "<C-l>", "<C-w>l")
map("n", "<leader>sv", "<cmd>vsplit<cr>")
map("n", "<leader>sh", "<cmd>split<cr>")
map("n", "<leader>sc", "<cmd>close<cr>")

-- Файловое дерево и поиск
map("n", "<leader>e",  "<cmd>NvimTreeToggle<cr>")
map("n", "<leader>ff", "<cmd>Telescope find_files<cr>")
map("n", "<leader>fg", "<cmd>Telescope live_grep<cr>")
map("n", "<leader>fb", "<cmd>Telescope buffers<cr>")

-- Буферы next/prev
map("n", "<S-l>", "<cmd>bnext<cr>")
map("n", "<S-h>", "<cmd>bprevious<cr>")

-- Закрытие буферов
map("n", "<leader>ba", function()  -- все
  vim.cmd("silent! %bd!")
  vim.cmd("enew")
end, { desc = "Buffers: close ALL" })
map("n", "<leader>bc", "<cmd>bdelete<cr>", { desc = "Buffers: close current" })
map("n", "<leader>bl", "<cmd>BufferLineCloseLeft<cr>",  { desc = "Buffers: close LEFT" })
map("n", "<leader>br", "<cmd>BufferLineCloseRight<cr>", { desc = "Buffers: close RIGHT" })

-- Вставка в cmdline
map("c", "<C-v>", "<C-r>+", { noremap = true, desc = "Paste clipboard into cmdline" })
map({ "i","c" }, "<S-Insert>", "<C-r>+", { noremap = true, desc = "Paste clipboard (Shift+Ins)" })
map("c", "<C-y>", "<C-r>0", { noremap = true, desc = "Paste last yank into cmdline" })

-- Поиск по выделению (//)
map("v", "//", function()
  local save = { vim.fn.getreg("z"), vim.fn.getregtype("z") }
  vim.cmd('normal! "zy')
  local pat = vim.fn.escape(vim.fn.getreg("z"), [[\]])
  vim.fn.setreg("/", "\\V" .. pat)
  vim.cmd("normal! n")
  vim.fn.setreg("z", save[1], save[2])
end, { desc = "Search visual selection" })

-- Neovide
if vim.g.neovide then
  local function pick_guifont(candidates, size)
    local families = {}
    local ok, out = pcall(vim.fn.systemlist, { "fc-list", "--family" })
    if ok and type(out) == "table" then families = out end
    local function has_family(name)
      for _, fam in ipairs(families) do
        if fam:find(name, 1, true) then return true end
      end
      return false
    end
    for _, name in ipairs(candidates) do
      if #families == 0 or has_family(name) then
        vim.o.guifont = string.format("%s:h%d", name, size)
        return
      end
    end
    vim.o.guifont = string.format("Monospace:h%d", size)
  end

  pick_guifont({
    "JetBrainsMono Nerd Font",
    "JetBrainsMono Nerd Font Mono",
    "JetBrainsMonoNL Nerd Font",
    "JetBrains Mono",
    "FiraCode Nerd Font",
    "DejaVuSansMono Nerd Font",
    "DejaVu Sans Mono",
    "Monospace",
  }, 12)

  vim.g.neovide_cursor_animation_length = 0.08
  vim.g.neovide_cursor_trail_size       = 0.7
  vim.g.neovide_cursor_antialiasing     = true
  vim.g.neovide_cursor_vfx_mode         = "railgun"
  vim.g.neovide_floating_blur_amount_x  = 2.0
  vim.g.neovide_floating_blur_amount_y  = 2.0
  vim.g.neovide_hide_mouse_when_typing  = true

  vim.g.neovide_scale_factor = vim.g.neovide_scale_factor or 1.0
  local function change_scale(delta)
    vim.g.neovide_scale_factor = math.max(0.2, (vim.g.neovide_scale_factor or 1.0) + delta)
  end
  map({ "n","v","i" }, "<C-=>", function() change_scale( 0.1) end, { desc = "Neovide ++ масштаб" })
  map({ "n","v","i" }, "<C-->", function() change_scale(-0.1) end, { desc = "Neovide -- масштаб" })
  map({ "n","v","i" }, "<C-0>", function() vim.g.neovide_scale_factor = 1.0 end, { desc = "Neovide масштаб = 1.0" })
end

-- ---------- ХЕЛПЕРЫ ----------
local uv = vim.uv or vim.loop
local function joinpath(...)
  if vim.fs and vim.fs.joinpath then return vim.fs.joinpath(...) end
  local sep = package.config:sub(1,1)
  return table.concat({...}, sep)
end
local function dirname(p)
  if vim.fs and vim.fs.dirname then return vim.fs.dirname(p) end
  return vim.fn.fnamemodify(p, ":h")
end

-- Поиск compile_commands.json вверх по дереву
local function find_ccdb_up(start_dir)
  local dir = start_dir or (vim.fn.getcwd())
  while dir and dir ~= "" and dir ~= "/" do
    local cand = joinpath(dir, "compile_commands.json")
    local st = (uv.fs_stat and uv.fs_stat(cand)) or nil
    if st and st.type == "file" then return cand end
    dir = dirname(dir)
  end
  return nil
end

-- ---------- lazy.nvim ----------
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  vim.fn.system({ "git", "clone", "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git", "--branch=stable", lazypath })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  { "nvim-lua/plenary.nvim" },
  { "MunifTanjim/nui.nvim" }, -- UI зависимость

  -- ТЕМА: Nightfox (рекомендация Ben Frain)
  { "EdenEast/nightfox.nvim",
    priority = 1000,
    config = function()
      require("nightfox").setup({
        options = { transparent = false, terminal_colors = true }
      })
      vim.cmd.colorscheme("nightfox")
    end
  },

  -- Файловый браузер
  { "nvim-tree/nvim-tree.lua", config = function()
      require("nvim-tree").setup({})
    end },

  -- Telescope
  { "nvim-telescope/telescope.nvim", tag = "0.1.8", dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      require("telescope").setup({
        defaults = {
          mappings = {
            i = { ["<C-j>"] = "move_selection_next", ["<C-k>"] = "move_selection_previous" },
            n = { ["q"] = "close" }
          }
        }
      })
    end
  },

  -- Лента буферов
  { "akinsho/bufferline.nvim", version = "*", dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      require("bufferline").setup({})
      vim.keymap.set("n", "<leader>1", "<Cmd>BufferLineGoToBuffer 1<CR>")
      vim.keymap.set("n", "<leader>2", "<Cmd>BufferLineGoToBuffer 2<CR>")
    end
  },

  -- Статус-лайн
  { "nvim-lualine/lualine.nvim", dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function() require("lualine").setup({ options = { theme = "auto" } }) end
  },

  -- Treesitter
  { "nvim-treesitter/nvim-treesitter", build = ":TSUpdate",
    config = function()
      require("nvim-treesitter.configs").setup{
        ensure_installed = { "lua", "vim", "vimdoc", "bash", "cpp", "c", "python", "json", "markdown" },
        highlight = { enable = true },
        indent = { enable = true },
      }
    end
  },

  -- LSP и менеджер серверов
  { "williamboman/mason.nvim", config = function() require("mason").setup() end },
  { "williamboman/mason-lspconfig.nvim",
    dependencies = { "neovim/nvim-lspconfig" },
    config = function()
      local mason_lspconfig = require("mason-lspconfig")
      mason_lspconfig.setup({ ensure_installed = { "clangd", "pyright", "lua_ls" } })
      local lspconfig = require("lspconfig")
      local caps = vim.lsp.protocol.make_client_capabilities()

      lspconfig.clangd.setup({
        capabilities = caps,
        on_new_config = function(new_config, root_dir)
          local cc = find_ccdb_up(root_dir)
          if cc then
            new_config.cmd = new_config.cmd or { "clangd" }
            local dir = dirname(cc)
            table.insert(new_config.cmd, "--compile-commands-dir=" .. dir)
          end
        end
      })
      lspconfig.pyright.setup({ capabilities = caps })
      lspconfig.lua_ls.setup({
        capabilities = caps,
        settings = {
          Lua = {
            diagnostics = { globals = { "vim" } },
            workspace = { checkThirdParty = false },
          }
        }
      })
    end
  },

  -- === CodeCompanion: AI (DeepSeek) ===
  { "olimorris/codecompanion.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
      "MunifTanjim/nui.nvim",
    },
    opts = {
      adapters = {
        http = {
          deepseek = function()
            return require("codecompanion.adapters").extend("deepseek", {
              env = {
                api_key = "DEEPSEEK_API_KEY", -- возьмётся из os.getenv
              },
              schema = {
                model = { default = "deepseek-chat" }, -- поменяй при желании
              },
            })
          end,
        },
      },
      strategies = {
        chat   = { adapter = "deepseek" },
        inline = { adapter = "deepseek" },
      },
    },
    config = function(_, opts)
      require("codecompanion").setup(opts)
      -- Хоткеи под AI
      vim.keymap.set("n", "<leader>ai", "<cmd>CodeCompanion<cr>",      { desc = "AI: панель действий" })
      vim.keymap.set("n", "<leader>ac", "<cmd>CodeCompanionChat<cr>",  { desc = "AI: чат" })
      vim.keymap.set("v", "<leader>ac", ":CodeCompanionChat<cr>",      { desc = "AI: чат по выделению" })
      vim.keymap.set("v", "<leader>ae", ":CodeCompanion /explain<cr>", { desc = "AI: объяснить код" })
      vim.keymap.set("v", "<leader>af", ":CodeCompanion /fix<cr>",     { desc = "AI: исправить код" })
      vim.keymap.set("v", "<leader>ao", ":CodeCompanion /optimize<cr>",{ desc = "AI: оптимизировать" })
      vim.keymap.set("v", "<leader>ad", ":CodeCompanion /docs<cr>",    { desc = "AI: документировать" })
    end
  },
}, {
  checker = { enabled = false },
  change_detection = { enabled = true, notify = false },
})
LUA

echo "[7/9] Первый запуск Neovim для установки плагинов (headless)…"
nvim --headless "+Lazy! sync" +qa || true

echo "[8/9] Создаю desktop-файлы (Neovide)…"
mkdir -p "$HOME/.local/share/applications"
cat > "$HOME/.local/share/applications/neovide.desktop" <<'DESK'
[Desktop Entry]
Name=Neovide (Neovim GUI)
Exec=neovide-nvim %F
Terminal=false
Type=Application
Categories=Utility;TextEditor;Development;
StartupWMClass=neovide
DESK

echo "[9/9] Готово!"
echo
echo "Запуск Neovide:  neovide-nvim"
echo "Запуск Neovim:  nvim"
echo
echo "ВАЖНО: экспортируй ключ API DeepSeek:"
echo '  export DEEPSEEK_API_KEY="твой_ключ_из_console.deepseek.com"'
echo
echo "Тема по умолчанию: Nightfox (можно сменить в init.lua)."

