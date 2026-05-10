local h = dofile("tests/helpers.lua")
local eq, ok, reset, new_named_buffer = h.eq, h.ok, h.reset, h.new_named_buffer

local function test_editor_apply_layout_after_close()
  reset()
  package.loaded["tablocal_buffer"] = nil
  local plugin = require("tablocal_buffer")
  plugin.setting({})

  new_named_buffer("a.txt")
  new_named_buffer("b.txt")

  local editor = require("tablocal_buffer.ui.editor")
  local bufnr, winid = editor.open_editor()
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
    "-- Edit tab-local buffers and write/quit to apply. Press q to close without saving. Duplicate basenames keep the shown :<bufnr> suffix.",
    "return {",
    "  groups = {",
    "    {",
    '      "a.txt",',
    "    },",
    "    {",
    '      "b.txt",',
    "    },",
    "  },",
    "",
    "  -- Unassigned buffers (not in any tab). Move labels above or leave here to keep unassigned.",
    "  unassigned = {",
    "    -- (none)",
    "  },",
    "}",
  })

  vim.api.nvim_win_close(winid, true)
  vim.wait(1000, function()
    return #vim.api.nvim_list_tabpages() == 2
  end)

  eq(#vim.api.nvim_list_tabpages(), 2, "closing editor with valid changes should apply layout after autocmd returns")
end

local function test_editor_save_and_close_mapping_applies_layout()
  reset()
  package.loaded["tablocal_buffer"] = nil
  local plugin = require("tablocal_buffer")
  plugin.setting({})

  new_named_buffer("a.txt")
  new_named_buffer("b.txt")

  local editor = require("tablocal_buffer.ui.editor")
  local bufnr, winid = editor.open_editor()
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
    "-- Edit tab-local buffers and write/quit to apply. Press q to close without saving. Duplicate basenames keep the shown :<bufnr> suffix.",
    "return {",
    "  groups = {",
    "    {",
    '      "a.txt",',
    "    },",
    "    {",
    '      "b.txt",',
    "    },",
    "  },",
    "",
    "  -- Unassigned buffers (not in any tab). Move labels above or leave here to keep unassigned.",
    "  unassigned = {",
    "    -- (none)",
    "  },",
    "}",
  })

  vim.api.nvim_set_current_win(winid)
  vim.api.nvim_feedkeys("s", "x", false)
  vim.wait(1000, function()
    return #vim.api.nvim_list_tabpages() == 2
  end)

  eq(#vim.api.nvim_list_tabpages(), 2, "save mapping should apply layout and close the editor")
  ok(not vim.api.nvim_win_is_valid(winid), "save mapping should close the editor window")
end

local function test_apply_layout_sorts_before_deleting_removed_buffers()
  reset()
  package.loaded["tablocal_buffer"] = nil
  package.loaded["tablocal_buffer.ui.editor"] = nil
  local plugin = require("tablocal_buffer")
  plugin.setting({
    bufferline = {
      enabled = true,
      auto_sort_on_apply = true,
    },
  })

  local kept = new_named_buffer("kept.txt")
  local removed = new_named_buffer("removed.txt")

  local sort_buf_validity = nil
  package.loaded["bufferline"] = {
    sort_by = function(comparator)
      sort_buf_validity = vim.api.nvim_buf_is_valid(removed)
      comparator({ id = kept }, { id = removed })
    end,
  }

  local editor = require("tablocal_buffer.ui.editor")
  editor.apply_layout({
    groups = {
      { kept },
    },
    unassigned = {},
  })

  ok(sort_buf_validity == true, "bufferline sort should run before removed buffers are deleted")
  ok(not vim.api.nvim_buf_is_valid(removed), "removed buffer should be deleted after sorting")
  package.loaded["bufferline"] = nil
end

local function test_apply_layout_reorders_tabs_to_match_group_order()
  reset()
  package.loaded["tablocal_buffer"] = nil
  local plugin = require("tablocal_buffer")
  local model = require("tablocal_buffer.model")
  plugin.setting({
    bufferline = {
      enabled = false,
      auto_sort_on_apply = false,
    },
  })

  local a = new_named_buffer("a.txt")
  local b = new_named_buffer("b.txt")
  vim.cmd.tabnew()
  local c = new_named_buffer("c.txt")

  local editor = require("tablocal_buffer.ui.editor")
  editor.apply_layout({
    groups = {
      { a },
      { c },
      { b },
    },
    unassigned = {},
  })

  local tabpages = vim.api.nvim_list_tabpages()
  eq(model.get_tab_buffers(tabpages[1]), { a }, "first tab should match first editor group")
  eq(model.get_tab_buffers(tabpages[2]), { c }, "second tab should match second editor group")
  eq(model.get_tab_buffers(tabpages[3]), { b }, "third tab should match third editor group")
end

local function test_apply_layout_does_not_leave_new_tab_scratch_buffers_unassigned()
  reset()
  package.loaded["tablocal_buffer"] = nil
  local plugin = require("tablocal_buffer")
  plugin.setting({
    bufferline = {
      enabled = false,
      auto_sort_on_apply = false,
    },
  })

  local a = new_named_buffer("a.txt")
  local b = new_named_buffer("b.txt")
  local c = new_named_buffer("c.txt")

  local editor = require("tablocal_buffer.ui.editor")
  editor.apply_layout({
    groups = {
      { a, b },
      { c },
    },
    unassigned = {},
  })

  local bufnr, winid = editor.open_editor()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  for _, line in ipairs(lines) do
    ok(not line:match("%[No Name:%d+%]"), "new tab scratch buffers should not remain as unassigned [No Name] entries")
  end

  vim.b[bufnr].tablocal_editor_cancelled = true
  vim.api.nvim_win_close(winid, true)
end

local function test_apply_layout_closes_removed_tabs_instead_of_leaving_empty_groups()
  reset()
  package.loaded["tablocal_buffer"] = nil
  local plugin = require("tablocal_buffer")
  local model = require("tablocal_buffer.model")
  plugin.setting({
    bufferline = {
      enabled = false,
      auto_sort_on_apply = false,
    },
  })

  local a = new_named_buffer("a.txt")
  local b = new_named_buffer("b.txt")
  vim.cmd.tabnew()
  local c = new_named_buffer("c.txt")
  local d = new_named_buffer("d.txt")
  vim.cmd.tabnew()
  local e = new_named_buffer("e.txt")
  local f = new_named_buffer("f.txt")

  local editor = require("tablocal_buffer.ui.editor")
  editor.apply_layout({
    groups = {
      { a, b },
      { e, f },
    },
    unassigned = {},
  })

  local tabpages = vim.api.nvim_list_tabpages()
  eq(#tabpages, 2, "removed groups should close extra tabs")
  eq(model.get_tab_buffers(tabpages[1]), { a, b }, "first tab should keep the first group")
  eq(model.get_tab_buffers(tabpages[2]), { e, f }, "second tab should keep the remaining group")
  ok(not vim.api.nvim_buf_is_valid(c), "buffers from removed tabs should be deleted when no longer referenced")
  ok(not vim.api.nvim_buf_is_valid(d), "all removed tab buffers should be deleted when no longer referenced")

  local bufnr, winid = editor.open_editor()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local joined = table.concat(lines, "\n")
  ok(not joined:match('%"c%.txt%"'), "removed tab buffer should not reappear as unassigned")
  ok(not joined:match('%"d%.txt%"'), "removed tab buffer should not reappear as unassigned")
  ok(not joined:match("{%s*}%s*,"), "editor should not render an empty trailing group after tab removal")

  vim.b[bufnr].tablocal_editor_cancelled = true
  vim.api.nvim_win_close(winid, true)
end

local function test_apply_layout_deletes_removed_unassigned_buffers()
  reset()
  package.loaded["tablocal_buffer"] = nil
  local plugin = require("tablocal_buffer")
  plugin.setting({
    bufferline = {
      enabled = false,
      auto_sort_on_apply = false,
    },
  })

  local kept = new_named_buffer("kept.txt")
  local removed = new_named_buffer("removed.txt")

  local editor = require("tablocal_buffer.ui.editor")
  editor.apply_layout({
    groups = {
      { kept },
    },
    unassigned = {
      removed,
    },
  })

  ok(vim.api.nvim_buf_is_valid(removed), "buffer should remain while it is listed as unassigned")

  editor.apply_layout({
    groups = {
      { kept },
    },
    unassigned = {},
  })

  ok(not vim.api.nvim_buf_is_valid(removed), "buffer removed from unassigned should be deleted")
end

local function test_apply_layout_keeps_unnamed_buffers()
  reset()
  package.loaded["tablocal_buffer"] = nil
  local plugin = require("tablocal_buffer")
  plugin.setting({
    bufferline = {
      enabled = false,
      auto_sort_on_apply = false,
    },
  })

  local named = new_named_buffer("named.txt")
  vim.cmd.enew()
  local unnamed = vim.api.nvim_get_current_buf()
  vim.bo[unnamed].buflisted = true

  local editor = require("tablocal_buffer.ui.editor")
  editor.apply_layout({
    groups = {
      { named },
    },
    unassigned = {},
  })

  ok(vim.api.nvim_buf_is_valid(unnamed), "unnamed buffers should not be auto-deleted by layout apply")
end

return {
  test_editor_apply_layout_after_close,
  test_editor_save_and_close_mapping_applies_layout,
  test_apply_layout_sorts_before_deleting_removed_buffers,
  test_apply_layout_reorders_tabs_to_match_group_order,
  test_apply_layout_does_not_leave_new_tab_scratch_buffers_unassigned,
  test_apply_layout_closes_removed_tabs_instead_of_leaving_empty_groups,
  test_apply_layout_deletes_removed_unassigned_buffers,
  test_apply_layout_keeps_unnamed_buffers,
}
