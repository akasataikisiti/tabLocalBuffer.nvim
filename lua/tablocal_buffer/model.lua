local config = require("tablocal_buffer.config")

local M = {}

M.tabvar_key = "tablocal_buffers"

local function safe_tab_var(tabpage)
  if not vim.api.nvim_tabpage_is_valid(tabpage) then
    return {}
  end
  local ok, value = pcall(vim.api.nvim_tabpage_get_var, tabpage, M.tabvar_key)
  if not ok or type(value) ~= "table" then
    return {}
  end
  return value
end

local function set_tab_buffers(tabpage, bufnrs)
  if not vim.api.nvim_tabpage_is_valid(tabpage) then
    return
  end
  vim.api.nvim_tabpage_set_var(tabpage, M.tabvar_key, bufnrs)
end

local function list_contains(list, value)
  for _, item in ipairs(list) do
    if item == value then
      return true
    end
  end
  return false
end

function M.get_cycle_context(bufnr)
  return {
    bufnr = bufnr,
    buflisted = vim.fn.buflisted(bufnr) == 1,
    buftype = vim.bo[bufnr].buftype,
    filetype = vim.bo[bufnr].filetype,
    bufname = vim.api.nvim_buf_get_name(bufnr),
    modified = vim.bo[bufnr].modified,
  }
end

function M.is_cycle_candidate(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return false
  end

  local opts = config.get().cycle
  local ctx = M.get_cycle_context(bufnr)

  if opts.require_buflisted and not ctx.buflisted then
    return false
  end

  if ctx.buftype ~= "" then
    if not (opts.include_terminal and ctx.buftype == "terminal") then
      return false
    end
  end

  local exclude = opts.exclude
  if vim.list_contains(exclude.filetypes, ctx.filetype) then
    return false
  end

  if vim.list_contains(exclude.buftypes, ctx.buftype) then
    return false
  end

  for _, pattern in ipairs(exclude.name_patterns) do
    if ctx.bufname:match(pattern) then
      return false
    end
  end

  for _, predicate in ipairs(exclude.predicates) do
    if predicate(ctx) then
      return false
    end
  end

  return true
end

function M.is_editor_candidate(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return false
  end

  local opts = config.get().cycle
  local ctx = M.get_cycle_context(bufnr)

  if opts.require_buflisted and not ctx.buflisted then
    return false
  end

  if ctx.buftype ~= "" then
    if not (opts.include_terminal and ctx.buftype == "terminal") then
      return false
    end
  end

  return true
end

function M.normalize_tab_buffers(tabpage)
  local seen = {}
  local normalized = {}
  for _, bufnr in ipairs(safe_tab_var(tabpage)) do
    if not seen[bufnr] and M.is_editor_candidate(bufnr) then
      seen[bufnr] = true
      table.insert(normalized, bufnr)
    end
  end
  set_tab_buffers(tabpage, normalized)
  return normalized
end

function M.get_tab_buffers_raw(tabpage)
  return M.normalize_tab_buffers(tabpage or vim.api.nvim_get_current_tabpage())
end

function M.get_tab_buffers(tabpage)
  local cycle_buffers = {}
  for _, bufnr in ipairs(M.get_tab_buffers_raw(tabpage)) do
    if M.is_cycle_candidate(bufnr) then
      table.insert(cycle_buffers, bufnr)
    end
  end
  return cycle_buffers
end

function M.set_tab_buffers(tabpage, bufnrs)
  set_tab_buffers(tabpage, bufnrs or {})
  return M.get_tab_buffers_raw(tabpage)
end

function M.add_buffer_to_tab(tabpage, bufnr)
  if not M.is_editor_candidate(bufnr) then
    M.remove_buffer_from_tab(tabpage, bufnr)
    return false
  end
  local buffers = M.get_tab_buffers_raw(tabpage)
  if list_contains(buffers, bufnr) then
    return false
  end
  table.insert(buffers, bufnr)
  set_tab_buffers(tabpage, buffers)
  return true
end

function M.remove_buffer_from_tab(tabpage, bufnr)
  local buffers = M.get_tab_buffers_raw(tabpage)
  local next_buffers = {}
  local changed = false
  for _, existing in ipairs(buffers) do
    if existing ~= bufnr then
      table.insert(next_buffers, existing)
    else
      changed = true
    end
  end
  if changed then
    set_tab_buffers(tabpage, next_buffers)
  end
  return changed
end

function M.remove_buffer_from_all_tabs(bufnr)
  for _, tabpage in ipairs(vim.api.nvim_list_tabpages()) do
    M.remove_buffer_from_tab(tabpage, bufnr)
  end
end

function M.find_first_valid_buffer(tabpage)
  for _, bufnr in ipairs(M.get_tab_buffers(tabpage)) do
    if vim.api.nvim_buf_is_valid(bufnr) then
      return bufnr
    end
  end
end

function M.get_buf_tabnr(bufnr)
  for index, tabpage in ipairs(vim.api.nvim_list_tabpages()) do
    if list_contains(M.get_tab_buffers(tabpage), bufnr) then
      return index
    end
  end
end

function M.sync_tab_windows(tabpage)
  if not vim.api.nvim_tabpage_is_valid(tabpage) then
    return
  end
  local buffers = M.get_tab_buffers(tabpage)
  if #buffers == 0 then
    return
  end

  local first = M.find_first_valid_buffer(tabpage)
  if not first then
    return
  end

  local has_managed_window = false
  for _, winid in ipairs(vim.api.nvim_tabpage_list_wins(tabpage)) do
    local bufnr = vim.api.nvim_win_get_buf(winid)
    if M.is_cycle_candidate(bufnr) then
      if list_contains(buffers, bufnr) then
        has_managed_window = true
      else
        vim.api.nvim_win_set_buf(winid, first)
        has_managed_window = true
      end
    end
  end

  if has_managed_window then
    return
  end

  local current = vim.api.nvim_tabpage_get_win(tabpage)
  if current and vim.api.nvim_win_is_valid(current) then
    vim.api.nvim_win_set_buf(current, first)
  end
end

function M.bootstrap()
  for _, tabpage in ipairs(vim.api.nvim_list_tabpages()) do
    set_tab_buffers(tabpage, {})
    for _, winid in ipairs(vim.api.nvim_tabpage_list_wins(tabpage)) do
      M.add_buffer_to_tab(tabpage, vim.api.nvim_win_get_buf(winid))
    end
    M.sync_tab_windows(tabpage)
  end
end

return M
