# home/neovim.nix
#
# kickstart.nvim, rebuilt on top of nixpkgs instead of lazy.nvim + Mason.
# Plugins come from pkgs-unstable.vimPlugins, language servers and CLI tools
# from extraPackages, and only the Lua *configuration* lives in initLua.
{pkgs-unstable, ...}: {
  programs.neovim = {
    enable = true;
    package = pkgs-unstable.neovim-unwrapped;
    defaultEditor = true; # Sets Neovim as the default editor via $EDITOR
    viAlias = true; # Creates a 'vi' alias to 'nvim'
    vimAlias = true; # Creates a 'vim' alias to 'nvim'

    withNodeJs = false;
    withPython3 = false;
    withRuby = false;

    # Kickstart leans on Mason to download language servers and formatters.
    # On NixOS we declare them here instead, so they are on Neovim's PATH only.
    extraPackages = with pkgs-unstable; [
      # Telescope's live_grep / find_files backends
      ripgrep
      fd

      # Language servers (mirrors kickstart's `servers` table)
      lua-language-server
      nixd
      basedpyright
      vtsls # TypeScript / JavaScript, wraps tsserver and bundles typescript
      vscode-langservers-extracted # eslint, jsonls, html, cssls

      # Formatters used by conform.nvim
      stylua
      alejandra
      ruff
      prettierd
    ];

    # Plugin packages are separate from configuration
    plugins = with pkgs-unstable.vimPlugins; [
      # Detect tabstop and shiftwidth automatically
      guess-indent-nvim

      # Git signs in the gutter
      gitsigns-nvim

      # Shows pending keybinds
      which-key-nvim

      # Fuzzy finder (files, lsp, etc)
      plenary-nvim
      telescope-nvim
      telescope-fzf-native-nvim # prebuilt by nixpkgs, no `make` step needed
      telescope-ui-select-nvim
      nvim-web-devicons

      # Lua LSP for Neovim config, plugin dev and the vim API
      lazydev-nvim

      # LSP: configs + progress notifications
      nvim-lspconfig
      fidget-nvim

      # Autoformat
      conform-nvim

      # Autocompletion
      blink-cmp
      luasnip
      friendly-snippets

      # Colorscheme
      tokyonight-nvim

      # Highlight TODO, FIXME, NOTE, etc. in comments
      todo-comments-nvim

      # Collection of small modules (mini.ai, mini.surround, mini.statusline)
      mini-nvim

      # Highlight, edit and navigate code.
      # withAllGrammars ships every parser prebuilt, so :TSInstall is never needed.
      nvim-treesitter.withAllGrammars
      nvim-treesitter-textobjects

      # kickstart optional: file explorer (neo-tree needs nui + plenary)
      nui-nvim
      neo-tree-nvim
    ];

    # initLua vs extraConfig: Lua goes here, Vimscript in extraConfig
    initLua = ''
      -- [[ Setting options ]]

      -- disable startup splash
      vim.opt.shortmess:append("I")

      -- Set <space> as the leader key. Must happen before plugins load.
      vim.g.mapleader = " "
      vim.g.maplocalleader = " "

      -- kitty is configured with JetBrainsMono Nerd Font
      vim.g.have_nerd_font = true

      vim.opt.number = true
      vim.opt.relativenumber = true

      -- Don't show the mode, since it's already in the status line
      vim.opt.showmode = false

      -- Sync clipboard between OS and Neovim (scheduled to not slow down startup)
      vim.schedule(function()
        vim.opt.clipboard = "unnamedplus"
      end)

      vim.opt.mouse = "a"
      vim.opt.breakindent = true
      vim.opt.undofile = true

      -- Case-insensitive searching UNLESS \C or one or more capitals in the term
      vim.opt.ignorecase = true
      vim.opt.smartcase = true

      vim.opt.signcolumn = "yes"
      vim.opt.updatetime = 250
      vim.opt.timeoutlen = 300

      vim.opt.splitright = true
      vim.opt.splitbelow = true

      -- Show whitespace characters
      vim.opt.list = true
      vim.opt.listchars = {tab = "» ", trail = "·", nbsp = "␣"}

      -- Live preview of :substitute
      vim.opt.inccommand = "split"

      vim.opt.cursorline = true
      vim.opt.scrolloff = 10
      vim.opt.confirm = true

      -- [[ Basic Keymaps ]]

      vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<CR>")

      -- å sits where the Nordic keyboard puts it, right next to Enter, so
      -- treat it as an extra Escape everywhere Escape is meaningful.
      vim.keymap.set("n", "å", "<cmd>nohlsearch<CR>")
      vim.keymap.set({"i", "v", "s", "c"}, "å", "<Esc>")

      vim.keymap.set("n", "<leader>q", vim.diagnostic.setloclist, {desc = "Open diagnostic [Q]uickfix list"})

      -- Exit terminal mode with <Esc><Esc>
      vim.keymap.set("t", "<Esc><Esc>", "<C-\\><C-n>", {desc = "Exit terminal mode"})

      -- Window navigation
      vim.keymap.set("n", "<C-h>", "<C-w><C-h>", {desc = "Move focus to the left window"})
      vim.keymap.set("n", "<C-l>", "<C-w><C-l>", {desc = "Move focus to the right window"})
      vim.keymap.set("n", "<C-j>", "<C-w><C-j>", {desc = "Move focus to the lower window"})
      vim.keymap.set("n", "<C-k>", "<C-w><C-k>", {desc = "Move focus to the upper window"})

      -- [[ Basic Autocommands ]]

      vim.api.nvim_create_autocmd("TextYankPost", {
        desc = "Highlight when yanking (copying) text",
        group = vim.api.nvim_create_augroup("kickstart-highlight-yank", {clear = true}),
        callback = function()
          vim.hl.on_yank()
        end,
      })

      -- [[ Colorscheme ]]

      require("tokyonight").setup {
        styles = {comments = {italic = false}},
      }
      vim.cmd.colorscheme "tokyonight-night"

      -- [[ guess-indent ]]

      require("guess-indent").setup {}

      -- [[ gitsigns ]]

      require("gitsigns").setup {
        signs = {
          add = {text = "+"},
          change = {text = "~"},
          delete = {text = "_"},
          topdelete = {text = "‾"},
          changedelete = {text = "~"},
        },
      }

      -- [[ which-key ]]

      local wk = require("which-key")
      wk.setup {
        delay = 0,
        icons = {
          mappings = vim.g.have_nerd_font,
        },
      }
      wk.add {
        {"<leader>s", group = "[S]earch"},
        {"<leader>t", group = "[T]oggle"},
        {"<leader>h", group = "Git [H]unk", mode = {"n", "v"}},
        {"<leader>c", group = "[C]ode"},
        {"ä", group = "Git [D]iff"},
        {"ö", group = "[B]uffers"},
      }

      -- [[ Telescope ]]

      local telescope = require("telescope")
      telescope.setup {
        extensions = {
          ["ui-select"] = {
            require("telescope.themes").get_dropdown(),
          },
        },
      }
      pcall(telescope.load_extension, "fzf")
      pcall(telescope.load_extension, "ui-select")

      local builtin = require("telescope.builtin")
      vim.keymap.set("n", "<leader>sh", builtin.help_tags, {desc = "[S]earch [H]elp"})
      vim.keymap.set("n", "<leader>sk", builtin.keymaps, {desc = "[S]earch [K]eymaps"})
      vim.keymap.set("n", "<leader>sf", builtin.find_files, {desc = "[S]earch [F]iles"})
      vim.keymap.set("n", "<leader>ss", builtin.builtin, {desc = "[S]earch [S]elect Telescope"})
      vim.keymap.set("n", "<leader>sw", builtin.grep_string, {desc = "[S]earch current [W]ord"})
      vim.keymap.set("n", "<leader>sg", builtin.live_grep, {desc = "[S]earch by [G]rep"})
      vim.keymap.set("n", "<leader>sd", builtin.diagnostics, {desc = "[S]earch [D]iagnostics"})
      vim.keymap.set("n", "<leader>sr", builtin.resume, {desc = "[S]earch [R]esume"})
      vim.keymap.set("n", "<leader>s.", builtin.oldfiles, {desc = "[S]earch Recent Files"})
      vim.keymap.set("n", "<leader><leader>", builtin.buffers, {desc = "[ ] Find existing buffers"})

      -- Fuzzily search in the current buffer
      vim.keymap.set("n", "<leader>/", function()
        builtin.current_buffer_fuzzy_find(require("telescope.themes").get_dropdown {
          winblend = 10,
          previewer = false,
        })
      end, {desc = "[/] Fuzzily search in current buffer"})

      -- Live grep only in open files
      vim.keymap.set("n", "<leader>s/", function()
        builtin.live_grep {
          grep_open_files = true,
          prompt_title = "Live Grep in Open Files",
        }
      end, {desc = "[S]earch [/] in Open Files"})

      -- Search Neovim config files
      vim.keymap.set("n", "<leader>sn", function()
        builtin.find_files {cwd = vim.fn.stdpath "config"}
      end, {desc = "[S]earch [N]eovim files"})

      -- [[ lazydev ]]

      require("lazydev").setup {
        library = {
          {path = "''${3rd}/luv/library", words = {"vim%.uv"}},
        },
      }

      -- [[ LSP ]]

      require("fidget").setup {}

      vim.api.nvim_create_autocmd("LspAttach", {
        group = vim.api.nvim_create_augroup("kickstart-lsp-attach", {clear = true}),
        callback = function(event)
          local map = function(keys, func, desc, mode)
            mode = mode or "n"
            vim.keymap.set(mode, keys, func, {buffer = event.buf, desc = "LSP: " .. desc})
          end

          map("grn", vim.lsp.buf.rename, "[R]e[n]ame")
          map("gra", vim.lsp.buf.code_action, "[G]oto Code [A]ction", {"n", "x"})
          map("grr", builtin.lsp_references, "[G]oto [R]eferences")
          map("gri", builtin.lsp_implementations, "[G]oto [I]mplementation")
          map("grd", builtin.lsp_definitions, "[G]oto [D]efinition")
          map("grD", vim.lsp.buf.declaration, "[G]oto [D]eclaration")
          map("gO", builtin.lsp_document_symbols, "Open Document Symbols")
          map("gW", builtin.lsp_dynamic_workspace_symbols, "Open Workspace Symbols")
          map("grt", builtin.lsp_type_definitions, "[G]oto [T]ype Definition")

          local client = vim.lsp.get_client_by_id(event.data.client_id)

          -- Highlight references of the word under the cursor
          if client and client:supports_method(vim.lsp.protocol.Methods.textDocument_documentHighlight, event.buf) then
            local highlight_augroup = vim.api.nvim_create_augroup("kickstart-lsp-highlight", {clear = false})
            vim.api.nvim_create_autocmd({"CursorHold", "CursorHoldI"}, {
              buffer = event.buf,
              group = highlight_augroup,
              callback = vim.lsp.buf.document_highlight,
            })
            vim.api.nvim_create_autocmd({"CursorMoved", "CursorMovedI"}, {
              buffer = event.buf,
              group = highlight_augroup,
              callback = vim.lsp.buf.clear_references,
            })
            vim.api.nvim_create_autocmd("LspDetach", {
              group = vim.api.nvim_create_augroup("kickstart-lsp-detach", {clear = true}),
              callback = function(event2)
                vim.lsp.buf.clear_references()
                vim.api.nvim_clear_autocmds {group = "kickstart-lsp-highlight", buffer = event2.buf}
              end,
            })
          end

          -- Toggle inlay hints
          if client and client:supports_method(vim.lsp.protocol.Methods.textDocument_inlayHint, event.buf) then
            map("<leader>th", function()
              vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled {bufnr = event.buf})
            end, "[T]oggle Inlay [H]ints")
          end
        end,
      })

      vim.diagnostic.config {
        severity_sort = true,
        float = {border = "rounded", source = "if_many"},
        underline = {severity = vim.diagnostic.severity.ERROR},
        signs = vim.g.have_nerd_font and {
          text = {
            [vim.diagnostic.severity.ERROR] = "󰅚 ",
            [vim.diagnostic.severity.WARN] = "󰀪 ",
            [vim.diagnostic.severity.INFO] = "󰋽 ",
            [vim.diagnostic.severity.HINT] = "󰌶 ",
          },
        } or {},
        virtual_text = {
          source = "if_many",
          spacing = 2,
          format = function(diagnostic)
            return diagnostic.message
          end,
        },
      }

      -- Broadcast blink.cmp's extra completion capabilities to every server.
      vim.lsp.config("*", {
        capabilities = require("blink.cmp").get_lsp_capabilities({}, false),
      })

      -- Per-server settings. Binaries come from extraPackages above, so there
      -- is no Mason / ensure_installed step.
      vim.lsp.config("lua_ls", {
        settings = {
          Lua = {
            completion = {callSnippet = "Replace"},
          },
        },
      })

      vim.lsp.config("nixd", {
        settings = {
          nixd = {
            formatting = {command = {"alejandra"}},
          },
        },
      })

      -- TypeScript / JavaScript / Node. vtsls wraps tsserver and exposes the
      -- same extras the VS Code extension has (inlay hints, organize imports,
      -- update-imports-on-rename).
      local ts_inlay_hints = {
        enumMemberValues = {enabled = true},
        functionLikeReturnTypes = {enabled = true},
        parameterNames = {enabled = "literals"},
        parameterTypes = {enabled = true},
        propertyDeclarationTypes = {enabled = true},
        variableTypes = {enabled = false},
      }

      vim.lsp.config("vtsls", {
        settings = {
          typescript = {
            inlayHints = ts_inlay_hints,
            updateImportsOnFileMove = {enabled = "always"},
            suggest = {completeFunctionCalls = true},
          },
          javascript = {
            inlayHints = ts_inlay_hints,
            updateImportsOnFileMove = {enabled = "always"},
          },
          vtsls = {
            experimental = {completion = {enableServerSideFuzzyMatch = true}},
          },
        },
      })

      -- eslint only attaches in projects that actually ship an eslint config
      vim.lsp.config("eslint", {
        settings = {workingDirectories = {mode = "auto"}},
      })

      vim.lsp.enable {"lua_ls", "nixd", "basedpyright", "vtsls", "eslint", "jsonls"}

      -- Organize imports (tsserver's source.organizeImports code action)
      vim.keymap.set("n", "<leader>co", function()
        vim.lsp.buf.code_action {
          context = {only = {"source.organizeImports"}, diagnostics = {}},
          apply = true,
        }
      end, {desc = "[C]ode [O]rganize imports"})

      -- [[ conform.nvim (autoformat) ]]

      local conform = require("conform")
      conform.setup {
        notify_on_error = false,
        format_on_save = function(bufnr)
          local disable_filetypes = {c = true, cpp = true}
          if disable_filetypes[vim.bo[bufnr].filetype] then
            return nil
          end
          return {timeout_ms = 500, lsp_format = "fallback"}
        end,
        formatters_by_ft = {
          lua = {"stylua"},
          nix = {"alejandra"},
          python = {"ruff_format"},
          javascript = {"prettierd"},
          javascriptreact = {"prettierd"},
          typescript = {"prettierd"},
          typescriptreact = {"prettierd"},
          json = {"prettierd"},
          jsonc = {"prettierd"},
          css = {"prettierd"},
          html = {"prettierd"},
        },
      }

      vim.keymap.set({"n", "v"}, "<leader>f", function()
        conform.format {async = true, lsp_format = "fallback"}
      end, {desc = "[F]ormat buffer"})

      -- [[ blink.cmp (completion) ]]

      require("luasnip").setup {}
      require("luasnip.loaders.from_vscode").lazy_load()

      vim.g.completion_enabled = true

      require("blink.cmp").setup {
        enabled = function()
          return vim.g.completion_enabled
        end,
        keymap = {preset = "default"},
        appearance = {nerd_font_variant = "mono"},
        completion = {
          -- Auto-highlight the top match so <CR> accepts it immediately,
          -- instead of falling back to a plain newline when nothing is selected.
          list = {selection = {preselect = true}},
          documentation = {auto_show = false, auto_show_delay_ms = 500},
        },
        sources = {
          default = {"lsp", "path", "snippets", "lazydev"},
          providers = {
            lazydev = {module = "lazydev.integrations.blink", score_offset = 100},
          },
        },
        snippets = {preset = "luasnip"},
        -- nixpkgs builds the Rust fuzzy matcher, so require it rather than
        -- silently falling back to the slower Lua implementation.
        fuzzy = {implementation = "prefer_rust"},
        signature = {enabled = true},
      }

      vim.keymap.set("n", "<leader>tc", function()
        vim.g.completion_enabled = not vim.g.completion_enabled
        vim.notify("Completion " .. (vim.g.completion_enabled and "enabled" or "disabled"))
      end, {desc = "[T]oggle [C]ompletion suggestions"})

      -- [[ todo-comments ]]

      require("todo-comments").setup {signs = false}

      -- [[ mini.nvim ]]

      -- Better Around/Inside textobjects: va), yinq, ci'
      require("mini.ai").setup {n_lines = 500}

      -- Add/delete/replace surroundings: saiw), sd', sr)'
      require("mini.surround").setup {}

      -- Simple and easy statusline
      local statusline = require("mini.statusline")
      statusline.setup {use_icons = vim.g.have_nerd_font}
      statusline.section_location = function()
        return "%2l:%-2v"
      end

      -- [[ nvim-treesitter ]]

      -- nixpkgs ships the `main` branch rewrite together with prebuilt parsers,
      -- so there is no `ensure_installed` / :TSInstall. Highlighting and
      -- indentation are enabled per-buffer instead.
      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("kickstart-treesitter", {clear = true}),
        desc = "Enable treesitter highlighting and indentation where a parser exists",
        callback = function(args)
          local lang = vim.treesitter.language.get_lang(vim.bo[args.buf].filetype)
          if lang and pcall(vim.treesitter.start, args.buf, lang) then
            vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
          end
        end,
      })

      -- Ruby and other whitespace-sensitive languages prefer the legacy indenter
      vim.g.skip_ts_indent_rule = {ruby = true, php = true}

      -- [[ Selection expansion (VS Code-style Shift+Alt+Left/Right) ]]

      -- The old nvim-treesitter `incremental_selection` module doesn't exist
      -- on the main branch rewrite used above, so this reimplements it with
      -- core vim.treesitter APIs: walk up the node's parents, pushing each
      -- wider range onto a stack so it can be popped to shrink back down.
      local ts_select_stack = {}

      local function get_visual_range()
        local srow, scol = unpack(vim.api.nvim_buf_get_mark(0, "<"))
        local erow, ecol = unpack(vim.api.nvim_buf_get_mark(0, ">"))
        return srow - 1, scol, erow - 1, ecol + 1 -- end exclusive
      end

      local function set_visual_range(srow, scol, erow, ecol)
        if ecol == 0 then
          erow = erow - 1
          ecol = #(vim.api.nvim_buf_get_lines(0, erow, erow + 1, false)[1] or "")
        else
          ecol = ecol - 1
        end
        vim.api.nvim_buf_set_mark(0, "<", srow + 1, scol, {})
        vim.api.nvim_buf_set_mark(0, ">", erow + 1, ecol, {})
        vim.cmd "normal! gv"
      end

      local function range_eq(a, b)
        return a[1] == b[1] and a[2] == b[2] and a[3] == b[3] and a[4] == b[4]
      end

      local function expand_selection()
        local mode = vim.fn.mode()
        local cur_range
        if mode == "v" or mode == "V" or mode == "\22" then
          cur_range = {get_visual_range()}
        else
          local row, col = unpack(vim.api.nvim_win_get_cursor(0))
          cur_range = {row - 1, col, row - 1, col + 1}
        end

        local ok, node = pcall(vim.treesitter.get_node, {bufnr = 0, pos = {cur_range[1], cur_range[2]}})
        if not ok or not node then
          return
        end

        while node do
          local node_range = {node:range()}
          if not range_eq(node_range, cur_range) then
            table.insert(ts_select_stack, cur_range)
            set_visual_range(unpack(node_range))
            return
          end
          node = node:parent()
        end
      end

      local function shrink_selection()
        local prev = table.remove(ts_select_stack)
        if not prev then
          vim.cmd "normal! \27"
          return
        end
        set_visual_range(unpack(prev))
      end

      vim.keymap.set({"n", "x"}, "<M-S-Right>", expand_selection, {desc = "Expand selection"})
      vim.keymap.set("x", "<M-S-Left>", shrink_selection, {desc = "Shrink selection"})
      vim.keymap.set({"n", "x"}, "<M-S-k>", expand_selection, {desc = "Expand selection"})
      vim.keymap.set("x", "<M-S-j>", shrink_selection, {desc = "Shrink selection"})

      -- [[ Buffers ]]

      local function close_other_buffers()
        local current = vim.api.nvim_get_current_buf()
        for _, buf in ipairs(vim.api.nvim_list_bufs()) do
          if buf ~= current and vim.bo[buf].buflisted then
            vim.cmd("confirm bdelete " .. buf)
          end
        end
      end

      vim.keymap.set({"n", "i", "v"}, "<C-s>", "<cmd>write<CR>", {desc = "Save buffer"})
      vim.keymap.set({"n", "i", "v"}, "<C-M-s>", "<cmd>wa<CR>", {desc = "Save all buffers"})
      vim.keymap.set({"n", "i", "v"}, "<C-q>", "<cmd>confirm bdelete<CR>", {desc = "Close buffer"})
      vim.keymap.set({"n", "i", "v"}, "<C-M-q>", close_other_buffers, {desc = "Close all other buffers"})

      -- ö mirrors the ä git-diff menu: a normal-mode-only prefix, so the key
      -- still types itself in insert and command mode. Same four actions as
      -- the Ctrl binds above, reachable without a chord.
      vim.keymap.set("n", "ös", "<cmd>write<CR>", {desc = "[S]ave buffer"})
      vim.keymap.set("n", "öa", "<cmd>wa<CR>", {desc = "Save [A]ll buffers"})
      vim.keymap.set("n", "öq", "<cmd>confirm bdelete<CR>", {desc = "[Q]uit buffer"})
      vim.keymap.set("n", "öo", close_other_buffers, {desc = "Close [O]ther buffers"})

      -- [[ neo-tree (file explorer) ]]

      require("neo-tree").setup {
        filesystem = {
          window = {
            mappings = {
              ["\\"] = "close_window",
            },
          },
        },
      }
      vim.keymap.set("n", "\\", ":Neotree reveal<CR>", {desc = "NeoTree reveal", silent = true})
      vim.keymap.set("n", "<leader>e", ":Neotree toggle<CR>", {desc = "Toggle file [E]xplorer", silent = true})

      -- [[ Git diff menu (ä) ]]

      -- ä is a plain prefix: Neovim treats any key that only starts longer
      -- mappings as one, and which-key (delay = 0) pops the list up instantly.
      -- Every entry opens a side-by-side diff of the current file against some
      -- revision, using gitsigns' diffthis.
      local gs = require("gitsigns")

      vim.keymap.set("n", "äs", function()
        gs.diffthis()
      end, {desc = "Diff against [S]taged (index)"})

      vim.keymap.set("n", "äc", function()
        gs.diffthis("HEAD")
      end, {desc = "Diff against last [C]ommit (HEAD)"})

      vim.keymap.set("n", "äb", function()
        local out = vim.fn.systemlist {
          "git", "for-each-ref", "--format=%(refname:short)",
          "--sort=-committerdate", "refs/heads", "refs/remotes",
        }
        if vim.v.shell_error ~= 0 or #out == 0 then
          vim.notify("No git branches found", vim.log.levels.WARN)
          return
        end
        vim.ui.select(out, {prompt = "Diff against branch"}, function(branch)
          if branch then
            gs.diffthis(branch)
          end
        end)
      end, {desc = "Diff against [B]ranch head"})

      vim.keymap.set("n", "är", function()
        vim.ui.input({prompt = "Diff against revision: "}, function(rev)
          if rev and rev ~= "" then
            gs.diffthis(rev)
          end
        end)
      end, {desc = "Diff against [R]evision"})

      vim.keymap.set("n", "äq", function()
        for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
          local buf = vim.api.nvim_win_get_buf(win)
          if vim.wo[win].diff and vim.bo[buf].buftype ~= "" then
            vim.api.nvim_win_close(win, true)
          end
        end
        vim.cmd "diffoff!"
      end, {desc = "[Q]uit diff view"})
    '';
  };
}
