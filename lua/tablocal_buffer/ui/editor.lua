local bufferline = require("tablocal_buffer.bufferline")
local config = require("tablocal_buffer.config")
local labels = require("tablocal_buffer.labels")
local model = require("tablocal_buffer.model")

local M = {}

local function quoted(label)
  return ("%q"):format(label)
end

local function all_known_buffers()
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

local function encode_state()
  local all_buffers = all_known_buffers()
  local label_map, reverse = labels.build_label_map(all_buffers)
  local assigned = {}
  local groups = {}

  for _, tabpage in ipairs(vim.api.nvim_list_tabpages()) do
    local group = {}
    for _, bufnr in ipairs(model.get_tab_buffers_raw(tabpage)) do
      assigned[bufnr] = true
      table.insert(group, label_map[bufnr])
    end
    table.insert(groups, group)
  end

  local unassigned = {}
  for _, bufnr in ipairs(all_buffers) do
    if not assigned[bufnr] then
      table.insert(unassigned, label_map[bufnr])
    end
  end

  return {
    payload = {
      groups = groups,
      unassigned = unassigned,
    },
    reverse = reverse,
    known_labels = vim.tbl_keys(reverse),
  }
end

local function validate_group(group, seen, reverse)
  if type(group) ~= "table" then
    return nil, "each group must be a table"
  end

  local resolved = {}
  for _, label in ipairs(group) do
    if type(label) ~= "string" then
      return nil, "group entries must be strings"
    end
    if seen[label] then
      return nil, ("duplicate label: %s"):format(label)
    end
    if not reverse[label] then
      return nil, ("unknown label: %s"):format(label)
    end
    seen[label] = true
    table.insert(resolved, reverse[label])
  end
  return resolved
end

function M.parse_editor_text(lines, reverse)
  local chunk = table.concat(lines, "\n")
  local fn, err = loadstring(chunk)
  if not fn then
    return nil, err
  end

  local ok, payload = pcall(fn)
  if not ok then
    return nil, payload
  end

  if type(payload) ~= "table" then
    return nil, "top-level value must be a table"
  end

  local groups = payload.groups or payload
  if type(groups) ~= "table" then
    return nil, "groups must be a table"
  end

  local seen = {}
  local resolved_groups = {}
  for _, group in ipairs(groups) do
    local resolved, group_err = validate_group(group, seen, reverse)
    if not resolved then
      return nil, group_err
    end
    table.insert(resolved_groups, resolved)
  end

  local resolved_unassigned = {}
  local unassigned = payload.unassigned or {}
  if type(unassigned) ~= "table" then
    return nil, "unassigned must be a table"
  end
  for _, label in ipairs(unassigned) do
    if type(label) ~= "string" then
      return nil, "unassigned entries must be strings"
    end
    if seen[label] then
      return nil, ("duplicate label: %s"):format(label)
    end
    if not reverse[label] then
      return nil, ("unknown label: %s"):format(label)
    end
    seen[label] = true
    table.insert(resolved_unassigned, reverse[label])
  end

  return {
    groups = resolved_groups,
    unassigned = resolved_unassigned,
  }
end

function M.render_editor_text(payload)
  local lines = {
    "-- Edit tab-local buffers and write/quit to apply. Press q to close without saving. Duplicate basenames keep the shown :<bufnr> suffix.",
    "return {",
    "  groups = {",
  }

  for _, group in ipairs(payload.groups or {}) do
    table.insert(lines, "    {")
    for _, label in ipairs(group) do
      table.insert(lines, ("      %s,"):format(quoted(label)))
    end
    table.insert(lines, "    },")
  end

  table.insert(lines, "  },")
  table.insert(lines, "")
  table.insert(lines, "  -- Unassigned buffers (not in any tab). Move labels above or leave here to keep unassigned.")
  table.insert(lines, "  unassigned = {")

  if payload.unassigned and #payload.unassigned > 0 then
    for _, label in ipairs(payload.unassigned) do
      table.insert(lines, ("    %s,"):format(quoted(label)))
    end
  else
    table.insert(lines, "    -- (none)")
  end

  table.insert(lines, "  },")
  table.insert(lines, "}")
  return lines
end

local function find_groups_block(lines)
  local groups_indent = nil
  for index, line in ipairs(lines) do
    if not groups_indent then
      groups_indent = line:match("^(%s*)groups%s*=%s*{%s*$")
    elseif line:match("^" .. groups_indent .. "},%s*$") then
      return index, groups_indent
    end
  end
end

function M.insert_empty_group(bufnr, winid)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local close_line, groups_indent = find_groups_block(lines)
  if not close_line then
    vim.notify("tablocal_buffer: could not find groups block", vim.log.levels.ERROR)
    return false
  end

  local group_indent = groups_indent .. "  "
  local entry_indent = group_indent .. "  "
  local inserted = {
    group_indent .. "{",
    entry_indent,
    group_indent .. "},",
  }
  vim.api.nvim_buf_set_lines(bufnr, close_line - 1, close_line - 1, false, inserted)

  if winid and vim.api.nvim_win_is_valid(winid) then
    vim.api.nvim_win_set_cursor(winid, { close_line + 1, #entry_indent })
  end
  return true
end

function M.delete_group_at_cursor(bufnr, winid)
  if not winid or not vim.api.nvim_win_is_valid(winid) then
    return false
  end

  local cursor_line = vim.api.nvim_win_get_cursor(winid)[1]
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local close_line, groups_indent = find_groups_block(lines)
  if not close_line then
    vim.notify("tablocal_buffer: could not find groups block", vim.log.levels.ERROR)
    return false
  end

  local group_indent = groups_indent .. "  "
  local group_start = nil
  for index = 1, close_line - 1 do
    local line = lines[index]
    if line:match("^" .. group_indent .. "{%s*$") then
      group_start = index
    elseif group_start and line:match("^" .. group_indent .. "},%s*$") then
      if cursor_line >= group_start and cursor_line <= index then
        vim.api.nvim_buf_set_lines(bufnr, group_start - 1, index, false, {})
        local next_line_count = vim.api.nvim_buf_line_count(bufnr)
        local next_cursor_line = math.min(group_start, next_line_count)
        vim.api.nvim_win_set_cursor(winid, { next_cursor_line, 0 })
        return true
      end
      group_start = nil
    end
  end

  vim.notify("tablocal_buffer: cursor is not inside a groups entry", vim.log.levels.WARN)
  return false
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

local function is_buffer_visible(bufnr)
  for _, winid in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(winid) == bufnr then
      return true
    end
  end
  return false
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
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end
  if vim.api.nvim_buf_get_name(bufnr) ~= "" then
    return
  end
  if vim.bo[bufnr].buftype ~= "" or vim.bo[bufnr].modified or is_buffer_visible(bufnr) then
    return
  end

  pcall(vim.api.nvim_buf_delete, bufnr, { force = false })
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
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end
  if vim.api.nvim_buf_get_name(bufnr) == "" then
    return
  end
  if vim.bo[bufnr].modified or is_buffer_visible(bufnr) then
    return
  end
  pcall(vim.api.nvim_buf_delete, bufnr, { force = false })
end

function M.apply_layout(layout)
  local known_buffers = all_known_buffers()
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

local function close_editor(bufnr, winid)
  if vim.api.nvim_win_is_valid(winid) then
    vim.api.nvim_win_close(winid, true)
  end
  if vim.api.nvim_buf_is_valid(bufnr) then
    pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
  end
end

function M.open_editor()
  local encoded = encode_state()
  local opts = config.get().editor
  local width = math.max(40, math.floor(vim.o.columns * opts.width_ratio))
  local height = math.max(10, math.floor(vim.o.lines * opts.height_ratio))

  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.bo[bufnr].buftype = "nofile"
  vim.bo[bufnr].bufhidden = "wipe"
  vim.bo[bufnr].swapfile = false
  vim.bo[bufnr].filetype = "lua"

  local winid = vim.api.nvim_open_win(bufnr, true, {
    relative = "editor",
    row = math.max(0, math.floor((vim.o.lines - height) / 2) - 1),
    col = math.floor((vim.o.columns - width) / 2),
    width = width,
    height = height,
    border = opts.border,
    style = "minimal",
  })

  local lines = M.render_editor_text(encoded.payload)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

  vim.b[bufnr].tablocal_label_map = encoded.reverse
  vim.b[bufnr].tablocal_editor_cancelled = false

  vim.keymap.set("n", "q", function()
    vim.b[bufnr].tablocal_editor_cancelled = true
    close_editor(bufnr, winid)
  end, { buffer = bufnr, nowait = true, silent = true })

  vim.keymap.set("n", "<C-j>", function()
    M.insert_empty_group(bufnr, winid)
  end, { buffer = bufnr, nowait = true, silent = true, desc = "tablocal_buffer:add_empty_group" })

  vim.keymap.set("n", "<C-d>", function()
    M.delete_group_at_cursor(bufnr, winid)
  end, { buffer = bufnr, nowait = true, silent = true, desc = "tablocal_buffer:delete_group" })

  vim.api.nvim_create_autocmd("BufWinLeave", {
    buffer = bufnr,
    once = true,
    callback = function()
      if vim.b[bufnr].tablocal_editor_cancelled then
        return
      end
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      local reverse = vim.deepcopy(vim.b[bufnr].tablocal_label_map or {})
      vim.schedule(function()
        local parsed, err = M.parse_editor_text(lines, reverse)
        if not parsed then
          vim.notify(("tablocal_buffer: invalid editor content: %s"):format(err), vim.log.levels.ERROR)
          return
        end
        M.apply_layout(parsed)
      end)
    end,
  })

  return bufnr, winid
end

return M
