-- =========================
-- init.lua — моноконфиг (Debian-ready, ≥ NVIM 0.8)
-- =========================

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
vim.o.number         = true
vim.o.wrap           = false
vim.o.mouse          = "a"
vim.o.clipboard      = "unnamedplus"
vim.o.completeopt    = "menu,menuone,noselect"
vim.o.swapfile       = false
vim.o.undofile       = true
vim.lsp.set_log_level("ERROR")

vim.o.timeout     = true
vim.o.timeoutlen  = 400
vim.o.ttimeoutlen = 5

-- Отступы: 4 пробела
vim.o.expandtab   = true
vim.o.shiftwidth  = 4
vim.o.tabstop     = 4
vim.o.softtabstop = 4
vim.o.smartindent = true

local map = vim.keymap.set

-- jk: быстрый выход (включая терминал)
map("i", "jk", "<Esc>", { desc = "Exit mode (jk)" })
map("t", "jk", [[<C-\><C-n>]], { desc = "Exit terminal mode (jk)" })

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

-- === Neovide (GUI) ===
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

  -- Масштаб
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
        view = {
          width = 35,                 -- корректный формат width
          adaptive_size = true,
          preserve_window_proportions = true,
        },
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
      local actions = require("telescope.actions")
      require("telescope").setup({
        defaults = {
          mappings = { i = {
            ["<C-j>"] = actions.move_selection_next,
            ["<C-k>"] = actions.move_selection_previous,
          } }
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
              env = { api_key = os.getenv("DEEPSEEK_API_KEY") },
              schema = { model = { default = "deepseek-chat" } },
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

  -- Терминал (ToggleTerm)
  { "akinsho/toggleterm.nvim",
    version = "*",
    config = function()
      require("toggleterm").setup({
        size = 9,
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
      local Terminal = require("toggleterm.terminal").Terminal

      local term1 = Terminal:new({
        cmd = "zsh",
        dir = ".",
        hidden = true,
        direction = "float",
        on_open = function() vim.cmd("startinsert!") end,
      })
      local term2 = Terminal:new({
        cmd = "zsh",
        dir = ".",
        hidden = true,
        direction = "horizontal",
        size = 15,
        on_open = function() vim.cmd("startinsert!") end,
      })
      local term3 = Terminal:new({
        cmd = "zsh",
        dir = ".",
        hidden = true,
        direction = "vertical",
        size = 60,
        on_open = function() vim.cmd("startinsert!") end,
      })
      local term4 = Terminal:new({
        cmd = "zsh",
        dir = ".",
        hidden = true,
        direction = "float",
        on_open = function() vim.cmd("startinsert!") end,
      })

      map("n", "<leader>tt", function() term1:toggle() end, { desc = "Toggle Terminal 1" })
      map("n", "<leader>th", function() term2:toggle() end, { desc = "Toggle Terminal 2" })
      map("n", "<leader>tv", function() term3:toggle() end, { desc = "Toggle Terminal 3" })
      map("n", "<leader>tl", function() term4:toggle() end, { desc = "Toggle Terminal 4" })
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
      map("n", "<S-Tab>", "<cmd>BufferLineCyclePrev<cr>")
      map("n", "<Tab>", "<cmd>BufferLineCycleNext<cr>")
      map("n", "<S-h>", "<cmd>BufferLineCyclePrev<cr>")
      map("n", "<S-l>", "<cmd>BufferLineCycleNext<cr>")
      map("n", "<leader>bb", "<cmd>bd<cr>")
      map("n", "<leader>bl", "<cmd>BufferLineCloseLeft<cr>")
      map("n", "<leader>br", "<cmd>BufferLineCloseRight<cr>")
      map("n", "<leader>ba", "<cmd>BufferLineCloseOthers<cr>")
    end
  },
}, { checker = { enabled = false } })

-- ---------- LSP ----------
local lspconfig = require("lspconfig")
local util = require("lspconfig.util")

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

-- ===== утилиты для clangd =====
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
    if i > 200 then break end
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

-- ===== clangd =====
-- Автоформатирование при сохранении: через автокоманду для текущего буфера
local clangd_fmt_group = vim.api.nvim_create_augroup("ClangdFormatOnSave", { clear = true })

lspconfig.clangd.setup({
  cmd = {
    "clangd",
    "--enable-config",
    "--header-insertion=never",
    "--completion-style=detailed",
    "--function-arg-placeholders=0",
  },
  on_attach = function(client, bufnr)
    -- вызов твоего базового on_attach (если определён выше)
    pcall(on_attach, client, bufnr)

    if client.server_capabilities.documentFormattingProvider then
      vim.api.nvim_clear_autocmds({ group = clangd_fmt_group, buffer = bufnr })
      vim.api.nvim_create_autocmd("BufWritePre", {
        group = clangd_fmt_group,
        buffer = bufnr,
        callback = function()
          -- форматируем ИМЕННО clangd (если вдруг есть другие форматтеры)
          vim.lsp.buf.format({
            async = false,
            timeout_ms = 5000,
            filter = function(c) return c.name == "clangd" end,
          })
        end,
        desc = "Format C/C++ with clangd on save",
      })
    end
  end,
  capabilities = capabilities,
  filetypes = { "c","cpp","objc","objcpp","cuda" },
  handlers = {
    ["textDocument/semanticTokens/full"] = function() return nil end,
  },
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
      local drv = detect_drivers_from_ccdb(cc)
      local query_driver_added = false
      if #drv > 0 then
        for _, driver in ipairs(drv) do
          if vim.fn.executable(driver) == 1 then
            table.insert(new_config.cmd, "--query-driver=" .. driver)
            query_driver_added = true
            break
          end
        end
      end
      if not query_driver_added then
        for _, d in ipairs({ "/usr/bin/g++", "/usr/bin/clang++" }) do
          if vim.fn.executable(d) == 1 then
            table.insert(new_config.cmd, "--query-driver=" .. d)
            break
          end
        end
      end
    else
      vim.schedule(function()
        vim.notify("clangd: compile_commands.json не найден в " .. root_dir ..
          " — сгенерируй через bear/compiledb", vim.log.levels.WARN)
      end)
    end
  end,
  single_file_support = true,
})

-- ===== pylsp =====
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

vim.diagnostic.config({
  underline = true,
  virtual_text = true,
  signs = true,
  update_in_insert = false,
  severity_sort = true,
})
