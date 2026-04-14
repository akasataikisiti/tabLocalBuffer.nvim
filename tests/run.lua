local function eq(actual, expected, message)
  if not vim.deep_equal(actual, expected) then
    error((message or "assertion failed") .. "\nexpected: " .. vim.inspect(expected) .. "\nactual: " .. vim.inspect(actual))
  end
end

local function ok(value, message)
  if not value then
    error(message or "assertion failed")
  end
end

local function reset()
  for _, tabpage in ipairs(vim.api.nvim_list_tabpages()) do
    vim.api.nvim_set_current_tabpage(tabpage)
    for _, winid in ipairs(vim.api.nvim_tabpage_list_wins(tabpage)) do
      if vim.api.nvim_win_is_valid(winid) and winid ~= vim.api.nvim_get_current_win() then
        pcall(vim.api.nvim_win_close, winid, true)
      end
    end
  end

  while #vim.api.nvim_list_tabpages() > 1 do
    vim.cmd.tabclose()
  end

  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(bufnr) and vim.bo[bufnr].buflisted and not vim.bo[bufnr].modified then
      pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
    end
  end

  vim.cmd.enew()
end

local function new_named_buffer(name)
  vim.cmd.enew()
  local bufnr = vim.api.nvim_get_current_buf()
  vim.bo[bufnr].buflisted = true
  vim.api.nvim_buf_set_name(bufnr, name)
  return bufnr
end

local function test_cycle_candidate()
  reset()
  package.loaded["tablocal_buffer"] = nil
  local plugin = require("tablocal_buffer")
  plugin.setting({})

  local listed = new_named_buffer("alpha.lua")
  vim.bo[listed].filetype = "lua"
  ok(plugin.is_cycle_candidate(listed), "listed buffer should be included")

  local help_buf = vim.api.nvim_create_buf(false, true)
  vim.bo[help_buf].buflisted = true
  vim.bo[help_buf].buftype = "help"
  vim.api.nvim_buf_set_name(help_buf, "help.txt")
  ok(not plugin.is_cycle_candidate(help_buf), "help buffer should be excluded")

  vim.cmd.enew()
  local unnamed = vim.api.nvim_get_current_buf()
  ok(plugin.is_cycle_candidate(unnamed), "unnamed normal buffer should be included by default")

  plugin.setting({
    cycle = {
      exclude = {
        filetypes = { "lua" },
      },
    },
  })
  ok(not plugin.is_cycle_candidate(listed), "custom exclusion should apply")

  plugin.setting({
    cycle = {
      exclude = {
        unnamed = true,
      },
    },
  })
  ok(not plugin.is_cycle_candidate(unnamed), "unnamed exclusion option should disable unnamed buffers")
end

local function test_navigation_and_registration()
  reset()
  package.loaded["tablocal_buffer"] = nil
  local plugin = require("tablocal_buffer")
  plugin.setting({})

  local first = new_named_buffer("one.lua")
  local second = new_named_buffer("two.lua")
  eq(vim.api.nvim_tabpage_get_var(0, "tablocal_buffers"), { first, second }, "buffers should register in current tab")

  vim.api.nvim_set_current_buf(first)
  plugin.bnext_tablocal()
  eq(vim.api.nvim_get_current_buf(), second, "bnext should move within tab order")
  plugin.bprevious_tablocal()
  eq(vim.api.nvim_get_current_buf(), first, "bprevious should wrap back")
end

local function test_navigation_includes_unnamed_buffers_by_default()
  reset()
  package.loaded["tablocal_buffer"] = nil
  local plugin = require("tablocal_buffer")
  plugin.setting({})

  local named = new_named_buffer("one.lua")
  vim.cmd.enew()
  local unnamed = vim.api.nvim_get_current_buf()

  eq(vim.api.nvim_tabpage_get_var(0, "tablocal_buffers"), { named, unnamed }, "unnamed buffer should register in current tab")

  vim.api.nvim_set_current_buf(named)
  plugin.bnext_tablocal()
  eq(vim.api.nvim_get_current_buf(), unnamed, "bnext should include unnamed buffers")
end

local function test_labels()
  reset()
  local labels = require("tablocal_buffer.labels")

  local first = new_named_buffer("/tmp/app/init.lua")
  local second = new_named_buffer("/tmp/other/init.lua")
  local third = vim.api.nvim_create_buf(false, true)
  vim.bo[third].buflisted = true

  local map = { first, second, third }
  local label_map = labels.build_label_map(map)
  eq(label_map[first], ("init.lua:%d"):format(first), "duplicate basename should include bufnr")
  eq(label_map[second], ("init.lua:%d"):format(second), "duplicate basename should include bufnr")
  eq(label_map[third], ("[No Name:%d]"):format(third), "unnamed buffer should use no-name label")
end

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

local function test_move_to_new_tab()
  reset()
  package.loaded["tablocal_buffer"] = nil
  local plugin = require("tablocal_buffer")
  plugin.setting({})

  local first = new_named_buffer("move-a.lua")
  local second = new_named_buffer("move-b.lua")
  vim.api.nvim_set_current_buf(first)

  plugin.move_current_window_to_new_tab()

  eq(#vim.api.nvim_list_tabpages(), 2, "move should create a new tab")
  eq(plugin.get_buf_tabnr(first), 2, "moved buffer should belong to new tab")
  eq(plugin.get_buf_tabnr(second), 1, "remaining buffer should stay in source tab")
end

local function test_move_to_new_tab_replaces_last_source_window()
  reset()
  package.loaded["tablocal_buffer"] = nil
  local plugin = require("tablocal_buffer")
  plugin.setting({})

  local only = new_named_buffer("move-last.lua")

  plugin.move_current_window_to_new_tab()

  vim.api.nvim_set_current_tabpage(vim.api.nvim_list_tabpages()[1])
  eq(plugin.get_buf_tabnr(only), 2, "moved buffer should only belong to destination tab")
  ok(vim.api.nvim_get_current_buf() ~= only, "source tab should no longer show the moved buffer")
  ok(plugin.is_cycle_candidate(vim.api.nvim_get_current_buf()), "source tab fallback unnamed buffer should remain manageable")
end

local function test_detach_current_buffer_keeps_tab_open_and_unassigns_buffer()
  reset()
  package.loaded["tablocal_buffer"] = nil
  local plugin = require("tablocal_buffer")
  plugin.setting({})

  local first = new_named_buffer("a.txt")
  local second = new_named_buffer("b.txt")
  vim.api.nvim_set_current_buf(first)

  local detached = plugin.detach_current_buffer_from_tab()

  ok(detached, "detach should report success")
  eq(#vim.api.nvim_list_tabpages(), 1, "detaching should not close the tab")
  eq(plugin.get_buf_tabnr(first), nil, "detached buffer should become unassigned")
  eq(plugin.get_buf_tabnr(second), 1, "remaining buffer should stay assigned to the tab")
  eq(vim.api.nvim_get_current_buf(), second, "current window should switch to another buffer in the tab")
end

local function test_delete_current_buffer_from_tab_removes_buffer_without_closing_tab()
  reset()
  package.loaded["tablocal_buffer"] = nil
  local plugin = require("tablocal_buffer")
  plugin.setting({})

  local first = new_named_buffer("a.txt")
  local second = new_named_buffer("b.txt")
  vim.api.nvim_set_current_buf(first)

  local deleted = plugin.delete_current_buffer_from_tab()

  ok(deleted, "delete should report success")
  eq(#vim.api.nvim_list_tabpages(), 1, "deleting current tab-local buffer should not close the tab")
  ok(not vim.api.nvim_buf_is_valid(first), "deleted buffer should be wiped")
  eq(plugin.get_buf_tabnr(second), 1, "remaining buffer should stay assigned to the tab")
  eq(vim.api.nvim_get_current_buf(), second, "window should remain on a valid fallback buffer")
end

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

local function test_bufferline_sort_sanitizes_invalid_state()
  reset()
  package.loaded["tablocal_buffer"] = nil
  package.loaded["tablocal_buffer.bufferline"] = nil
  package.loaded["bufferline.state"] = nil
  package.loaded["bufferline"] = nil
  require("tablocal_buffer").setting({
    bufferline = {
      enabled = true,
      auto_sort_on_apply = true,
    },
  })

  local kept = new_named_buffer("kept.txt")
  local invalid = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_delete(invalid, { force = true })

  local captured_ids = nil
  package.loaded["bufferline.state"] = {
    components = {
      { id = kept },
      { id = invalid },
    },
    visible_components = {
      { id = kept },
      { id = invalid },
    },
    set = function(next_state)
      package.loaded["bufferline.state"].components = next_state.components
      package.loaded["bufferline.state"].visible_components = next_state.visible_components
    end,
  }
  package.loaded["bufferline"] = {
    sort_by = function(_)
      captured_ids = {}
      for _, item in ipairs(package.loaded["bufferline.state"].components) do
        table.insert(captured_ids, item.id)
      end
    end,
  }

  local tlb_bufferline = require("tablocal_buffer.bufferline")
  ok(tlb_bufferline.sort_bufferline(), "bufferline sort should succeed with sanitized state")
  eq(captured_ids, { kept }, "invalid buffer ids should be removed before sorting")

  package.loaded["bufferline"] = nil
  package.loaded["bufferline.state"] = nil
end

local tests = {
  test_cycle_candidate,
  test_navigation_and_registration,
  test_navigation_includes_unnamed_buffers_by_default,
  test_labels,
  test_editor_parser,
  test_editor_render_text,
  test_move_to_new_tab,
  test_move_to_new_tab_replaces_last_source_window,
  test_detach_current_buffer_keeps_tab_open_and_unassigns_buffer,
  test_delete_current_buffer_from_tab_removes_buffer_without_closing_tab,
  test_editor_apply_layout_after_close,
  test_apply_layout_sorts_before_deleting_removed_buffers,
  test_apply_layout_reorders_tabs_to_match_group_order,
  test_apply_layout_does_not_leave_new_tab_scratch_buffers_unassigned,
  test_apply_layout_deletes_removed_unassigned_buffers,
  test_apply_layout_keeps_unnamed_buffers,
  test_editor_shows_unnamed_buffers_excluded_from_cycle,
  test_bufferline_sort_sanitizes_invalid_state,
}

for _, test in ipairs(tests) do
  test()
end

print(("tests-ok:%d"):format(#tests))
