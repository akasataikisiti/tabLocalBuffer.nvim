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

  plugin.setting({
    cycle = {
      exclude = {
        filetypes = { "lua" },
      },
    },
  })
  ok(not plugin.is_cycle_candidate(listed), "custom exclusion should apply")
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
  ok(not plugin.is_cycle_candidate(vim.api.nvim_get_current_buf()), "source tab fallback should be unmanaged")
end

local tests = {
  test_cycle_candidate,
  test_navigation_and_registration,
  test_labels,
  test_editor_parser,
  test_move_to_new_tab,
  test_move_to_new_tab_replaces_last_source_window,
}

for _, test in ipairs(tests) do
  test()
end

print(("tests-ok:%d"):format(#tests))
