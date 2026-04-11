local config = require("tablocal_buffer.config")
local model = require("tablocal_buffer.model")
local navigation = require("tablocal_buffer.navigation")
local bufferline = require("tablocal_buffer.bufferline")

local M = {}

local augroup = vim.api.nvim_create_augroup("tablocal_buffer", { clear = true })
local command_names = {
  "TabLocalBnext",
  "TabLocalBprevious",
  "TabLocalBufferlineSort",
  "TabLocalMoveToNewTab",
  "TabLocalEditTabBuffers",
  "TabLocalDebugState",
}

local function create_commands()
  for _, name in ipairs(command_names) do
    pcall(vim.api.nvim_del_user_command, name)
  end

  if not config.get().commands.enabled then
    return
  end

  vim.api.nvim_create_user_command("TabLocalBnext", function()
    M.bnext_tablocal()
  end, {})
  vim.api.nvim_create_user_command("TabLocalBprevious", function()
    M.bprevious_tablocal()
  end, {})
  vim.api.nvim_create_user_command("TabLocalBufferlineSort", function()
    M.sort_bufferline()
  end, {})
  vim.api.nvim_create_user_command("TabLocalMoveToNewTab", function()
    M.move_current_window_to_new_tab()
  end, {})
  vim.api.nvim_create_user_command("TabLocalEditTabBuffers", function()
    M.open_editor()
  end, {})
  vim.api.nvim_create_user_command("TabLocalDebugState", function()
    local state = {}
    for index, tabpage in ipairs(vim.api.nvim_list_tabpages()) do
      state[index] = model.get_tab_buffers(tabpage)
    end
    vim.notify(vim.inspect(state))
  end, {})
end

local function clear_keymaps()
  for _, lhs in pairs(M._registered_keymaps or {}) do
    pcall(vim.keymap.del, "n", lhs)
  end
  M._registered_keymaps = {}
end

local function create_keymaps()
  clear_keymaps()
  local keymaps = config.get().keymaps
  local specs = {
    bnext = M.bnext_tablocal,
    bprevious = M.bprevious_tablocal,
    move_to_new_tab = M.move_current_window_to_new_tab,
    open_editor = M.open_editor,
  }
  for key, callback in pairs(specs) do
    local lhs = keymaps[key]
    if lhs and lhs ~= "" then
      vim.keymap.set("n", lhs, callback, { silent = true, desc = "tablocal_buffer:" .. key })
      M._registered_keymaps[key] = lhs
    end
  end
end

local function configure_commandline_abbrev()
  pcall(vim.cmd, "silent! cunabbrev bnext")
  pcall(vim.cmd, "silent! cunabbrev bprevious")
  if not config.get().replace_builtin_bnext then
    return
  end

  vim.cmd([[cnoreabbrev <expr> bnext getcmdtype() ==# ':' && getcmdline() ==# 'bnext' ? 'TabLocalBnext' : 'bnext']])
  vim.cmd([[cnoreabbrev <expr> bprevious getcmdtype() ==# ':' && getcmdline() ==# 'bprevious' ? 'TabLocalBprevious' : 'bprevious']])
end

local function create_autocmds()
  vim.api.nvim_clear_autocmds({ group = augroup })
  vim.api.nvim_create_autocmd("BufWinEnter", {
    group = augroup,
    callback = function(args)
      local tabpage = vim.api.nvim_get_current_tabpage()
      model.add_buffer_to_tab(tabpage, args.buf)
      model.sync_tab_windows(tabpage)
    end,
  })
  vim.api.nvim_create_autocmd("BufWipeout", {
    group = augroup,
    callback = function(args)
      model.remove_buffer_from_all_tabs(args.buf)
      for _, tabpage in ipairs(vim.api.nvim_list_tabpages()) do
        model.sync_tab_windows(tabpage)
      end
    end,
  })
  vim.api.nvim_create_autocmd("TabEnter", {
    group = augroup,
    callback = function()
      model.sync_tab_windows(vim.api.nvim_get_current_tabpage())
    end,
  })
end

function M.setting(opts)
  config.merge(opts)
  create_commands()
  create_keymaps()
  configure_commandline_abbrev()
  create_autocmds()
  model.bootstrap()
end

function M.setup(opts)
  M.setting(opts)
end

function M.bnext_tablocal()
  navigation.bnext_tablocal()
end

function M.bprevious_tablocal()
  navigation.bprevious_tablocal()
end

function M.get_buf_tabnr(bufnr)
  return model.get_buf_tabnr(bufnr)
end

function M.get_global_buffer_order()
  return bufferline.get_global_buffer_order()
end

function M.sort_bufferline()
  return bufferline.sort_bufferline()
end

function M.is_cycle_candidate(bufnr)
  return model.is_cycle_candidate(bufnr)
end

function M.move_current_window_to_new_tab()
  error("move_current_window_to_new_tab() is not implemented yet")
end

function M.open_editor()
  error("open_editor() is not implemented yet")
end

return M
