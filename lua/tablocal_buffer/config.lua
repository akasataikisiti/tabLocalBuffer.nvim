local M = {}

local defaults = {
  keymaps = {},
  commands = {
    enabled = true,
  },
  replace_builtin_bnext = false,
  bufferline = {
    enabled = true,
    auto_sort_on_apply = true,
  },
  editor = {
    width_ratio = 0.6,
    height_ratio = 0.6,
    border = "rounded",
  },
  cycle = {
    include_terminal = true,
    require_buflisted = true,
    exclude = {
      unnamed = false,
      filetypes = { "fugitive" },
      buftypes = {},
      name_patterns = { "^fugitive://" },
      predicates = {},
    },
  },
}

local state = vim.deepcopy(defaults)

function M.defaults()
  return vim.deepcopy(defaults)
end

function M.get()
  return state
end

function M.merge(opts)
  state = vim.tbl_deep_extend("force", M.defaults(), opts or {})
  state.keymaps = state.keymaps or {}
  state.commands = state.commands or { enabled = true }
  state.bufferline = vim.tbl_deep_extend("force", defaults.bufferline, state.bufferline or {})
  state.editor = vim.tbl_deep_extend("force", defaults.editor, state.editor or {})
  state.cycle = vim.tbl_deep_extend("force", defaults.cycle, state.cycle or {})
  state.cycle.exclude = vim.tbl_deep_extend("force", defaults.cycle.exclude, state.cycle.exclude or {})
  return state
end

return M
