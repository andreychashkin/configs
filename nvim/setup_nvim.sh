#!/usr/bin/env bash
# install.sh — установка Neovim (>=0.8), Neovide и полного конфига (одним файлом)
set -euo pipefail

have() { command -v "$1" >/dev/null 2>&1; }

echo "[1/9] Проверка apt..."
if ! have apt-get; then
  echo "Это не Debian/Ubuntu. Скрипт рассчитан на Debian." >&2
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
  fonts-jetbrains-mono

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
  tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
  cd "$tmp"

  if curl -fL --retry 3 --retry-all-errors \
      -o nvim-linux64.tar.gz \
      "https://github.com/neovim/neovim-releases/releases/latest/download/nvim-linux64.tar.gz" \
      && tar -tzf nvim-linux64.tar.gz >/dev/null 2>&1; then
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
    echo "  -> Tarball не скачался/повреждён. Пробую AppImage…"
    curl -fL --retry 3 --retry-all-errors \
      -o nvim.appimage \
      "https://github.com/neovim/neovim-releases/releases/latest/download/nvim.appimage"
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
  cd - >/dev/null
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

tmp="$(mktemp -d)"; cd "$tmp"
if curl -fL --retry 3 --retry-all-errors \
     -o neovide.appimage \
     "https://github.com/neovide/neovide/releases/latest/download/neovide.AppImage"; then
  chmod +x neovide.appimage
  ./neovide.appimage --appimage-extract
  if sudo -n true 2>/dev/null; then
    sudo rm -rf "$NEOVIDE_APPDIR"
    sudo mv squashfs-root "$NEOVIDE_APPDIR"
    sudo ln -sfn "$NEOVIDE_APPDIR/AppRun" /usr/local/bin/neovide
    # wrapper, который всегда запускает правильный nvim
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

echo "[5/9] Бэкап старого ~/.config/nvim (если есть)…"
NVIM_DIR="$HOME/.config/nvim"
if [ -e "$NVIM_DIR" ]; then
  ts="$(date +%Y%m%d-%H%M%S)"
  mv "$NVIM_DIR" "$NVIM_DIR.backup-$ts"
  echo "  -> Старый конфиг перемещён в: ~/.config/nvim.backup-$ts"
fi
mkdir -p "$NVIM_DIR"

echo "[6/9] Пишу init.lua (один файл, с Neovide и терминалом)…"
cat > "$NVIM_DIR/init.lua" <<'LUA'
-- =========================
-- init.lua — моноконфиг (Debian-ready, ≥ NVIM 0.8)
-- =========================

-- Мягкая защита: на старых версиях Neovim просто выходим, без падений
if vim.fn.has("nvim-0.8") ~= 1 then
  local v = vim.version()
  vim.api.nvim_echo({{
    "Neovim 0.8+ требуется для этой сборки. Текущая: "
      .. v.major .. "." .. v.minor .. "." .. v.patch, "ErrorMsg"}}, true, {})
  return
end

-- Отключаем netrw (и авто-«дерево» при `nvim .`)
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- ---------- БАЗОВОЕ ----------
vim.g.mapleader = " "
vim.o.termguicolors  = true
vim.o.number         = true   -- абсолютная нумерация
vim.o.relativenumber = false
vim.o.mouse          = "a"
vim.o.clipboard      = "unnamedplus"
vim.o.completeopt    = "menu,menuone,noselect"
vim.o.swapfile       = false
vim.o.undofile       = true
vim.lsp.set_log_level("ERROR") -- меньше мусора в lsp.log

-- Отступ: 4 пробела вместо табов (как раньше)
vim.o.expandtab   = true
vim.o.shiftwidth  = 4
vim.o.tabstop     = 4
vim.o.softtabstop = 4
vim.o.smartindent = true
local map = vim.keymap.set


local map = vim.keymap.set

-- jk: быстрый выход из всех режимов (включая терминал)
map({ "i","v","x","s","o","c" }, "jk", "<Esc>", { desc = "Exit mode (jk)" })
map("t", "jk", [[<C-\><C-n>]], { desc = "Exit terminal mode (jk)" })
map("n", "jk", "<cmd>nohlsearch<cr>", { desc = "jk: снять подсветку поиска" })

-- окна/буферы/поиск
map("n", "<C-h>", "<C-w>h"); map("n", "<C-j>", "<C-w>j"); map("n", "<C-k>", "<C-w>k"); map("n", "<C-l>", "<C-w>l")
map("n", "<leader>sv", "<cmd>vsplit<cr>")
map("n", "<leader>sh", "<cmd>split<cr>")
map("n", "<leader>sc", "<cmd>close<cr>")
map("n", "<S-l>", "<cmd>bnext<cr>")
map("n", "<S-h>", "<cmd>bprevious<cr>")
map("n", "<leader>bd", "<cmd>bdelete<cr>")
map("n", "<leader>e",  "<cmd>NvimTreeToggle<cr>")
map("n", "<leader>ff", "<cmd>Telescope find_files<cr>")
map("n", "<leader>fg", "<cmd>Telescope live_grep<cr>")
map("n", "<leader>fb", "<cmd>Telescope buffers<cr>")

-- === Neovide (GUI): анимация курсора, авто-подбор шрифта, масштаб ===
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
  vim.g.neovide_cursor_vfx_mode         = "railgun"  -- "torpedo"/"pixiedust"/"ripple"/"sonicboom"
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

-- ---------- ХЕЛПЕРЫ (совместимость 0.8/0.9) ----------
local uv = vim.uv or vim.loop
local function joinpath(...)
  if vim.fs and vim.fs.joinpath then return vim.fs.joinpath(...) end
  local sep = package.config:sub(1,1); return table.concat({...}, sep)
end
local function dirname(p)
  if vim.fs and vim.fs.dirname then return vim.fs.dirname(p) end
  return vim.fn.fnamemodify(p, ":h")
end
local function find_ccdb_up(start_dir)
  if vim.fs and vim.fs.find then
    local r = vim.fs.find("compile_commands.json", { upward = true, path = start_dir })
    return r and r[1] or nil
  end
  local dir = start_dir
  while dir and dir ~= "" do
    local candidate = joinpath(dir, "compile_commands.json")
    if vim.fn.filereadable(candidate) == 1 then return candidate end
    local parent = vim.fn.fnamemodify(dir, ":h")
    if parent == dir then break end
    dir = parent
  end
end

-- ---------- LAZY.NVIM ----------
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (uv.fs_stat and uv.fs_stat(lazypath)) then
  vim.fn.system({ "git","clone","--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git","--branch=stable", lazypath })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  -- Тема
  { "ellisonleao/gruvbox.nvim", priority = 1000, config = function()
      require("gruvbox").setup({})
      vim.cmd.colorscheme("gruvbox")
    end
  },

  -- Файловый менеджер (не автооткрывается при `nvim .`)
  { "nvim-tree/nvim-tree.lua",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    cmd = { "NvimTreeToggle", "NvimTreeFocus" },
    config = function()
      require("nvim-tree").setup({
        disable_netrw = true,
        hijack_netrw = true,
        hijack_directories = { enable = false },
        view = { width = 32 },
        renderer = { group_empty = true },
        update_focused_file = { enable = true },
      })
    end
  },

  -- Поиск
  { "nvim-telescope/telescope.nvim",
    cmd = "Telescope",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      require("telescope").setup({
        defaults = { mappings = { i = {
          ["<C-j>"] = "move_selection_next",
          ["<C-k>"] = "move_selection_previous"
        } } }
      })
    end
  },

  -- Терминал (ToggleTerm)
  { "akinsho/toggleterm.nvim",
    version = "*",
    config = function()
      require("toggleterm").setup({
        size = 12,
        open_mapping = nil,
        hide_numbers = true,
        shade_terminals = true,
        shading_factor = 2,
        start_in_insert = true,
        insert_mappings = true,
        persist_size = true,
        direction = "float",
        close_on_exit = true,
        shell = vim.o.shell,
        float_opts = { border = "curved", winblend = 0 },
      })
      map("n", "<leader>tt", "<cmd>ToggleTerm direction=float<cr>",              { desc = "Terminal (float)" })
      map("n", "<leader>th", "<cmd>ToggleTerm size=12 direction=horizontal<cr>", { desc = "Terminal (horizontal)" })
      map("n", "<leader>tv", "<cmd>ToggleTerm size=50 direction=vertical<cr>",   { desc = "Terminal (vertical)" })
    end
  },

  -- LSPCONFIG
  { "neovim/nvim-lspconfig", lazy = false },

  -- Автодополнение
  { "hrsh7th/cmp-nvim-lsp", lazy = false },
  { "hrsh7th/nvim-cmp",
    event = "InsertEnter",
    dependencies = {
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-path",
      "saadparwaiz1/cmp_luasnip",
      { "L3MON4D3/LuaSnip", version = "v2.*" },
    },
    config = function()
      local cmp = require("cmp")
      local ok_snip, luasnip = pcall(require, "luasnip")
      cmp.setup({
        preselect = cmp.PreselectMode.None,
        window = { documentation = false },
        experimental = { ghost_text = false },
        snippet = { expand = function(args) if ok_snip then luasnip.lsp_expand(args.body) end end },
        mapping = cmp.mapping.preset.insert({
          ["<C-Space>"] = cmp.mapping.complete(),
          ["<CR>"] = cmp.mapping(function(fallback)
            if cmp.visible() and cmp.get_selected_entry() then
              cmp.confirm({ behavior = cmp.ConfirmBehavior.Insert, select = false })
            else
              fallback()
            end
          end, { "i","s" }),
          ["<S-CR>"] = cmp.mapping(function(fb) fb() end, { "i","s" }),
          ["<Tab>"]   = cmp.mapping(function(fb)
            if cmp.visible() then cmp.select_next_item()
            elseif ok_snip and luasnip.expand_or_jumpable() then luasnip.expand_or_jump()
            else fb() end
          end, { "i","s" }),
          ["<S-Tab>"] = cmp.mapping(function(fb)
            if cmp.visible() then cmp.select_prev_item()
            elseif ok_snip and luasnip.jumpable(-1) then luasnip.jump(-1)
            else fb() end
          end, { "i","s" }),
        }),
        sources = cmp.config.sources({ { name = "nvim_lsp" }, { name = "path" }, { name = "buffer" } }),
      })
    end
  },

  -- Плавная прокрутка
  { "karb94/neoscroll.nvim", event = "VeryLazy", config = function() require("neoscroll").setup({}) end },

  -- Буферы (полоса вкладок)
  { "akinsho/bufferline.nvim",
    event = "VeryLazy",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      require("bufferline").setup({ options = { diagnostics = "none", separator_style = "slant" } })
      map("n", "<leader>1", "<cmd>BufferLineGoToBuffer 1<cr>")
      map("n", "<leader>2", "<cmd>BufferLineGoToBuffer 2<cr>")
      map("n", "<leader>$", "<cmd>BufferLineGoToBuffer -1<cr>")
    end
  },
}, { checker = { enabled = false } })

-- ---------- LSP ----------
local lspconfig = require("lspconfig")

local function on_attach(_, bufnr)
  local o = { buffer = bufnr }
  map("n", "gd", vim.lsp.buf.definition, o)
  map("n", "gD", vim.lsp.buf.declaration, o)
  map("n", "gi", vim.lsp.buf.implementation, o)
  map("n", "gr", vim.lsp.buf.references, o)
  map("n", "K",  vim.lsp.buf.hover, o)
  map("n", "<leader>rn", vim.lsp.buf.rename, o)
  map("n", "<leader>ca", vim.lsp.buf.code_action, o)
end

local capabilities = vim.lsp.protocol.make_client_capabilities()
pcall(function() capabilities = require("cmp_nvim_lsp").default_capabilities(capabilities) end)

-- ===== утилиты для clangd (ccdb, qmake, .clangd) =====
local function split_words(s) local t = {}; for w in s:gmatch("%S+") do t[#t+1]=w end; return t end
local function is_wrapper(bin)
  bin = vim.fn.fnamemodify(bin, ":t")
  return (bin=="ccache" or bin=="sccache" or bin=="distcc" or bin=="icecc")
end

local function detect_drivers_from_ccdb(ccpath)
  local ok, data = pcall(function()
    local bytes = assert(vim.fn.readfile(ccpath, "b"))
    return vim.json.decode(table.concat(bytes, "\n"))
  end)
  if not ok or type(data) ~= "table" then return {}, nil end
  local set, drivers, build_dir = {}, {}, nil
  for i, obj in ipairs(data) do
    if i == 1 and type(obj.directory) == "string" then build_dir = obj.directory end
    if i > 2000 then break end
    local drv
    if type(obj.arguments) == "table" and #obj.arguments > 0 then
      local a0 = obj.arguments[1]
      drv = (a0 and not is_wrapper(a0)) and a0 or obj.arguments[2]
    elseif type(obj.command) == "string" then
      local p = split_words(obj.command)
      drv = (#p > 1 and is_wrapper(p[1])) and p[2] or p[1]
    end
    if drv and vim.fn.executable(drv) == 1 and not set[drv] then
      set[drv]=true; drivers[#drivers+1]=drv
    end
  end
  return drivers, build_dir
end

local function qmake_headers()
  local bins = { "qmake6", "qmake" }
  for _, b in ipairs(bins) do
    if vim.fn.executable(b) == 1 then
      local out = vim.fn.systemlist({ b, "-query" })
      for _, line in ipairs(out) do
        local k,v = line:match("^([^:]+):%s*(.+)$")
        if k == "QT_INSTALL_HEADERS" and v and vim.fn.isdirectory(v) == 1 then
          return v
        end
      end
    end
  end
  local guesses = { "/usr/include/x86_64-linux-gnu/qt6", "/usr/include/qt6" }
  for _, d in ipairs(guesses) do
    if vim.fn.isdirectory(d) == 1 then return d end
  end
  return nil
end

local function ensure_project_clangd(root_dir, build_dir)
  local cfg = joinpath(root_dir, ".clangd")
  if vim.fn.filereadable(cfg) == 1 then return end
  local qtinc = qmake_headers()
  local add = { "-std=c++20" }
  if build_dir and vim.fn.isdirectory(build_dir) == 1 then table.insert(add, "-I" .. build_dir) end
  if qtinc then
    table.insert(add, "-isystem"); table.insert(add, qtinc)
    for _, m in ipairs({ "QtCore","QtGui","QtWidgets","QtNetwork","QtQml","QtQuick","QtOpenGLWidgets" }) do
      local d = joinpath(qtinc, m)
      if vim.fn.isdirectory(d) == 1 then
        table.insert(add, "-isystem"); table.insert(add, d)
      end
    end
  end
  if #add > 0 then
    vim.fn.writefile({
      "CompileFlags:",
      "  Add: [" .. table.concat(add, ", ") .. "]",
      ""
    }, cfg)
    vim.schedule(function()
      vim.notify("Создан " .. cfg .. " (добавлены include'ы build/Qt) — при необходимости: :LspRestart",
        vim.log.levels.INFO)
    end)
  end
end

-- ===== clangd =====
local util = require("lspconfig.util")
lspconfig.clangd.setup({
  cmd = { "clangd", "--enable-config" }, -- читает ~/.config/clangd/config.yaml и .clangd в проекте
  on_attach = on_attach,
  capabilities = capabilities,
  filetypes = { "c","cpp","objc","objcpp","cuda" },
  root_dir = function(fname)
    local cc = find_ccdb_up(dirname(fname))
    if cc then
      local dir = dirname(cc)
      local real = (uv.fs_realpath and uv.fs_realpath(dir)) or dir
      return real
    end
    return util.find_git_ancestor(fname) or (uv.cwd and uv.cwd()) or vim.loop.cwd()
  end,
  on_new_config = function(new_config, root_dir)
    local cc = joinpath(root_dir, "compile_commands.json")
    if vim.fn.filereadable(cc) == 1 then
      if not vim.tbl_contains(new_config.cmd, "--compile-commands-dir=" .. root_dir) then
        table.insert(new_config.cmd, "--compile-commands-dir=" .. root_dir)
      end
      local drv, build_dir = detect_drivers_from_ccdb(cc)
      if #drv == 0 then
        drv = {
          "/usr/bin/clang-*","/usr/bin/gcc-*","/usr/bin/g++*",
          "/usr/lib/ccache/*","/usr/bin/ccache","/usr/local/bin/*"
        }
      end
      table.insert(new_config.cmd, "--query-driver=" .. table.concat(drv, ","))
      ensure_project_clangd(root_dir, build_dir)
    else
      vim.schedule(function()
        vim.notify("clangd: compile_commands.json не найден в " .. root_dir ..
          " — сгенерируй через bear/compiledb", vim.log.levels.WARN)
      end)
    end
  end,
  single_file_support = true,
})

-- ===== pylsp (venv/.venv; black/ruff из pyproject.toml) =====
lspconfig.pylsp.setup({
  on_attach = on_attach,
  capabilities = capabilities,
  root_dir = util.root_pattern("pyproject.toml", "setup.cfg", "setup.py", "requirements.txt", ".git"),
  settings = {
    pylsp = {
      plugins = {
        black = { enabled = true },
        ruff  = { enabled = true },
        pycodestyle = { enabled = false },
        pyflakes    = { enabled = false },
        mccabe      = { enabled = false },
        jedi        = {},
      },
    },
  },
  on_new_config = function(new_config, root_dir)
    local sep = package.config:sub(1,1)
    local is_win = sep == "\\"
    local function jp(...) return table.concat({ ... }, sep) end
    local venv
    for _, name in ipairs({ ".venv", "venv" }) do
      local base = jp(root_dir, name)
      if vim.fn.isdirectory(base) == 1 then venv = base; break end
    end
    if venv then
      local bin = is_win and "Scripts" or "bin"
      local py    = jp(venv, bin, is_win and "python.exe" or "python")
      local pylsp = jp(venv, bin, is_win and "pylsp.exe" or "pylsp")
      new_config.cmd     = (vim.fn.executable(pylsp) == 1) and { pylsp } or { "pylsp" }
      new_config.cmd_env = {
        VIRTUAL_ENV = venv,
        PATH = jp(venv, bin) .. (is_win and ";" or ":") .. (vim.env.PATH or ""),
      }
      new_config.settings = new_config.settings or {}; new_config.settings.pylsp = new_config.settings.pylsp or {}
      new_config.settings.pylsp.plugins = new_config.settings.pylsp.plugins or {}
      new_config.settings.pylsp.plugins.jedi = new_config.settings.pylsp.plugins.jedi or {}
      new_config.settings.pylsp.plugins.jedi.environment = py
    end
  end,
})

-- Диагностики
vim.diagnostic.config({
  underline = true,
  virtual_text = true,
  signs = true,
  update_in_insert = false,
  severity_sort = true,
})
LUA

echo "[7/9] Синхронизация плагинов (Lazy sync)…"
if nvim --headless +"lua if vim.fn.has('nvim-0.8')==1 then os.exit(0) else os.exit(1) end" +q >/dev/null 2>&1; then
  nvim --headless "+Lazy! sync" +qa || true
else
  echo "  -> Пропускаю Lazy sync: активный nvim < 0.8. Проверь PATH/установку."
fi

echo "[8/9] Создаю HOTKEYS.md…"
cat > "$NVIM_DIR/HOTKEYS.md" <<'MD'
# Горячие клавиши (сборка nvim)

## Быстрый выход (jk)
- `jk` — выход из режимов **Insert / Visual / Select / Operator / Command**.
- `jk` в терминале — выход в Normal.

## Файлы и поиск
- `Space e` — открыть/закрыть дерево (NvimTree).
- `Space ff` — поиск файла по имени.
- `Space fg` — поиск по содержимому (ripgrep).
- `Space fb` — список открытых буферов.

> Примечание: **netrw отключён**, при запуске `nvim .` дерево **не** открывается автоматически.

## Терминал (ToggleTerm)
- `Space tt` — терминал во всплывающем окне (float).
- `Space th` — терминал в горизонтальном сплите (высота 12).
- `Space tv` — терминал в вертикальном сплите (ширина 50).
- Внутри терминала — `jk` для выхода в Normal.

## Окна (splits)
- `Ctrl h/j/k/l` — перейти в окно влево/вниз/вверх/вправо.
- `Space sv` — вертикальный сплит.
- `Space sh` — горизонтальный сплит.
- `Space sc` — закрыть окно.

## Буферы
- `Shift l` — следующий буфер.
- `Shift h` — предыдущий буфер.
- `Space bd` — закрыть текущий буфер.
- `Space 1..9` — перейти к буферу по номеру (в Bufferline).
- `Space $` — перейти к последнему буферу.

## LSP
- `gd` — перейти к определению.
- `gD` — к объявлению.
- `gi` — реализации.
- `gr` — ссылки.
- `K` — hover.
- `Space rn` — переименование.
- `Space ca` — code actions.

## Neovide (GUI)
- Масштаб: `Ctrl+=` / `Ctrl+-` / `Ctrl+0`.
- Запуск GUI:
  - `neovide-nvim` — всегда с правильным бинарём Neovim.
  - или `neovide --neovim-bin /usr/local/bin/nvim`
MD

echo "[9/9] Готово!"
echo "Теперь запусти:"
echo "  which -a nvim            # /usr/local/bin/nvim должен быть первым"
echo "  nvim --version           # 0.8+"
echo "  neovide-nvim             # GUI-клиент с твоим конфигом"

