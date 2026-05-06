local h = dofile("tests/helpers.lua")
local eq, ok, reset, new_named_buffer = h.eq, h.ok, h.reset, h.new_named_buffer

local function test_editor_parser()
  reset()
  local editor = require("tablocal_buffer.ui.editor")

  local parsed = editor.parse_editor_text({
    "return {",
    "  groups = { { 'a' }, { 'b' } },",
    "  unassigned = { 'c' },",
    "}",
  }, { a = 1, b = 2, c = 3 })
  eq(parsed, { groups = { { 1 }, { 2 } }, unassigned = { 3 } }, "editor parser should resolve labels")

  local invalid = editor.parse_editor_text({
    "return { groups = { { 'a' }, { 'a' } } }",
  }, { a = 1 })
  ok(invalid == nil, "duplicate labels should fail validation")

  local empty_group = editor.parse_editor_text({
    "return { groups = { { 'a' }, {} } }",
  }, { a = 1 })
  eq(empty_group, { groups = { { 1 }, {} }, unassigned = {} }, "empty groups should be accepted")
end

local function test_editor_render_text()
  reset()
  local editor = require("tablocal_buffer.ui.editor")

  local rendered = editor.render_editor_text({
    groups = {
      { "a.txt", "b.txt" },
      { "c.txt:12" },
    },
    unassigned = {},
  })

  eq(rendered, {
    "-- Edit tab-local buffers and write/quit to apply. Press q to close without saving. Duplicate basenames keep the shown :<bufnr> suffix.",
    "return {",
    "  groups = {",
    "    {",
    '      "a.txt",',
    '      "b.txt",',
    "    },",
    "    {",
    '      "c.txt:12",',
    "    },",
    "  },",
    "",
    "  -- Unassigned buffers (not in any tab). Move labels above or leave here to keep unassigned.",
    "  unassigned = {",
    "    -- (none)",
    "  },",
    "}",
  }, "editor renderer should produce multiline editable layout")
end

local function test_editor_insert_empty_group()
  reset()
  package.loaded["tablocal_buffer"] = nil
  local plugin = require("tablocal_buffer")
  plugin.setting({})

  new_named_buffer("a.txt")

  local editor = require("tablocal_buffer.ui.editor")
  local bufnr, winid = editor.open_editor()
  local map = vim.fn.maparg("<C-J>", "n", false, true)
  ok(map.buffer == 1, "editor should register buffer-local Ctrl-j mapping")
  ok(editor.insert_empty_group(bufnr, winid), "editor should insert an empty group")

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  eq({
    lines[7],
    lines[8],
    lines[9],
  }, {
    "    {",
    "      ",
    "    },",
  }, "empty group should be inserted before the groups block closes")
  eq(vim.api.nvim_win_get_cursor(winid), { 8, 5 }, "cursor should move inside the new empty group")

  vim.b[bufnr].tablocal_editor_cancelled = true
  vim.api.nvim_win_close(winid, true)
end

local function test_editor_delete_group_at_cursor()
  reset()
  package.loaded["tablocal_buffer"] = nil
  local plugin = require("tablocal_buffer")
  plugin.setting({})

  local editor = require("tablocal_buffer.ui.editor")
  local bufnr, winid = editor.open_editor()
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
    "-- Edit tab-local buffers and write/quit to apply. Press q to close without saving. Duplicate basenames keep the shown :<bufnr> suffix.",
    "return {",
    "  groups = {",
    "    {",
    '      "model.lua",',
    "    },",
    "    {",
    '      "labels.lua",',
    '      "bash",',
    "    },",
    "  },",
    "",
    "  -- Unassigned buffers (not in any tab). Move labels above or leave here to keep unassigned.",
    "  unassigned = {",
    "    -- (none)",
    "  },",
    "}",
  })

  local map = vim.fn.maparg("<C-D>", "n", false, true)
  ok(map.buffer == 1, "editor should register buffer-local Ctrl-d mapping")
  vim.api.nvim_win_set_cursor(winid, { 5, 8 })
  ok(editor.delete_group_at_cursor(bufnr, winid), "editor should delete the group at the cursor")

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  eq({
    lines[4],
    lines[5],
    lines[6],
    lines[7],
  }, {
    "    {",
    '      "labels.lua",',
    '      "bash",',
    "    },",
  }, "only the group containing the cursor should be deleted")

  vim.b[bufnr].tablocal_editor_cancelled = true
  vim.api.nvim_win_close(winid, true)
end

local function test_editor_keymaps_are_configurable()
  reset()
  package.loaded["tablocal_buffer"] = nil
  local plugin = require("tablocal_buffer")
  plugin.setting({
    editor = {
      keymaps = {
        add_empty_group = "<leader>j",
        delete_group = "<leader>d",
      },
    },
  })

  local editor = require("tablocal_buffer.ui.editor")
  local bufnr, winid = editor.open_editor()

  ok(vim.fn.maparg("<leader>j", "n", false, true).buffer == 1, "custom add group mapping should be registered")
  ok(vim.fn.maparg("<leader>d", "n", false, true).buffer == 1, "custom delete group mapping should be registered")
  ok(vim.tbl_isempty(vim.fn.maparg("<C-J>", "n", false, true)), "default add group mapping should not be registered when overridden")
  ok(vim.tbl_isempty(vim.fn.maparg("<C-D>", "n", false, true)), "default delete group mapping should not be registered when overridden")

  vim.b[bufnr].tablocal_editor_cancelled = true
  vim.api.nvim_win_close(winid, true)
end

local function test_editor_shows_unnamed_buffers_excluded_from_cycle()
  reset()
  package.loaded["tablocal_buffer"] = nil
  local plugin = require("tablocal_buffer")
  plugin.setting({
    cycle = {
      exclude = {
        predicates = {
          function(ctx)
            return ctx.bufname == ""
          end,
        },
      },
    },
    bufferline = {
      enabled = false,
      auto_sort_on_apply = false,
    },
  })

  vim.cmd.enew()
  local unnamed = vim.api.nvim_get_current_buf()
  vim.bo[unnamed].buflisted = true

  local editor = require("tablocal_buffer.ui.editor")
  local bufnr, winid = editor.open_editor()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local expected = ('      "[No Name:%d]",'):format(unnamed)

  ok(vim.tbl_contains(lines, expected), "editor should show unnamed buffers even when cycle excludes them")

  vim.api.nvim_win_close(winid, true)
end

return {
  test_editor_parser,
  test_editor_render_text,
  test_editor_insert_empty_group,
  test_editor_delete_group_at_cursor,
  test_editor_keymaps_are_configurable,
  test_editor_shows_unnamed_buffers_excluded_from_cycle,
}
