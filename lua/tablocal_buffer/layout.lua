local bufferline = require("tablocal_buffer.bufferline")
local config = require("tablocal_buffer.config")
local model = require("tablocal_buffer.model")
local ops = require("tablocal_buffer.ops")

local M = {}

function M.all_known_buffers()
  local seen = {}
  local bufnrs = {}

  for _, tabpage in ipairs(vim.api.nvim_list_tabpages()) do
    for _, bufnr in ipairs(model.get_tab_buffers_raw(tabpage)) do
      if not seen[bufnr] then
        seen[bufnr] = true
        table.insert(bufnrs, bufnr)
      end
    end
  end

  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if model.is_editor_candidate(bufnr) and not seen[bufnr] then
      seen[bufnr] = true
      table.insert(bufnrs, bufnr)
    end
  end

  table.sort(bufnrs)
  return bufnrs
end

local function overlap_size(group, buffers)
  local set = {}
  for _, bufnr in ipairs(buffers) do
    set[bufnr] = true
  end

  local score = 0
  for _, bufnr in ipairs(group) do
    if set[bufnr] then
      score = score + 1
    end
  end
  return score
end

local function ensure_tabs(count)
  local created_scratch_buffers = {}

  while #vim.api.nvim_list_tabpages() < count do
    vim.cmd.tabnew()
    table.insert(created_scratch_buffers, vim.api.nvim_get_current_buf())
  end

  return created_scratch_buffers
end

local function maybe_delete_created_scratch_buffer(bufnr)
  ops.delete_unmodified_unnamed_buffer(bufnr)
end

local function tabs_by_best_overlap(groups)
  local tabs = vim.api.nvim_list_tabpages()
  local current_state = {}
  for _, tabpage in ipairs(tabs) do
    current_state[tabpage] = model.get_tab_buffers_raw(tabpage)
  end

  local assigned_tabs = {}
  local ordered_tabs = {}
  for _, group in ipairs(groups) do
    local best_tab = nil
    local best_score = -1
    for _, tabpage in ipairs(tabs) do
      if not assigned_tabs[tabpage] then
        local score = overlap_size(group, current_state[tabpage])
        if score > best_score then
          best_tab = tabpage
          best_score = score
        end
      end
    end
    if best_tab then
      assigned_tabs[best_tab] = true
      table.insert(ordered_tabs, best_tab)
    end
  end

  for _, tabpage in ipairs(tabs) do
    if not assigned_tabs[tabpage] then
      table.insert(ordered_tabs, tabpage)
    end
  end

  return ordered_tabs
end

local function reorder_tabs(tabpages)
  local original_tab = vim.api.nvim_get_current_tabpage()

  for target_index, tabpage in ipairs(tabpages) do
    if vim.api.nvim_tabpage_is_valid(tabpage) then
      local current_tabs = vim.api.nvim_list_tabpages()
      local current_index = nil
      for index, existing in ipairs(current_tabs) do
        if existing == tabpage then
          current_index = index
          break
        end
      end

      if current_index and current_index ~= target_index then
        vim.api.nvim_set_current_tabpage(tabpage)
        vim.cmd(("tabmove %d"):format(target_index - 1))
      end
    end
  end

  if vim.api.nvim_tabpage_is_valid(original_tab) then
    vim.api.nvim_set_current_tabpage(original_tab)
  end
end

local function close_extra_tabs(tabpages, keep_count)
  local to_close = {}
  for index = keep_count + 1, #tabpages do
    local tabpage = tabpages[index]
    if vim.api.nvim_tabpage_is_valid(tabpage) then
      table.insert(to_close, tabpage)
    end
  end

  for index = #to_close, 1, -1 do
    local tabpage = to_close[index]
    if vim.api.nvim_tabpage_is_valid(tabpage) then
      vim.api.nvim_set_current_tabpage(tabpage)
      vim.cmd.tabclose()
    end
  end
end

local function maybe_delete_buffer(bufnr)
  ops.delete_unmodified_named_buffer(bufnr)
end

function M.apply(layout)
  local known_buffers = M.all_known_buffers()
  local created_scratch_buffers = ensure_tabs(#layout.groups)
  local tabs = tabs_by_best_overlap(layout.groups)
  local removed = {}

  for _, bufnr in ipairs(known_buffers) do
    removed[bufnr] = true
  end

  for index, group in ipairs(layout.groups) do
    local tabpage = tabs[index]
    model.set_tab_buffers(tabpage, group)
    model.sync_tab_windows(tabpage)
    for _, bufnr in ipairs(group) do
      removed[bufnr] = nil
    end
  end

  for index = #layout.groups + 1, #tabs do
    model.set_tab_buffers(tabs[index], {})
  end

  for _, bufnr in ipairs(layout.unassigned) do
    removed[bufnr] = nil
  end

  reorder_tabs(tabs)
  close_extra_tabs(tabs, #layout.groups)

  if config.get().bufferline.auto_sort_on_apply then
    bufferline.sort_bufferline()
  end

  for bufnr in pairs(removed) do
    maybe_delete_buffer(bufnr)
  end

  for _, bufnr in ipairs(created_scratch_buffers) do
    maybe_delete_created_scratch_buffer(bufnr)
  end
end

return M
