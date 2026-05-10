local config = require("tablocal_buffer.config")
local editor_text = require("tablocal_buffer.ui.editor_text")
local labels = require("tablocal_buffer.labels")
local layout = require("tablocal_buffer.layout")
local model = require("tablocal_buffer.model")
local ops = require("tablocal_buffer.ops")

local M = {}

local function encode_state()
  local all_buffers = layout.all_known_buffers()
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

M.parse_editor_text = editor_text.parse
M.render_editor_text = editor_text.render

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

  -- Default: insert before the closing `},` of the groups block
  local insert_at = close_line - 1  -- 0-based: inserts after 1-based line (close_line - 1)
  local cursor_line_after = close_line + 1

  if winid and vim.api.nvim_win_is_valid(winid) then
    local cursor_line = vim.api.nvim_win_get_cursor(winid)[1]
    local group_start = nil
    for index = 1, close_line - 1 do
      local line = lines[index]
      if line:match("^" .. group_indent .. "{%s*$") then
        group_start = index
      elseif group_start and line:match("^" .. group_indent .. "},%s*$") then
        if cursor_line >= group_start and cursor_line <= index then
          -- Insert after this group's closing `},` (1-based index)
          insert_at = index
          cursor_line_after = index + 2
          break
        end
        group_start = nil
      end
    end
  end

  vim.api.nvim_buf_set_lines(bufnr, insert_at, insert_at, false, inserted)

  if winid and vim.api.nvim_win_is_valid(winid) then
    vim.api.nvim_win_set_cursor(winid, { cursor_line_after, #entry_indent })
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

M.apply_layout = layout.apply

local function close_editor(bufnr, winid)
  ops.close_win(winid, true)
  ops.delete_buffer(bufnr, { force = true })
end

function M.save_and_close_editor(bufnr, winid)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return false
  end

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local reverse = vim.deepcopy(vim.b[bufnr].tablocal_label_map or {})
  local parsed, err = M.parse_editor_text(lines, reverse)
  if not parsed then
    vim.notify(("tablocal_buffer: invalid editor content: %s"):format(err), vim.log.levels.ERROR)
    return false
  end

  vim.b[bufnr].tablocal_editor_cancelled = true
  close_editor(bufnr, winid)
  vim.schedule(function()
    M.apply_layout(parsed)
  end)
  return true
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

  local keymaps = config.get().editor.keymaps or {}
  if keymaps.save_and_close and keymaps.save_and_close ~= "" and keymaps.save_and_close ~= "q" then
    vim.keymap.set("n", keymaps.save_and_close, function()
      M.save_and_close_editor(bufnr, winid)
    end, { buffer = bufnr, nowait = true, silent = true, desc = "tablocal_buffer:save_and_close" })
  end

  if keymaps.add_empty_group and keymaps.add_empty_group ~= "" then
    vim.keymap.set("n", keymaps.add_empty_group, function()
      M.insert_empty_group(bufnr, winid)
    end, { buffer = bufnr, nowait = true, silent = true, desc = "tablocal_buffer:add_empty_group" })
  end

  if keymaps.delete_group and keymaps.delete_group ~= "" then
    vim.keymap.set("n", keymaps.delete_group, function()
      M.delete_group_at_cursor(bufnr, winid)
    end, { buffer = bufnr, nowait = true, silent = true, desc = "tablocal_buffer:delete_group" })
  end

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
